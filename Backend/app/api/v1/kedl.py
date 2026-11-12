"""KEDL discom paperwork: name change, load enhancement and net-metering files,
their demand notices and documents. Approving the net-metering file makes the
customer's system live (see services.workflow)."""
from datetime import date, datetime, timezone
from typing import Literal, Optional
import uuid
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.uploads import save_upload
from app.db.mongo import _format_mongo_doc, get_mongo_db, mongo_get_kedl_dashboard
from app.models.enums import UserRole
from app.services import workflow

router = APIRouter(tags=["KEDL Tracker"])
require_kedl = require_roles(UserRole.ADMIN, UserRole.KEDL)
require_kedl_or_sales = require_roles(UserRole.ADMIN, UserRole.KEDL, UserRole.SALES)

FileType = Literal["name_change", "load", "net"]
FileStatus = Literal["not_started", "submitted", "demand_raised", "demand_paid", "approved"]


class KedlFileIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    customer_id: str = Field(..., min_length=1, max_length=64)
    file_type: FileType
    application_no: Optional[str] = Field(None, max_length=60)
    remarks: Optional[str] = Field(None, max_length=2000)


class KedlFilePatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    application_no: Optional[str] = Field(None, max_length=60)
    remarks: Optional[str] = Field(None, max_length=2000)
    meter_no: Optional[str] = Field(None, max_length=40)
    sanctioned_kw: Optional[float] = Field(None, ge=0, le=1000)


class KedlStatusIn(BaseModel):
    status: FileStatus
    note: Optional[str] = Field(None, max_length=1000)


class DemandIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    description: str = Field("Demand notice", min_length=1, max_length=300)
    amount: int = Field(..., ge=0, le=10_000_000_00, description="Amount in paise")
    due_date: Optional[date] = None
    notice_no: Optional[str] = Field(None, max_length=60)


def _files():
    return get_mongo_db()["kedl_files"]


def _require_file(user: MongoUserProxy, file_id: str) -> dict:
    fid = str(file_id)
    doc = _files().find_one({"$or": [{"_id": fid}, {"id": fid}]})
    if not doc:
        raise NotFoundException("KEDL file not found.")
    role = access.role_of(user)
    if role in access.SALES_ROLES:
        try:
            access.require_customer_write(user, doc.get("customer_id"))
        except NotFoundException:
            raise NotFoundException("KEDL file not found.")
    elif role in access.KEDL_ROLES and doc.get("assigned_to") not in (None, "", user.id):
        raise NotFoundException("KEDL file not found.")
    return doc


def _save(doc: dict, updates: dict, user: MongoUserProxy, push: Optional[dict] = None) -> dict:
    from pymongo import ReturnDocument
    updates["updated_at"] = datetime.now(timezone.utc)
    op: dict = {"$set": updates}
    if push:
        op["$push"] = push
    return get_mongo_db()["kedl_files"].find_one_and_update({"_id": doc["_id"]}, op, return_document=ReturnDocument.AFTER)


def _new_file(cust: dict, file_type: str, assignee: Optional[str]) -> dict:
    now = datetime.now(timezone.utc)
    fid = str(uuid.uuid4())
    return {
        "_id": fid, "id": fid, "customer_id": str(cust["_id"]), "customer_name": cust.get("name", ""),
        "location": cust.get("address", ""), "file_type": file_type, "status": "not_started",
        "application_no": None, "remarks": None, "demand_amount": 0, "demands": [], "documents": [],
        "status_log": [], "assigned_to": assignee or cust.get("kedl_employee_id"),
        "created_at": now, "updated_at": now,
    }


@router.post("/kedl-files", status_code=status.HTTP_201_CREATED, summary="Create a KEDL file for a customer")
async def create_or_update_kedl_file(payload: KedlFileIn, current_user: MongoUserProxy = Depends(require_kedl_or_sales)):
    cust = access.require_customer(current_user, payload.customer_id) if access.role_of(current_user) in access.KEDL_ROLES | access.ADMIN_ROLES \
        else access.require_customer_write(current_user, payload.customer_id)
    existing = _files().find_one({"customer_id": str(cust["_id"]), "file_type": payload.file_type})
    if existing:
        updates = payload.model_dump(exclude_unset=True, include={"application_no", "remarks"})
        return _format_mongo_doc(_save(existing, updates, current_user) if updates else existing)
    doc = _new_file(cust, payload.file_type, current_user.id if access.role_of(current_user) in access.KEDL_ROLES else None)
    doc["application_no"], doc["remarks"] = payload.application_no, payload.remarks
    _files().insert_one(doc)
    return _format_mongo_doc(doc)


@router.post("/customers/{customer_id}/kedl-files/init", status_code=status.HTTP_201_CREATED, summary="Create the three KEDL files for a customer")
async def init_kedl_files(customer_id: str, current_user: MongoUserProxy = Depends(require_kedl_or_sales)):
    cust = access.require_customer(current_user, customer_id) if access.role_of(current_user) in access.KEDL_ROLES | access.ADMIN_ROLES \
        else access.require_customer_write(current_user, customer_id)
    out = []
    for ft in ("name_change", "load", "net"):
        existing = _files().find_one({"customer_id": str(cust["_id"]), "file_type": ft})
        if not existing:
            existing = _new_file(cust, ft, None)
            _files().insert_one(existing)
        out.append(_format_mongo_doc(existing))
    return out


@router.get("/kedl-files", summary="KEDL files visible to the caller")
async def list_kedl_files(
    customer_id: Optional[str] = Query(default=None, max_length=64),
    file_type: Optional[str] = Query(default=None, max_length=20),
    status_filter: Optional[str] = Query(default=None, alias="status", max_length=20),
    current_user: MongoUserProxy = Depends(require_kedl_or_sales),
):
    query: dict = {}
    if customer_id:
        query["customer_id"] = customer_id
    if file_type and file_type != "all":
        query["file_type"] = file_type
    if status_filter and status_filter != "all":
        query["status"] = status_filter
    role = access.role_of(current_user)
    if role in access.KEDL_ROLES:
        query["$or"] = [{"assigned_to": current_user.id}, {"assigned_to": None}, {"assigned_to": {"$exists": False}}]
    db = get_mongo_db()
    out = []
    for f in _files().find(query).sort("updated_at", -1):
        if role in access.SALES_ROLES:
            cust = db["customers"].find_one({"_id": f.get("customer_id")})
            if not cust or str(cust.get("sales_id") or "") not in ("", current_user.id):
                continue
        out.append(_format_mongo_doc(f))
    return out


@router.get("/kedl/dashboard", summary="KEDL paperwork counts and demand totals")
async def get_kedl_dashboard(current_user: MongoUserProxy = Depends(require_kedl)):
    return mongo_get_kedl_dashboard()


@router.get("/kedl-files/{file_id}", summary="KEDL file with demands and documents")
async def get_kedl_file(file_id: str, current_user: MongoUserProxy = Depends(require_kedl_or_sales)):
    return _format_mongo_doc(_require_file(current_user, file_id))


@router.patch("/kedl-files/{file_id}", summary="Edit application number, remarks or meter details")
async def update_kedl_file(file_id: str, payload: KedlFilePatch, current_user: MongoUserProxy = Depends(require_kedl)):
    doc = _require_file(current_user, file_id)
    updates = payload.model_dump(exclude_unset=True)
    return _format_mongo_doc(_save(doc, updates, current_user) if updates else doc)


@router.post("/kedl-files/{file_id}/status", summary="Move a KEDL file through its stages")
async def update_kedl_status(file_id: str, payload: KedlStatusIn, current_user: MongoUserProxy = Depends(require_kedl)):
    doc = _require_file(current_user, file_id)
    now = datetime.now(timezone.utc)
    updates: dict = {"status": payload.status}
    if payload.status == "submitted" and not doc.get("submitted_on"):
        updates["submitted_on"] = now.isoformat()
    if payload.status == "approved":
        updates["approved_on"] = now.isoformat()
        updates["approved_at"] = now
        updates["approved_by"] = current_user.name
    elif doc.get("status") == "approved":
        updates.update({"approved_on": None, "approved_at": None, "approved_by": None})
    if not doc.get("assigned_to") and access.role_of(current_user) in access.KEDL_ROLES:
        updates["assigned_to"] = current_user.id
    log = {"from": doc.get("status"), "to": payload.status, "by": current_user.name,
           "note": (payload.note or "").strip() or None, "at": now.isoformat()}
    res = _save(doc, updates, current_user, push={"status_log": log})
    if (doc.get("status") == "approved") != (payload.status == "approved"):
        workflow.on_kedl_file_status(res, current_user)
    return _format_mongo_doc(res)


@router.post("/kedl-files/{file_id}/demands", summary="Record a demand notice from the discom")
async def raise_demand(file_id: str, payload: DemandIn, current_user: MongoUserProxy = Depends(require_kedl)):
    doc = _require_file(current_user, file_id)
    now = datetime.now(timezone.utc)
    demand = {
        "id": f"dmd_{uuid.uuid4().hex[:16]}",
        "kedl_file_id": str(doc["_id"]),
        "description": payload.description.strip(),
        "amount": payload.amount,
        "amount_paise": payload.amount,
        "due_date": payload.due_date.isoformat() if payload.due_date else None,
        "notice_no": payload.notice_no,
        "status": "open",
        "raised_by": current_user.name,
        "raised_on": now.isoformat(),
        "paid_on": None,
        "receipt_url": None,
    }
    total = sum(int(d.get("amount", 0)) for d in doc.get("demands") or []) + payload.amount
    _save(doc, {"status": "demand_raised", "demand_amount": total}, current_user, push={"demands": demand})
    return demand


@router.patch("/kedl-demands/{demand_id}", summary="Mark a demand paid or waived (optional receipt)")
async def update_demand(
    demand_id: str,
    status: Literal["paid", "waived"] = Form(...),
    paid_on: Optional[datetime] = Form(None),
    receipt_file: Optional[UploadFile] = File(None),
    current_user: MongoUserProxy = Depends(require_kedl),
):
    doc = _files().find_one({"demands.id": demand_id})
    if not doc:
        raise NotFoundException("Demand not found.")
    doc = _require_file(current_user, str(doc["_id"]))
    receipt = None
    if receipt_file is not None and receipt_file.filename:
        receipt = await save_upload(receipt_file, category="kedl_receipts", uploaded_by=current_user.id,
                                    customer_id=str(doc.get("customer_id") or ""))
    demands = list(doc.get("demands") or [])
    target = None
    for d in demands:
        if d.get("id") == demand_id:
            d["status"] = status
            d["paid_on"] = (paid_on or datetime.now(timezone.utc)).isoformat() if status == "paid" else None
            if receipt:
                d["receipt_key"], d["receipt_url"] = receipt["file_id"], receipt["url"]
            target = d
    if target is None:
        raise NotFoundException("Demand not found.")
    updates: dict = {"demands": demands}
    if all(d.get("status") in ("paid", "waived") for d in demands):
        updates["status"] = "demand_paid"
        updates["demand_paid_date"] = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    _save(doc, updates, current_user)
    return target


@router.post("/kedl-files/{file_id}/documents", status_code=status.HTTP_201_CREATED, summary="Attach a document to a KEDL file")
async def upload_kedl_document(
    file_id: str,
    doc_type: str = Form("other", max_length=40),
    file: UploadFile = File(...),
    current_user: MongoUserProxy = Depends(require_kedl),
):
    doc = _require_file(current_user, file_id)
    meta = await save_upload(file, category="kedl_documents", uploaded_by=current_user.id,
                             customer_id=str(doc.get("customer_id") or ""))
    entry = {
        "id": meta["file_id"],
        "kedl_file_id": str(doc["_id"]),
        "doc_type": "".join(c for c in doc_type.lower() if c.isalnum() or c == "_")[:40] or "other",
        "file_key": meta["file_id"],
        "original_name": meta["filename"],
        "download_url": meta["url"],
        "uploaded_by": current_user.name,
        "created_at": meta["uploaded_at"],
    }
    _save(doc, {}, current_user, push={"documents": entry})
    return entry
