"""Site work (structure → electrical → civil). Site staff only see and update
their own jobs or unassigned jobs in their trade."""
from datetime import date, datetime, timezone
from typing import List, Literal, Optional
import uuid
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles, require_staff
from app.core.exceptions import BadRequestException, ForbiddenException
from app.core.uploads import save_upload
from app.db.mongo import _format_mongo_doc, get_mongo_db
from app.models.enums import UserRole
from app.services import workflow

router = APIRouter(tags=["Work Assignments"])
require_planner = require_roles(UserRole.ADMIN, UserRole.SALES)
require_site = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.SALES, UserRole.SITE)

WorkType = Literal["structure", "electrical", "civil", "installation"]
WorkStatus = Literal["pending", "assigned", "in_progress", "completed", "cancelled"]


class WorkCreate(BaseModel):
    model_config = ConfigDict(extra="ignore")
    customer_id: str = Field(..., min_length=1, max_length=64)
    work_type: WorkType
    team_name: Optional[str] = Field("", max_length=60)
    lead_name: Optional[str] = Field("", max_length=100)
    lead_phone: Optional[str] = Field("", max_length=15)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    notes: Optional[str] = Field("", max_length=2000)
    assigned_to: Optional[str] = Field(None, max_length=64)


class WorkPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Optional[WorkStatus] = None
    notes: Optional[str] = Field(None, max_length=2000)
    team_name: Optional[str] = Field(None, max_length=60)
    lead_name: Optional[str] = Field(None, max_length=100)
    lead_phone: Optional[str] = Field(None, max_length=15)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    assigned_to: Optional[str] = Field(None, max_length=64)


PLANNER_ONLY = {"team_name", "lead_name", "lead_phone", "start_date", "end_date", "assigned_to"}


def _validate_site_employee(emp_id: str) -> dict:
    emp = get_mongo_db()["users"].find_one({"_id": emp_id, "is_active": True})
    if not emp or str(emp.get("role", "")).lower() not in access.SITE_ROLES:
        raise BadRequestException("assigned_to must be an active site employee.")
    return emp


def _create(user: MongoUserProxy, data: WorkCreate) -> dict:
    cust = access.require_customer_write(user, data.customer_id)
    now = datetime.now(timezone.utc)
    aid = str(uuid.uuid4())
    emp = _validate_site_employee(data.assigned_to) if data.assigned_to else None
    doc = {
        "_id": aid, "id": aid,
        "customer_id": str(cust["_id"]), "customer_name": cust.get("name", ""),
        "location": cust.get("address", ""), "work_type": data.work_type,
        "team_name": (data.team_name or "").strip(), "lead_name": (data.lead_name or "").strip(),
        "lead_phone": (data.lead_phone or "").strip(),
        "start_date": (data.start_date or now.date()).isoformat(),
        "end_date": (data.end_date or data.start_date or now.date()).isoformat(),
        "status": "assigned", "notes": (data.notes or "").strip(), "photos": [],
        "assigned_to": str(emp["_id"]) if emp else None,
        "assigned_employee_id": str(emp["_id"]) if emp else None,
        "assigned_employee_name": emp.get("name") if emp else None,
        "assigned_employee_no": emp.get("employee_no") if emp else None,
        "created_by": user.id, "created_at": now, "updated_at": now,
    }
    get_mongo_db()["work_assignments"].insert_one(doc)
    return _format_mongo_doc(doc)


@router.post("/work-assignments", status_code=status.HTTP_201_CREATED, summary="Schedule site work")
async def create_work_assignment_direct(payload: WorkCreate, current_user: MongoUserProxy = Depends(require_planner)):
    return _create(current_user, payload)


@router.post("/customers/{customer_id}/work-assignments", status_code=status.HTTP_201_CREATED, summary="Schedule site work for a customer")
async def create_work_assignment(customer_id: str, payload: WorkCreate, current_user: MongoUserProxy = Depends(require_planner)):
    payload.customer_id = customer_id
    return _create(current_user, payload)


@router.get("/work-assignments", summary="Work visible to the caller")
async def list_work_assignments(
    customer_id: Optional[str] = Query(default=None, max_length=64),
    work_type: Optional[str] = Query(default=None, max_length=20),
    status: Optional[str] = Query(default=None, max_length=20),
    current_user: MongoUserProxy = Depends(require_site),
):
    clauses = [access.work_scope_query(current_user)]
    if customer_id:
        clauses.append({"customer_id": customer_id})
    if work_type and work_type.lower() != "all":
        clauses.append({"work_type": work_type.lower()})
    if status and status.lower() != "all":
        clauses.append({"status": status.lower()})
    cursor = get_mongo_db()["work_assignments"].find({"$and": clauses}).sort("created_at", -1)
    return [_format_mongo_doc(d) for d in cursor]


@router.get("/work-assignments/calendar", summary="Scheduled work grouped by date and team")
async def get_calendar_schedule(
    from_date: Optional[date] = Query(default=None),
    to_date: Optional[date] = Query(default=None),
    current_user: MongoUserProxy = Depends(require_site),
):
    clauses = [access.work_scope_query(current_user)]
    if from_date:
        clauses.append({"end_date": {"$gte": from_date.isoformat()}})
    if to_date:
        clauses.append({"start_date": {"$lte": to_date.isoformat()}})
    items = [_format_mongo_doc(d) for d in get_mongo_db()["work_assignments"].find({"$and": clauses}).sort("start_date", 1)]
    by_date: dict = {}
    by_team: dict = {}
    for it in items:
        by_date.setdefault(str(it.get("start_date") or ""), []).append(it)
        by_team.setdefault(it.get("team_name") or "Unassigned", []).append(it)
    return {"total_assignments": len(items), "by_date": by_date, "by_team": by_team, "items": items}


@router.get("/work-assignments/{assignment_id}", summary="Work details")
async def get_work_assignment(assignment_id: str, current_user: MongoUserProxy = Depends(require_site)):
    return _format_mongo_doc(access.require_work(current_user, assignment_id))


def _apply(work: dict, updates: dict, user: MongoUserProxy) -> dict:
    from pymongo import ReturnDocument
    now = datetime.now(timezone.utc)
    updates["updated_at"] = now
    if updates.get("status") == "in_progress" and not work.get("started_at"):
        updates["started_at"] = now
    if updates.get("status") == "completed":
        updates["completed_at"] = now
        updates["completed_by"] = user.name
    # Site staff picking up an unassigned job become its owner.
    if access.role_of(user) in access.SITE_ROLES and not work.get("assigned_to"):
        updates.update({"assigned_to": user.id, "assigned_employee_id": user.id,
                        "assigned_employee_name": user.name, "assigned_employee_no": user.employee_no})
    res = get_mongo_db()["work_assignments"].find_one_and_update(
        {"_id": work["_id"]}, {"$set": updates}, return_document=ReturnDocument.AFTER,
    )
    if "status" in updates and updates["status"] != work.get("status"):
        workflow.on_work_status(res, user)
    return _format_mongo_doc(res)


@router.patch("/work-assignments/{assignment_id}", summary="Update work status or schedule")
async def update_work_assignment(
    assignment_id: str,
    payload: WorkPatch,
    current_user: MongoUserProxy = Depends(require_site),
):
    work = access.require_work(current_user, assignment_id, write=True)
    updates = payload.model_dump(exclude_unset=True)
    is_planner = access.role_of(current_user) in access.ADMIN_ROLES | access.SALES_ROLES | {"manager"}
    if not is_planner and PLANNER_ONLY & updates.keys():
        raise ForbiddenException("Only an admin or sales planner can reschedule or reassign work.")
    for k in ("start_date", "end_date"):
        if updates.get(k):
            updates[k] = updates[k].isoformat()
    if updates.get("assigned_to"):
        emp = _validate_site_employee(updates["assigned_to"])
        updates.update({"assigned_employee_id": str(emp["_id"]), "assigned_employee_name": emp.get("name"),
                        "assigned_employee_no": emp.get("employee_no")})
    if updates.get("status") == "completed" and not (work.get("photos") or []) and not is_planner:
        raise BadRequestException("Upload at least one site photo before marking the job complete.")
    return _apply(work, updates, current_user)


@router.post("/work-assignments/{assignment_id}/start", summary="Mark work as started")
async def start_work(assignment_id: str, current_user: MongoUserProxy = Depends(require_site)):
    work = access.require_work(current_user, assignment_id, write=True)
    return _apply(work, {"status": "in_progress"}, current_user)


@router.post("/work-assignments/{assignment_id}/complete", summary="Mark work as completed")
async def complete_work(assignment_id: str, current_user: MongoUserProxy = Depends(require_site)):
    work = access.require_work(current_user, assignment_id, write=True)
    is_planner = access.role_of(current_user) in access.ADMIN_ROLES | {"manager"}
    if not (work.get("photos") or []) and not is_planner:
        raise BadRequestException("Upload at least one site photo before marking the job complete.")
    return _apply(work, {"status": "completed"}, current_user)


@router.post("/work-assignments/{assignment_id}/reopen", summary="Mark completed work as incomplete (rework)")
async def reopen_work(assignment_id: str, current_user: MongoUserProxy = Depends(require_site)):
    work = access.require_work(current_user, assignment_id, write=True)
    if work.get("status") != "completed":
        raise BadRequestException("Only completed work can be reopened.")
    return _apply(work, {"status": "in_progress", "completed_at": None, "completed_by": None}, current_user)


@router.post("/work-assignments/{assignment_id}/photos", status_code=status.HTTP_201_CREATED, summary="Upload site proof photos")
async def upload_work_photos(
    assignment_id: str,
    files: List[UploadFile] = File(..., description="Up to 10 photos"),
    captions: Optional[List[str]] = Form(None),
    current_user: MongoUserProxy = Depends(require_site),
):
    work = access.require_work(current_user, assignment_id, write=True)
    if not files or len(files) > 10:
        raise BadRequestException("Upload between 1 and 10 photos at a time.")
    photos = []
    for i, f in enumerate(files):
        meta = await save_upload(f, category="site_photos", uploaded_by=current_user.id,
                                 customer_id=str(work.get("customer_id") or ""), allow_pdf=False)
        caption = (captions[i] if captions and i < len(captions) else "") or ""
        photos.append({
            "id": meta["file_id"],
            "work_assignment_id": str(work["_id"]),
            "file_key": meta["file_id"],
            "caption": caption.strip()[:200],
            "uploaded_by": current_user.name,
            "download_url": meta["url"],
            "uploaded_at": meta["uploaded_at"],
        })
    get_mongo_db()["work_assignments"].update_one(
        {"_id": work["_id"]},
        {"$push": {"photos": {"$each": photos}}, "$set": {"updated_at": datetime.now(timezone.utc)}},
    )
    return photos
