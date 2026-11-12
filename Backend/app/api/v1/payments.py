"""Payments: pending → sales_approved → verified (or rejected).

Clients can only read their own ledger; sales can only act on payments of
their own customers; only admins verify money into the company account.
"""
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
import structlog
from app.core import access
from app.core.deps import MongoUserProxy, get_current_user, require_roles
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.uploads import save_upload
from app.db.mongo import (
    _format_mongo_doc,
    get_mongo_db,
    mongo_create_notification,
    mongo_get_customer_payments,
    mongo_record_client_payment,
)
from app.models.enums import PaymentMode, UserRole
from app.services import workflow

logger = structlog.get_logger()
router = APIRouter(tags=["Payments"])
require_payment_staff = require_roles(UserRole.ADMIN, UserRole.SALES)


class RejectIn(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500)


class PaymentPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    amount: Optional[int] = Field(None, gt=0, le=10_000_000_00)
    mode: Optional[PaymentMode] = None
    reference_no: Optional[str] = Field(None, max_length=60)
    remarks: Optional[str] = Field(None, max_length=500)


def _payment(payment_id: str) -> dict:
    pid = str(payment_id)
    doc = get_mongo_db()["payments"].find_one({"$or": [{"_id": pid}, {"id": pid}]})
    if not doc:
        raise NotFoundException("Payment not found.")
    return doc


def _require_payment_access(user: MongoUserProxy, payment: dict, *, write: bool) -> dict:
    """Return the payment's customer if the user may act on it, else 404."""
    try:
        cust = access.require_customer_write(user, payment.get("customer_id")) if write \
            else access.require_customer(user, payment.get("customer_id"))
    except NotFoundException:
        raise NotFoundException("Payment not found.")
    return cust


def _recompute_paid(customer_id: str) -> int:
    db = get_mongo_db()
    verified = sum(int(p.get("amount", 0)) for p in db["payments"].find({"customer_id": customer_id, "status": "verified"}))
    db["customers"].update_one({"_id": customer_id}, {"$set": {"paid_amount": verified, "updated_at": datetime.now(timezone.utc)}})
    return verified


def _set(payment: dict, updates: dict) -> dict:
    from pymongo import ReturnDocument
    updates["updated_at"] = datetime.now(timezone.utc)
    return _format_mongo_doc(get_mongo_db()["payments"].find_one_and_update(
        {"_id": payment["_id"]}, {"$set": updates}, return_document=ReturnDocument.AFTER))


@router.post("/customers/{customer_id}/payments", status_code=status.HTTP_201_CREATED, summary="Record a payment received from a customer")
async def create_payment(
    customer_id: str,
    amount: int = Form(..., gt=0, le=10_000_000_00, description="Amount in paise"),
    mode: PaymentMode = Form(...),
    reference_no: Optional[str] = Form(None, max_length=60),
    paid_on: Optional[datetime] = Form(None),
    remarks: Optional[str] = Form(None, max_length=500),
    direct_verify: bool = Form(False, description="Admin only: mark as verified immediately"),
    file: Optional[UploadFile] = File(None),
    current_user: MongoUserProxy = Depends(require_payment_staff),
):
    cust = access.require_customer_write(current_user, customer_id)
    proof = None
    if file is not None and file.filename:
        proof = await save_upload(file, category="payment_proofs", uploaded_by=current_user.id, customer_id=str(cust["_id"]))
    payment = mongo_record_client_payment(
        customer=cust, submitted_by=current_user.id, submitted_by_role=access.role_of(current_user),
        amount_paise=amount, mode=mode.value, reference_no=reference_no, paid_on=paid_on,
        remarks=remarks, proof=proof,
    )
    now = datetime.now(timezone.utc)
    stored = _payment(payment["id"])
    if direct_verify and access.is_admin(current_user):
        payment = _set(stored, {"status": "verified", "verified_by": current_user.id,
                                "verified_by_name": current_user.name, "verified_at": now})
        _recompute_paid(str(cust["_id"]))
        workflow.on_payment_verified(str(cust["_id"]), current_user)
    else:
        payment = _set(stored, {"status": "sales_approved", "sales_approved_by": current_user.id,
                                "sales_approved_by_name": current_user.name,
                                "sales_approver_emp_no": current_user.employee_no, "sales_approved_at": now})
    return payment


@router.get("/customers/{customer_id}/payments", summary="A customer's payment ledger and summary")
async def get_customer_payments(customer_id: str, current_user: MongoUserProxy = Depends(get_current_user)):
    cust = access.require_customer(current_user, customer_id)
    return mongo_get_customer_payments(str(cust["_id"]))


@router.get("/payments/pending", summary="Payments awaiting approval for the caller")
async def list_pending_payments(current_user: MongoUserProxy = Depends(require_payment_staff)):
    db = get_mongo_db()
    statuses = ["pending", "sales_approved"] if access.is_admin(current_user) else ["pending"]
    out = []
    for p in db["payments"].find({"status": {"$in": statuses}}).sort("created_at", -1):
        cust = db["customers"].find_one({"_id": p.get("customer_id")})
        if cust and (access.is_admin(current_user) or access.staff_can_view_customer(current_user, cust)):
            out.append(_format_mongo_doc(p))
    return out


@router.post("/payments/{payment_id}/sales-approve", summary="Sales confirms a customer payment")
async def sales_approve_payment(payment_id: str, current_user: MongoUserProxy = Depends(require_payment_staff)):
    payment = _payment(payment_id)
    _require_payment_access(current_user, payment, write=True)
    if payment.get("status") != "pending":
        raise BadRequestException("Only pending payments can be approved.")
    res = _set(payment, {
        "status": "sales_approved",
        "sales_approved_by": current_user.id,
        "sales_approved_by_name": current_user.name,
        "sales_approver_emp_no": current_user.employee_no or "",
        "sales_approved_at": datetime.now(timezone.utc),
    })
    mongo_create_notification({
        "title": "Payment ready for verification",
        "body": f"₹{int(payment.get('amount', 0)) / 100:,.0f} from {payment.get('customer_name', 'a customer')} was approved by {current_user.name}.",
        "type": "payment", "target_role": "admin", "target_id": res["id"],
    })
    logger.info("payment_sales_approved", payment_id=res["id"], by=current_user.id)
    return res


@router.post("/payments/{payment_id}/verify", summary="Admin verifies money received")
async def verify_payment(payment_id: str, current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN))):
    payment = _payment(payment_id)
    if payment.get("status") not in ("pending", "sales_approved"):
        raise BadRequestException("This payment cannot be verified in its current state.")
    res = _set(payment, {"status": "verified", "verified_by": current_user.id,
                         "verified_by_name": current_user.name, "verified_at": datetime.now(timezone.utc)})
    cid = str(payment.get("customer_id"))
    _recompute_paid(cid)
    workflow.on_payment_verified(cid, current_user)
    logger.info("payment_verified", payment_id=res["id"], by=current_user.id)
    return res


@router.post("/payments/{payment_id}/reject", summary="Reject a payment with a reason")
async def reject_payment(payment_id: str, payload: RejectIn, current_user: MongoUserProxy = Depends(require_payment_staff)):
    payment = _payment(payment_id)
    _require_payment_access(current_user, payment, write=True)
    allowed = ("pending", "sales_approved") if access.is_admin(current_user) else ("pending",)
    if payment.get("status") not in allowed:
        raise BadRequestException("This payment cannot be rejected in its current state.")
    res = _set(payment, {"status": "rejected", "rejected_by": current_user.id, "rejected_by_name": current_user.name,
                         "rejection_reason": payload.reason.strip(), "rejected_at": datetime.now(timezone.utc)})
    _recompute_paid(str(payment.get("customer_id")))
    logger.info("payment_rejected", payment_id=res["id"], by=current_user.id)
    return res


@router.patch("/payments/{payment_id}", summary="Edit a payment while it is still pending")
async def update_payment(payment_id: str, payload: PaymentPatch, current_user: MongoUserProxy = Depends(get_current_user)):
    payment = _payment(payment_id)
    if access.role_of(current_user) in access.CLIENT_ROLES:
        if payment.get("submitted_by") != current_user.id:
            raise NotFoundException("Payment not found.")
    else:
        _require_payment_access(current_user, payment, write=True)
    if payment.get("status") != "pending":
        raise BadRequestException("Only pending payments can be edited.")
    updates = payload.model_dump(exclude_unset=True)
    if "mode" in updates and updates["mode"]:
        updates["mode"] = updates["mode"].value.upper()
    if "amount" in updates:
        updates["amount_paise"] = updates["amount"]
        updates["amount_rupees"] = updates["amount"] / 100.0
    return _set(payment, updates) if updates else _format_mongo_doc(payment)
