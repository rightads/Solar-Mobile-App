from collections import defaultdict
from datetime import date, datetime, timezone
import mimetypes
import os
from typing import BinaryIO, Dict, List, Optional
import uuid
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.exceptions import (
    BadRequestException,
    ConflictException,
    ForbiddenException,
    NotFoundException,
)
from app.models.customer import Customer, StageHistory
from app.models.enums import CustomerStage, UserRole, WorkStatus, WorkType
from app.models.team import Team
from app.models.user import User
from app.models.work_assignment import WorkAssignment, WorkPhoto, WorkStatusLog
from app.schemas.work_assignment import (
    CalendarScheduleItem,
    CalendarScheduleResponse,
    CustomerShortForLabour,
    WorkAssignmentCreate,
    WorkAssignmentRead,
    WorkAssignmentUpdate,
    WorkPhotoRead,
    WorkStatusLogRead,
)
from app.storage.s3 import storage_service

ALLOWED_PHOTO_EXTS = {".jpg", ".jpeg", ".png", ".pdf"}
ALLOWED_PHOTO_MIMES = {"image/jpeg", "image/png", "application/pdf"}
MAX_PHOTO_SIZE = 10 * 1024 * 1024

WORK_TYPE_TO_CUSTOMER_STAGE = {
    WorkType.STRUCTURE: CustomerStage.STRUCTURE_WORK,
    WorkType.ELECTRICAL: CustomerStage.ELECTRICAL_WORK,
    WorkType.CIVIL: CustomerStage.CIVIL_WORK,
}


class WorkAssignmentService:
    """Service managing on-site installation assignments, labour teams, and photo proof."""

    @staticmethod
    async def create_work_assignment(
        db: AsyncSession,
        customer_id: uuid.UUID,
        assignment_in: WorkAssignmentCreate,
        admin_user: User,
    ) -> WorkAssignmentRead:
        if admin_user.role != UserRole.ADMIN:
            raise ForbiddenException("Only administrators can assign work.")

        # 1. Fetch customer
        cust_stmt = select(Customer).where(Customer.id == customer_id, Customer.is_deleted == False)  # noqa: E712
        customer = (await db.execute(cust_stmt)).scalar_one_or_none()
        if not customer:
            raise NotFoundException("Customer not found.")

        # 2. Advance payment guard (unless override is True)
        stages_before_advance = [CustomerStage.SALE_CONFIRMED, CustomerStage.DOCUMENTS_RECEIVED]
        if customer.stage in stages_before_advance and not assignment_in.override:
            raise BadRequestException(
                f"Cannot assign work while customer is in stage '{customer.stage.value}' without advance payment verification. Set override=true to proceed."
            )

        # 3. Validate team existence and matching type
        team_stmt = select(Team).where(Team.id == assignment_in.team_id)
        team = (await db.execute(team_stmt)).scalar_one_or_none()
        if not team:
            raise NotFoundException("Assigned team not found.")
        if team.type.value != assignment_in.work_type.value:
            raise BadRequestException(
                f"Team type mismatch: Team '{team.name}' is of type '{team.type.value}', but assignment is for '{assignment_in.work_type.value}'."
            )

        # 4. Validate dates
        if assignment_in.scheduled_end < assignment_in.scheduled_start:
            raise BadRequestException("Scheduled end date cannot be earlier than scheduled start date.")

        # 5. Check if active assignment for (customer_id, work_type) already exists
        active_check = select(WorkAssignment).where(
            WorkAssignment.customer_id == customer_id,
            WorkAssignment.work_type == assignment_in.work_type,
            WorkAssignment.status != WorkStatus.CANCELLED,
        )
        if (await db.execute(active_check)).scalar_one_or_none():
            raise ConflictException(
                f"Customer already has an active {assignment_in.work_type.value} work assignment."
            )

        # 6. Check team schedule overlap (unless allow_overlap is True)
        if not assignment_in.allow_overlap:
            overlap_check = select(WorkAssignment).where(
                WorkAssignment.team_id == assignment_in.team_id,
                WorkAssignment.status.in_([WorkStatus.PENDING, WorkStatus.IN_PROGRESS]),
                WorkAssignment.scheduled_start <= assignment_in.scheduled_end,
                WorkAssignment.scheduled_end >= assignment_in.scheduled_start,
            )
            overlapping = (await db.execute(overlap_check)).scalar_one_or_none()
            if overlapping:
                raise ConflictException(
                    f"Team '{team.name}' already has an overlapping active assignment between {overlapping.scheduled_start} and {overlapping.scheduled_end}. Set allow_overlap=true to assign anyway."
                )

        # 7. Create assignment
        assignment = WorkAssignment(
            customer_id=customer_id,
            work_type=assignment_in.work_type,
            team_id=assignment_in.team_id,
            scheduled_start=assignment_in.scheduled_start,
            scheduled_end=assignment_in.scheduled_end,
            notes=assignment_in.notes,
            status=WorkStatus.PENDING,
            assigned_by=admin_user.id,
        )
        db.add(assignment)
        await db.flush()

        # 8. Log initial status
        log = WorkStatusLog(
            work_assignment_id=assignment.id,
            from_status=None,
            to_status=WorkStatus.PENDING,
            changed_by=admin_user.id,
            note=f"Work assigned to team '{team.name}'",
        )
        db.add(log)
        await db.commit()
        await db.refresh(assignment)

        return await WorkAssignmentService._to_read(assignment)

    @staticmethod
    async def list_work_assignments(
        db: AsyncSession,
        current_user: User,
        customer_id: Optional[uuid.UUID] = None,
        team_id: Optional[uuid.UUID] = None,
        work_type: Optional[WorkType] = None,
        status: Optional[WorkStatus] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
    ) -> List[WorkAssignmentRead]:
        query = select(WorkAssignment)

        # Scoping: Labour sees only their own team
        if current_user.role == UserRole.LABOUR:
            if not current_user.team_id:
                return []
            query = query.where(WorkAssignment.team_id == current_user.team_id)
        elif team_id:
            query = query.where(WorkAssignment.team_id == team_id)

        if customer_id:
            query = query.where(WorkAssignment.customer_id == customer_id)
        if work_type:
            query = query.where(WorkAssignment.work_type == work_type)
        if status:
            query = query.where(WorkAssignment.status == status)
        if date_from:
            query = query.where(WorkAssignment.scheduled_end >= date_from)
        if date_to:
            query = query.where(WorkAssignment.scheduled_start <= date_to)

        query = query.order_by(WorkAssignment.scheduled_start.asc())
        assignments = list((await db.execute(query)).scalars().all())

        return [await WorkAssignmentService._to_read(a) for a in assignments]

    @staticmethod
    async def get_work_assignment_by_id(
        db: AsyncSession,
        assignment_id: uuid.UUID,
        current_user: User,
    ) -> WorkAssignmentRead:
        stmt = select(WorkAssignment).where(WorkAssignment.id == assignment_id)
        assignment = (await db.execute(stmt)).scalar_one_or_none()
        if not assignment:
            raise NotFoundException("Work assignment not found.")

        if current_user.role == UserRole.LABOUR and assignment.team_id != current_user.team_id:
            raise ForbiddenException("Labour users can only view their own team's work assignments.")

        return await WorkAssignmentService._to_read(assignment)

    @staticmethod
    async def update_work_assignment(
        db: AsyncSession,
        assignment_id: uuid.UUID,
        update_in: WorkAssignmentUpdate,
        admin_user: User,
    ) -> WorkAssignmentRead:
        if admin_user.role != UserRole.ADMIN:
            raise ForbiddenException("Only administrators can edit work assignments.")

        stmt = select(WorkAssignment).where(WorkAssignment.id == assignment_id)
        assignment = (await db.execute(stmt)).scalar_one_or_none()
        if not assignment:
            raise NotFoundException("Work assignment not found.")

        old_status = assignment.status
        if update_in.team_id and update_in.team_id != assignment.team_id:
            team = (await db.execute(select(Team).where(Team.id == update_in.team_id))).scalar_one_or_none()
            if not team:
                raise NotFoundException("Team not found.")
            if team.type.value != assignment.work_type.value:
                raise BadRequestException("Team type mismatch with work type.")
            assignment.team_id = update_in.team_id

        if update_in.scheduled_start:
            assignment.scheduled_start = update_in.scheduled_start
        if update_in.scheduled_end:
            assignment.scheduled_end = update_in.scheduled_end
        if update_in.notes is not None:
            assignment.notes = update_in.notes
        if update_in.status is not None:
            assignment.status = update_in.status

        if update_in.status and update_in.status != old_status:
            log = WorkStatusLog(
                work_assignment_id=assignment.id,
                from_status=old_status,
                to_status=update_in.status,
                changed_by=admin_user.id,
                note=f"Status changed from {old_status.value} to {update_in.status.value}",
            )
            db.add(log)

        await db.commit()
        await db.refresh(assignment)
        return await WorkAssignmentService._to_read(assignment)

    @staticmethod
    async def start_work(
        db: AsyncSession,
        assignment_id: uuid.UUID,
        current_user: User,
    ) -> WorkAssignmentRead:
        stmt = select(WorkAssignment).where(WorkAssignment.id == assignment_id)
        assignment = (await db.execute(stmt)).scalar_one_or_none()
        if not assignment:
            raise NotFoundException("Work assignment not found.")

        # Permission check: team member or admin
        if current_user.role == UserRole.LABOUR and assignment.team_id != current_user.team_id:
            raise ForbiddenException("Only assigned team members can start this work assignment.")
        elif current_user.role not in [UserRole.ADMIN, UserRole.LABOUR]:
            raise ForbiddenException("Insufficient permissions to start work.")

        if assignment.status != WorkStatus.PENDING:
            raise BadRequestException(f"Cannot start work with status '{assignment.status.value}'.")

        now = datetime.now(timezone.utc)
        old_status = assignment.status
        assignment.status = WorkStatus.IN_PROGRESS
        assignment.actual_start = now

        # Status log
        log = WorkStatusLog(
            work_assignment_id=assignment.id,
            from_status=old_status,
            to_status=WorkStatus.IN_PROGRESS,
            changed_by=current_user.id,
            note="Work started on-site",
        )
        db.add(log)

        # Progress customer stage according to work type
        target_stage = WORK_TYPE_TO_CUSTOMER_STAGE.get(assignment.work_type)
        if target_stage and assignment.customer.stage != target_stage:
            old_cust_stage = assignment.customer.stage
            assignment.customer.stage = target_stage
            history = StageHistory(
                customer_id=assignment.customer.id,
                from_stage=old_cust_stage,
                to_stage=target_stage,
                changed_by=current_user.id,
                note=f"{assignment.work_type.value.capitalize()} work started by team",
            )
            db.add(history)

        await db.commit()
        await db.refresh(assignment)
        return await WorkAssignmentService._to_read(assignment)

    @staticmethod
    async def upload_photos(
        db: AsyncSession,
        assignment_id: uuid.UUID,
        files: List[BinaryIO],
        filenames: List[str],
        content_types: List[str],
        captions: List[Optional[str]],
        current_user: User,
    ) -> List[WorkPhotoRead]:
        stmt = select(WorkAssignment).where(WorkAssignment.id == assignment_id)
        assignment = (await db.execute(stmt)).scalar_one_or_none()
        if not assignment:
            raise NotFoundException("Work assignment not found.")

        if current_user.role == UserRole.LABOUR and assignment.team_id != current_user.team_id:
            raise ForbiddenException("Only assigned team members can upload photos for this work assignment.")
        elif current_user.role not in [UserRole.ADMIN, UserRole.LABOUR]:
            raise ForbiddenException("Insufficient permissions to upload work photos.")

        if len(files) > 10:
            raise BadRequestException("Maximum 10 photos can be uploaded per request.")

        created_photos: List[WorkPhoto] = []
        for file_obj, filename, c_type, caption in zip(files, filenames, content_types, captions):
            _, ext = os.path.splitext(filename.lower())
            if ext not in ALLOWED_PHOTO_EXTS:
                raise BadRequestException(f"Invalid photo extension '{ext}'. Allowed: jpg, png, pdf.")

            photo_id = uuid.uuid4()
            storage_path = f"customers/{assignment.customer_id}/work/{assignment.work_type.value}/{photo_id}{ext}"
            await storage_service.upload_file(
                file_obj=file_obj,
                destination_path=storage_path,
                content_type=c_type or "image/jpeg",
            )

            photo = WorkPhoto(
                id=photo_id,
                work_assignment_id=assignment.id,
                file_key=storage_path,
                caption=caption,
                uploaded_by=current_user.id,
            )
            db.add(photo)
            created_photos.append(photo)

        await db.commit()

        results: List[WorkPhotoRead] = []
        for p in created_photos:
            await db.refresh(p)
            read_item = WorkPhotoRead.model_validate(p)
            read_item.download_url = await storage_service.get_presigned_url(p.file_key, expires_in=3600)
            results.append(read_item)

        return results

    @staticmethod
    async def complete_work(
        db: AsyncSession,
        assignment_id: uuid.UUID,
        current_user: User,
    ) -> WorkAssignmentRead:
        stmt = select(WorkAssignment).where(WorkAssignment.id == assignment_id)
        assignment = (await db.execute(stmt)).scalar_one_or_none()
        if not assignment:
            raise NotFoundException("Work assignment not found.")

        if current_user.role == UserRole.LABOUR and assignment.team_id != current_user.team_id:
            raise ForbiddenException("Only assigned team members can complete this work assignment.")
        elif current_user.role not in [UserRole.ADMIN, UserRole.LABOUR]:
            raise ForbiddenException("Insufficient permissions to complete work.")

        if assignment.status == WorkStatus.COMPLETED:
            raise BadRequestException("Work assignment is already completed.")

        # Photo requirement validation
        photo_count_stmt = select(func.count(WorkPhoto.id)).where(WorkPhoto.work_assignment_id == assignment_id)
        photo_count = (await db.execute(photo_count_stmt)).scalar() or 0
        if photo_count == 0:
            raise BadRequestException("At least 1 proof photo is required to complete this work assignment.")

        now = datetime.now(timezone.utc)
        old_status = assignment.status
        assignment.status = WorkStatus.COMPLETED
        assignment.actual_end = now

        log = WorkStatusLog(
            work_assignment_id=assignment.id,
            from_status=old_status,
            to_status=WorkStatus.COMPLETED,
            changed_by=current_user.id,
            note="Work completed on-site with photo proof",
        )
        db.add(log)

        # Check if all work assignments for this customer are COMPLETED
        all_assign_stmt = select(WorkAssignment).where(
            WorkAssignment.customer_id == assignment.customer_id,
            WorkAssignment.status != WorkStatus.CANCELLED,
        )
        all_assignments = list((await db.execute(all_assign_stmt)).scalars().all())

        all_completed = all(
            (a.id == assignment.id or a.status == WorkStatus.COMPLETED)
            for a in all_assignments
        )

        if all_completed and len(all_assignments) > 0:
            if assignment.customer.stage != CustomerStage.INSTALLATION_COMPLETE:
                old_stage = assignment.customer.stage
                assignment.customer.stage = CustomerStage.INSTALLATION_COMPLETE
                history = StageHistory(
                    customer_id=assignment.customer.id,
                    from_stage=old_stage,
                    to_stage=CustomerStage.INSTALLATION_COMPLETE,
                    changed_by=current_user.id,
                    note="All assigned installation works (Structure/Electrical/Civil) completed",
                )
                db.add(history)

        await db.commit()
        await db.refresh(assignment)
        return await WorkAssignmentService._to_read(assignment)

    @staticmethod
    async def get_calendar_schedule(
        db: AsyncSession,
        from_date: date,
        to_date: date,
        current_user: User,
        team_id: Optional[uuid.UUID] = None,
    ) -> CalendarScheduleResponse:
        query = (
            select(WorkAssignment)
            .where(
                WorkAssignment.status != WorkStatus.CANCELLED,
                WorkAssignment.scheduled_end >= from_date,
                WorkAssignment.scheduled_start <= to_date,
            )
            .order_by(WorkAssignment.scheduled_start.asc())
        )

        if current_user.role == UserRole.LABOUR:
            if not current_user.team_id:
                return CalendarScheduleResponse(from_date=from_date, to_date=to_date, total_assignments=0)
            query = query.where(WorkAssignment.team_id == current_user.team_id)
        elif team_id:
            query = query.where(WorkAssignment.team_id == team_id)

        assignments = list((await db.execute(query)).scalars().all())

        by_date: Dict[str, List[CalendarScheduleItem]] = defaultdict(list)
        by_team: Dict[str, List[CalendarScheduleItem]] = defaultdict(list)

        for a in assignments:
            item = CalendarScheduleItem(
                assignment_id=a.id,
                customer_id=a.customer.id,
                customer_name=a.customer.name,
                customer_address=a.customer.address,
                work_type=a.work_type,
                team_id=a.team.id,
                team_name=a.team.name,
                scheduled_start=a.scheduled_start,
                scheduled_end=a.scheduled_end,
                status=a.status,
            )
            by_date[str(a.scheduled_start)].append(item)
            by_team[a.team.name].append(item)

        return CalendarScheduleResponse(
            from_date=from_date,
            to_date=to_date,
            total_assignments=len(assignments),
            by_date=dict(by_date),
            by_team=dict(by_team),
        )

    @staticmethod
    async def _to_read(assignment: WorkAssignment) -> WorkAssignmentRead:
        read_obj = WorkAssignmentRead.model_validate(assignment)
        # Populate presigned URLs on photos if any
        if read_obj.photos:
            for p in read_obj.photos:
                p.download_url = await storage_service.get_presigned_url(p.file_key, expires_in=3600)
        return read_obj
