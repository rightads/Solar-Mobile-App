"""Client (homeowner) portal. Every route is limited to the caller's own project."""
from datetime import datetime, timezone
from typing import List, Optional
import uuid
from fastapi import APIRouter, Body, Depends, File, Form, UploadFile, status
from app.core import access
from app.core.deps import MongoUserProxy, load_user, require_client
from app.core.exceptions import BadRequestException
from app.core.uploads import get_file_record, save_upload
from app.db.mongo import (
    _format_mongo_doc,
    get_mongo_db,
    mongo_create_notification,
    mongo_create_ticket,
    mongo_get_client_home,
    mongo_get_client_payments,
    mongo_get_tickets,
    mongo_record_client_payment,
    mongo_update_ticket_status,
)
from app.models.enums import PaymentMode
from app.schemas.ticket import TicketCommentCreate, TicketCreate

router = APIRouter(prefix="/client", tags=["Client Mobile Experience"])


def _ensure_project(user: MongoUserProxy) -> Optional[dict]:
    """Return the client's project, creating a registration-stage one if safe."""
    cust = access.client_customer(user)
    if cust:
        return cust
    db = get_mongo_db()
    if db is None:
        return None
    # A staff-created project with this phone exists but the client has not yet
    # proven they own the number: do not create a duplicate, ask for OTP instead.
    if db["customers"].find_one({"$or": [{"phone": user.phone}, {"mobile": user.phone}]}):
        return None
    now = datetime.now(timezone.utc)
    cid = str(uuid.uuid4())
    doc = {
        "_id": cid, "id": cid, "user_id": user.id,
        "name": user.name, "phone": user.phone, "mobile": user.phone, "email": user.email or "",
        "address": "", "capacity_kw": 0.0, "kw": 0.0, "final_price": 0, "total_amount": 0, "paid_amount": 0,
        "phase": "single", "panel_brand": "", "panel_watt": 0, "panel_count": 0, "inverter_brand": "",
        "structure_type": "", "stage": "REGISTRATION_SUBMITTED", "status": "active",
        "sales_id": None, "assigned_to": None, "milestones": [],
        "documents": {"e_bill": None, "aadhaar": None, "pan": None, "cancelled_cheque": None, "registry": None},
        "documents_count": 0, "created_at": now, "updated_at": now,
    }
    db["customers"].insert_one(doc)
    mongo_create_notification({
        "title": "New client registration",
        "body": f"{user.name} signed up and is waiting for a site survey.",
        "type": "client_registration",
        "target_role": "admin",
        "target_id": cid,
    })
    return doc


@router.get("/home", summary="Client dashboard: project, 10-stage timeline, contacts, payments")
async def get_client_home(current_user: MongoUserProxy = Depends(require_client)):
    customer = _ensure_project(current_user)
    data = mongo_get_client_home(load_user(current_user.id) or {}, customer)
    data["needs_phone_verification"] = customer is None and not current_user.is_phone_verified
    return data


@router.get("/payments", summary="Payments for the client's project")
async def get_client_payments(current_user: MongoUserProxy = Depends(require_client)):
    cust = access.client_customer(current_user)
    return mongo_get_client_payments(str(cust["_id"])) if cust else []


@router.post("/payments", status_code=status.HTTP_201_CREATED, summary="Submit a payment with an optional receipt")
async def submit_client_payment(
    amount: int = Form(..., gt=0, le=10_000_000_00, description="Amount in paise"),
    mode: PaymentMode = Form(..., description="Payment mode"),
    reference_no: Optional[str] = Form(None, max_length=60),
    paid_on: Optional[datetime] = Form(None),
    remarks: Optional[str] = Form(None, max_length=500),
    file: Optional[UploadFile] = File(None, description="Receipt image or PDF"),
    current_user: MongoUserProxy = Depends(require_client),
):
    cust = access.require_client_customer(current_user)
    proof = None
    if file is not None and file.filename:
        proof = await save_upload(file, category="payment_proofs", uploaded_by=current_user.id, customer_id=str(cust["_id"]))
    payment = mongo_record_client_payment(
        customer=cust,
        submitted_by=current_user.id,
        amount_paise=amount,
        mode=mode.value,
        reference_no=reference_no,
        paid_on=paid_on,
        remarks=remarks,
        proof=proof,
    )
    mongo_create_notification({
        "title": "New payment submitted",
        "body": f"{cust.get('name', 'A client')} submitted ₹{amount / 100:,.0f} for approval.",
        "type": "payment",
        "target_role": "sales" if not cust.get("sales_id") else None,
        "user_id": cust.get("sales_id"),
        "target_id": payment["id"],
    })
    return payment


@router.get("/documents", summary="KYC and project documents on file")
async def get_client_documents(current_user: MongoUserProxy = Depends(require_client)):
    cust = access.client_customer(current_user)
    return (cust or {}).get("documents") or {}


def _own_image_keys(user: MongoUserProxy, keys: Optional[List[str]]) -> List[str]:
    out = []
    for key in keys or []:
        rec = get_file_record(key)
        if rec and rec.get("uploaded_by") == user.id:
            out.append(rec["id"])
    return out


@router.post("/tickets", status_code=status.HTTP_201_CREATED, summary="Raise a post-installation service ticket")
async def create_client_ticket(data: TicketCreate, current_user: MongoUserProxy = Depends(require_client)):
    cust = access.require_client_customer(current_user)
    assignee = cust.get("service_employee_id")
    ticket = mongo_create_ticket({
        "customer_id": str(cust["_id"]),
        "customer_name": cust.get("name") or current_user.name,
        "customer_phone": cust.get("phone") or current_user.phone,
        "customer_address": cust.get("address", ""),
        "type": data.type.value,
        "title": data.title,
        "description": data.description,
        "error_code": data.error_code or "",
        "priority": data.priority.value,
        "images": _own_image_keys(current_user, data.image_keys),
        # Unassigned by default (admin queue) unless a dedicated engineer is linked.
        "assigned_to": assignee,
        "assigned_staff": cust.get("service_employee_name") if assignee else None,
        "assigned_staff_emp_no": cust.get("service_employee_no") if assignee else None,
        "status": "assigned" if assignee else "open",
    })
    mongo_create_notification({
        "title": "New service ticket",
        "body": f"{ticket['customer_name']} raised: {data.title}",
        "type": "ticket",
        "target_role": "admin",
        "target_id": ticket["id"],
    })
    if assignee:
        mongo_create_notification({
            "title": "Service ticket assigned to you",
            "body": f"{ticket['customer_name']}: {data.title}",
            "type": "ticket",
            "user_id": assignee,
            "target_id": ticket["id"],
        })
    return ticket


@router.get("/tickets", summary="Tickets raised for the client's project")
async def list_client_tickets(current_user: MongoUserProxy = Depends(require_client)):
    cust = access.client_customer(current_user)
    return mongo_get_tickets(customer_id=str(cust["_id"])) if cust else []


@router.get("/tickets/{ticket_id}", summary="Ticket details")
async def get_client_ticket(ticket_id: str, current_user: MongoUserProxy = Depends(require_client)):
    return _format_mongo_doc(access.require_ticket(current_user, ticket_id))


@router.post("/tickets/{ticket_id}/comments", status_code=status.HTTP_201_CREATED, summary="Reply on a ticket")
async def add_client_ticket_comment(
    ticket_id: str,
    data: TicketCommentCreate,
    current_user: MongoUserProxy = Depends(require_client),
):
    ticket = access.require_ticket(current_user, ticket_id)
    cmt = {
        "id": f"cmt_{uuid.uuid4().hex[:12]}",
        "ticket_id": str(ticket["_id"]),
        "author_id": current_user.id,
        "author_name": current_user.name,
        "author_role": "client",
        "message": data.message.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    get_mongo_db()["tickets"].update_one({"_id": ticket["_id"]}, {"$push": {"comments": cmt}})
    return cmt


@router.post("/tickets/{ticket_id}/reopen", summary="Reopen a resolved or closed ticket")
async def reopen_client_ticket(
    ticket_id: str,
    reason: str = Body(..., embed=True, min_length=3, max_length=500),
    current_user: MongoUserProxy = Depends(require_client),
):
    ticket = access.require_ticket(current_user, ticket_id)
    if str(ticket.get("status")) not in ("resolved", "closed"):
        raise BadRequestException("Only resolved or closed tickets can be reopened.")
    return mongo_update_ticket_status(str(ticket["_id"]), "reopened", note=f"Reopened by client: {reason.strip()}")
