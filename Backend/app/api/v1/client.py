from datetime import datetime, timezone
from typing import List, Optional
import uuid
from fastapi import APIRouter, Body, Depends, File, Form, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.enums import PaymentMode
from app.models.user import User
from app.schemas.client import ClientHomeResponse
from app.schemas.document import DocumentRead
from app.schemas.payment import CustomerPaymentsListResponse, PaymentCreate, PaymentRead
from app.schemas.ticket import TicketCommentCreate, TicketCommentRead, TicketCreate, TicketRead
from app.services.client_service import ClientService
from app.services.document_service import DocumentService
from app.services.payment_service import PaymentService
from app.services.ticket_service import TicketService

router = APIRouter(prefix="/client", tags=["Client Mobile Experience"])


@router.get(
    "/home",
    response_model=None,
    summary="Get customer home screen data including 10-stage timeline, contacts, specs, and payments",
)
async def get_client_home(
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            return await ClientService.get_home_data(db, current_user)
        except Exception:
            pass
    from app.db.mongo import mongo_get_client_home
    user_phone = getattr(current_user, "phone", None) or str(current_user.id)
    return mongo_get_client_home(user_phone)


@router.get(
    "/payments",
    response_model=None,
    summary="Get all payment records and schedule status for the logged-in client",
)
async def get_client_payments(
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            customer = await ClientService.get_client_customer(db, current_user)
            return await PaymentService.get_customer_payments(db, customer.id)
        except Exception:
            pass
    from app.db.mongo import mongo_get_client_payments
    user_phone = getattr(current_user, "phone", None) or str(current_user.id)
    return mongo_get_client_payments(user_phone)


@router.post(
    "/payments",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Submit a payment receipt / record as client",
)
async def submit_client_payment(
    amount: int = Form(..., gt=0, description="Amount in paise"),
    mode: PaymentMode = Form(..., description="Payment mode"),
    reference_no: Optional[str] = Form(None, description="Transaction reference"),
    paid_on: Optional[datetime] = Form(None, description="Payment date"),
    remarks: Optional[str] = Form(None, description="Remarks"),
    file: Optional[UploadFile] = File(None, description="Optional receipt proof file"),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            customer = await ClientService.get_client_customer(db, current_user)
            payment_in = PaymentCreate(
                amount=amount,
                mode=mode,
                reference_no=reference_no,
                paid_on=paid_on or datetime.utcnow(),
                remarks=remarks,
            )

            proof_stream = None
            proof_filename = None
            proof_mime = None
            proof_size = None

            if file:
                content = await file.read()
                proof_size = len(content)
                proof_stream = file.file
                proof_filename = file.filename
                proof_mime = file.content_type
                await file.seek(0)

            payment = await PaymentService.record_payment(
                db=db,
                customer_id=customer.id,
                data=payment_in,
                current_user=current_user,
                proof_file=proof_stream,
                filename=proof_filename,
                content_type=proof_mime,
                file_size=proof_size,
            )
            return await PaymentService.build_payment_read(payment)
        except Exception:
            pass

    from app.db.mongo import mongo_record_client_payment
    user_phone = getattr(current_user, "phone", None) or str(current_user.id)
    mode_str = mode.value if hasattr(mode, "value") else str(mode)
    return mongo_record_client_payment(
        client_phone=user_phone,
        amount_paise=amount,
        mode=mode_str,
        reference_no=reference_no,
        paid_on=paid_on,
        remarks=remarks,
        proof_filename=file.filename if file else None,
    )


@router.get(
    "/documents",
    response_model=List[DocumentRead],
    summary="List all uploaded KYC and project documents for the client",
)
async def get_client_documents(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    customer = await ClientService.get_client_customer(db, current_user)
    docs = await DocumentService.get_customer_documents(db, customer.id)
    return [await DocumentService.build_document_read(doc) for doc in docs]


@router.post(
    "/tickets",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Raise a new post-installation service ticket",
)
async def create_client_ticket(
    data: TicketCreate,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            customer = await ClientService.get_client_customer(db, current_user)
            ticket = await TicketService.create_ticket(db, customer, data, current_user)
            return await TicketService.build_ticket_read(ticket)
        except Exception:
            pass

    from app.db.mongo import mongo_create_ticket, get_mongo_db
    mongo_db = get_mongo_db()
    user_phone = getattr(current_user, "phone", None) or str(getattr(current_user, "id", ""))
    cust = None
    if mongo_db:
        cust = mongo_db["customers"].find_one({
            "$or": [{"phone": user_phone}, {"mobile": user_phone}, {"user_id": str(getattr(current_user, "id", ""))}]
        })

    ticket_data = {
        "customer_id": str(cust["_id"]) if cust else str(getattr(current_user, "id", "")),
        "customer_name": cust.get("name", getattr(current_user, "name", "Client")) if cust else getattr(current_user, "name", "Client"),
        "customer_phone": cust.get("phone", user_phone) if cust else user_phone,
        "customer_address": cust.get("address", "Jaipur, Rajasthan") if cust else "Jaipur, Rajasthan",
        "type": data.type.value if hasattr(data.type, "value") else str(data.type),
        "title": data.title,
        "description": data.description,
        "error_code": data.error_code,
        "priority": data.priority.value if hasattr(data.priority, "value") else str(data.priority),
        "images": data.image_keys or [],
        "assigned_to": "emp-srv-104",
        "assigned_staff": "Vikram Singh",
        "assigned_staff_emp_no": "EMP-SRV-104",
    }
    return mongo_create_ticket(ticket_data)


@router.get(
    "/tickets",
    response_model=None,
    summary="List all service tickets raised for the logged-in client",
)
async def list_client_tickets(
    limit: int = 50,
    offset: int = 0,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            customer = await ClientService.get_client_customer(db, current_user)
            tickets = await TicketService.list_tickets(
                db=db,
                customer_id=customer.id,
                limit=limit,
                offset=offset,
            )
            return [await TicketService.build_ticket_read(t) for t in tickets]
        except Exception:
            pass

    from app.db.mongo import mongo_get_tickets, get_mongo_db
    mongo_db = get_mongo_db()
    user_phone = getattr(current_user, "phone", None) or str(getattr(current_user, "id", ""))
    cust = None
    if mongo_db:
        cust = mongo_db["customers"].find_one({
            "$or": [{"phone": user_phone}, {"mobile": user_phone}, {"user_id": str(getattr(current_user, "id", ""))}]
        })
    cid = str(cust["_id"]) if cust else user_phone
    return mongo_get_tickets(customer_id=cid)


@router.get(
    "/tickets/{ticket_id}",
    response_model=None,
    summary="Get service ticket details",
)
async def get_client_ticket(
    ticket_id: str,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            tid = uuid.UUID(ticket_id)
            customer = await ClientService.get_client_customer(db, current_user)
            ticket = await TicketService.get_ticket_by_id(db, tid, for_customer_id=customer.id)
            return await TicketService.build_ticket_read(ticket)
        except Exception:
            pass

    from app.db.mongo import mongo_get_ticket_by_id
    return mongo_get_ticket_by_id(str(ticket_id))


@router.post(
    "/tickets/{ticket_id}/comments",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Add a comment to a service ticket",
)
async def add_client_ticket_comment(
    ticket_id: str,
    data: TicketCommentCreate,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            tid = uuid.UUID(ticket_id)
            customer = await ClientService.get_client_customer(db, current_user)
            comment = await TicketService.add_comment(
                db=db,
                ticket_id=tid,
                data=data,
                user=current_user,
                for_customer_id=customer.id,
            )
            return TicketCommentRead(
                id=comment.id,
                ticket_id=comment.ticket_id,
                author_id=comment.author_id,
                author_name=current_user.name,
                author_role=current_user.role.value,
                message=comment.message,
                created_at=comment.created_at,
            )
        except Exception:
            pass

    from app.db.mongo import get_mongo_db, _format_mongo_doc
    mongo_db = get_mongo_db()
    if mongo_db:
        cmt = {
            "id": f"cmt_{uuid.uuid4().hex[:8]}",
            "ticket_id": str(ticket_id),
            "author_id": str(getattr(current_user, "id", "")),
            "author_name": getattr(current_user, "name", "Client"),
            "author_role": getattr(current_user, "role", "client"),
            "message": data.message,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        mongo_db["tickets"].update_one(
            {"$or": [{"_id": str(ticket_id)}, {"id": str(ticket_id)}, {"ticket_no": str(ticket_id)}]},
            {"$push": {"comments": cmt}}
        )
        return cmt
    return {"message": "Comment recorded"}


@router.post(
    "/tickets/{ticket_id}/reopen",
    response_model=None,
    summary="Reopen a resolved or closed ticket (within 7 days)",
)
async def reopen_client_ticket(
    ticket_id: str,
    reason: str = Body(..., embed=True),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            tid = uuid.UUID(ticket_id)
            customer = await ClientService.get_client_customer(db, current_user)
            ticket = await TicketService.reopen_by_client(
                db=db,
                ticket_id=tid,
                reason=reason,
                user=current_user,
                customer_id=customer.id,
            )
            return await TicketService.build_ticket_read(ticket)
        except Exception:
            pass

    from app.db.mongo import mongo_update_ticket_status
    return mongo_update_ticket_status(str(ticket_id), "open", note=f"Reopened by client: {reason}")
