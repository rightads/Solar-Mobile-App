"""Customer (project) records. Staff only; each role sees only its own customers."""
from datetime import date, datetime, timezone
from typing import Literal, Optional
import uuid
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles, require_staff
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.helpers import paginate_list
from app.core.uploads import save_upload
from app.db.mongo import (
    _format_mongo_doc,
    get_mongo_db,
    mongo_create_customer,
    mongo_update_customer,
    mongo_update_customer_milestone,
)
from app.models.enums import CustomerStage, UserRole
from app.schemas.customer import CustomerCreate, CustomerStageUpdate

router = APIRouter(prefix="/customers", tags=["Customers"])

KYC_DOCUMENTS = ("e_bill", "aadhaar", "pan", "cancelled_cheque", "registry")
_DOC_ALIASES = {"cheque": "cancelled_cheque", "ebill": "e_bill", "electricity_bill": "e_bill"}


class CustomerPatch(BaseModel):
    """Editable customer fields. Anything else (stage, payments, documents,
    ownership links) is server-controlled and rejected."""
    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = Field(None, min_length=2, max_length=100)
    address: Optional[str] = Field(None, min_length=3, max_length=300)
    email: Optional[str] = Field(None, max_length=120)
    location_gps: Optional[str] = Field(None, max_length=60)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    capacity_kw: Optional[float] = Field(None, ge=0, le=1000)
    kw: Optional[float] = Field(None, ge=0, le=1000)
    final_price: Optional[int] = Field(None, ge=0, le=10_000_000_00)
    phase: Optional[Literal["single", "three"]] = None
    panel_brand: Optional[str] = Field(None, max_length=100)
    panel_watt: Optional[int] = Field(None, ge=0, le=2000)
    panel_count: Optional[int] = Field(None, ge=0, le=10000)
    inverter_brand: Optional[str] = Field(None, max_length=100)
    structure_type: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = Field(None, max_length=2000)
    # Admin-only assignment fields
    sales_id: Optional[str] = Field(None, max_length=64)
    service_employee_id: Optional[str] = Field(None, max_length=64)
    kedl_employee_id: Optional[str] = Field(None, max_length=64)
    site_employee_id: Optional[str] = Field(None, max_length=64)


ADMIN_ONLY_FIELDS = {"sales_id", "service_employee_id", "kedl_employee_id", "site_employee_id"}


class MilestoneIn(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: Optional[str] = Field(None, max_length=64)
    milestone_id: Optional[str] = Field(None, max_length=64)
    title: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[int] = Field(None, ge=0, le=10_000_000_00)
    status: Optional[Literal["pending", "verified"]] = None
    due_date: Optional[date] = None
    employee_verified_date: Optional[str] = Field(None, max_length=20)
    customer_verified_date: Optional[str] = Field(None, max_length=20)


def _sales_scope(user: MongoUserProxy) -> Optional[str]:
    return user.id if access.role_of(user) in access.SALES_ROLES else None


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a customer (Admin or Sales)")
async def create_customer(
    payload: CustomerCreate,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    data = payload.model_dump()
    data["phone"] = data.get("mobile")
    if access.is_admin(current_user) and payload.sales_id:
        sales = get_mongo_db()["users"].find_one({"_id": str(payload.sales_id)})
        if not sales or str(sales.get("role", "")).lower() not in access.SALES_ROLES or not sales.get("is_active"):
            raise BadRequestException("sales_id must be an active sales employee.")
        data["sales_id"], data["sales_name"] = str(sales["_id"]), sales.get("name")
    else:
        data["sales_id"], data["sales_name"] = current_user.id, current_user.name
    for forbidden in ("stage", "paid_amount", "documents", "documents_count", "milestones", "id", "user_id"):
        data.pop(forbidden, None)
    return mongo_create_customer(data)


@router.get("", summary="List customers visible to the caller")
async def list_customers(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    stage: Optional[CustomerStage] = Query(default=None),
    search: Optional[str] = Query(default=None, max_length=60),
    current_user: MongoUserProxy = Depends(require_staff),
):
    import re
    db = get_mongo_db()
    if db is None:
        return paginate_list(items=[], page=page, page_size=page_size)
    query: dict = {}
    if stage:
        query["stage"] = stage.value
    if search:
        s = re.escape(search.strip())
        query["$or"] = [{f: {"$regex": s, "$options": "i"}} for f in ("name", "phone", "mobile", "address")]
    cursor = db["customers"].find(query).sort("created_at", -1)
    visible = [c for c in cursor if access.staff_can_view_customer(current_user, c)]
    total = len(visible)
    start = (page - 1) * page_size
    items = [_format_mongo_doc(c) for c in visible[start:start + page_size]]
    return paginate_list(items=items, page=page, page_size=page_size, total=total)


@router.get("/{customer_id}", summary="Customer details")
async def get_customer(customer_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    return _format_mongo_doc(access.require_customer(current_user, customer_id))


@router.patch("/{customer_id}", summary="Update editable customer details (Admin or owning Sales)")
async def update_customer(
    customer_id: str,
    payload: CustomerPatch,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    cust = access.require_customer_write(current_user, customer_id)
    updates = payload.model_dump(exclude_unset=True)
    if not access.is_admin(current_user):
        blocked = ADMIN_ONLY_FIELDS & updates.keys()
        if blocked:
            raise BadRequestException(f"Only an admin can change: {', '.join(sorted(blocked))}.")
    for field in ("name", "address", "panel_brand", "inverter_brand", "structure_type", "notes", "location_gps"):
        if isinstance(updates.get(field), str):
            updates[field] = updates[field].strip()
    db = get_mongo_db()
    for key, name_key, no_key in (
        ("sales_id", "sales_name", None),
        ("service_employee_id", "service_employee_name", "service_employee_no"),
        ("kedl_employee_id", "kedl_employee_name", None),
        ("site_employee_id", "site_employee_name", None),
    ):
        if updates.get(key):
            emp = db["users"].find_one({"_id": updates[key], "is_active": True})
            if not emp or str(emp.get("role")) == "client":
                raise BadRequestException(f"{key} must reference an active employee.")
            updates[name_key] = emp.get("name")
            if no_key:
                updates[no_key] = emp.get("employee_no")
    if "capacity_kw" in updates and "kw" not in updates:
        updates["kw"] = updates["capacity_kw"]
    if "final_price" in updates:
        updates["total_amount"] = updates["final_price"]
    if not updates:
        return _format_mongo_doc(cust)
    return mongo_update_customer(str(cust["_id"]), updates)


@router.patch("/{customer_id}/stage", summary="Move a customer to a lifecycle stage (Admin)")
async def update_customer_stage(
    customer_id: str,
    payload: CustomerStageUpdate,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN)),
):
    cust = access.require_customer(current_user, customer_id)
    return mongo_update_customer(str(cust["_id"]), {"stage": payload.stage.value})


@router.post("/{customer_id}/milestones", summary="Add or verify a payment milestone")
async def update_customer_milestone(
    customer_id: str,
    payload: MilestoneIn,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    cust = access.require_customer_write(current_user, customer_id)
    milestone_id = payload.id or payload.milestone_id or str(uuid.uuid4())
    updates = payload.model_dump(exclude_unset=True, exclude={"id", "milestone_id"})
    if "due_date" in updates and updates["due_date"]:
        updates["due_date"] = updates["due_date"].isoformat()
    if updates.get("status") == "verified":
        updates["verified_by"] = current_user.name
        updates["verified_by_id"] = current_user.id
        updates["verified_at"] = datetime.now(timezone.utc).isoformat()
    elif updates.get("status") == "pending":
        updates.update({"verified_by": None, "verified_by_id": None, "verified_at": None,
                        "employee_verified_date": "", "customer_verified_date": ""})
    res = mongo_update_customer_milestone(str(cust["_id"]), str(milestone_id), updates)
    if not res:
        raise NotFoundException("Customer not found.")
    return res


@router.post("/{customer_id}/documents", status_code=status.HTTP_201_CREATED, summary="Upload a KYC document (JPG/PNG/PDF, max 10 MB)")
async def upload_document(
    customer_id: str,
    type: str = Form(..., max_length=40, description="e_bill, aadhaar, pan, cancelled_cheque or registry"),
    file: UploadFile = File(...),
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    cust = access.require_customer_write(current_user, customer_id)
    doc_key = type.strip().lower().replace("-", "_")
    doc_key = _DOC_ALIASES.get(doc_key, doc_key)
    if doc_key not in KYC_DOCUMENTS:
        raise BadRequestException(f"Unknown document type. Use one of: {', '.join(KYC_DOCUMENTS)}.")
    meta = await save_upload(file, category="kyc", uploaded_by=current_user.id, customer_id=str(cust["_id"]))
    meta["uploaded_by"] = current_user.name

    docs = dict(cust.get("documents") or {})
    docs[doc_key] = meta
    count = sum(1 for k in KYC_DOCUMENTS if docs.get(k))
    updates = {"documents": docs, "documents_count": count}
    if count == len(KYC_DOCUMENTS):
        updates["documents_verified"] = True
    mongo_update_customer(str(cust["_id"]), updates)
    if count == len(KYC_DOCUMENTS):
        from app.services.workflow import mark_stage
        mark_stage(str(cust["_id"]), "DOCUMENTS_RECEIVED", True, current_user)
    return {"status": "success", "doc_type": doc_key, "document": meta, "documents_count": count}


@router.delete("/{customer_id}/documents/{doc_type}", summary="Remove a KYC document (Admin or owning Sales)")
async def delete_document(
    customer_id: str,
    doc_type: str,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    cust = access.require_customer_write(current_user, customer_id)
    key = _DOC_ALIASES.get(doc_type.lower(), doc_type.lower())
    if key not in KYC_DOCUMENTS:
        raise BadRequestException("Unknown document type.")
    docs = dict(cust.get("documents") or {})
    docs[key] = None
    count = sum(1 for k in KYC_DOCUMENTS if docs.get(k))
    mongo_update_customer(str(cust["_id"]), {"documents": docs, "documents_count": count, "documents_verified": False})
    from app.services.workflow import mark_stage
    mark_stage(str(cust["_id"]), "DOCUMENTS_RECEIVED", False, current_user)
    return {"status": "success", "doc_type": key, "documents_count": count}


@router.get("/{customer_id}/documents", summary="List a customer's KYC documents")
async def list_documents(customer_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    cust = access.require_customer(current_user, customer_id)
    return cust.get("documents") or {}


@router.get("/{customer_id}/timeline", summary="Live 10-stage timeline")
async def get_timeline(customer_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    from app.services.workflow import build_timeline
    cust = access.require_customer(current_user, customer_id)
    return build_timeline(cust)


class StageToggle(BaseModel):
    stage: CustomerStage
    done: bool


@router.post("/{customer_id}/timeline", summary="Mark a lifecycle stage Done or Incomplete")
async def toggle_stage(customer_id: str, payload: StageToggle, current_user: MongoUserProxy = Depends(require_staff)):
    from app.services.workflow import build_timeline, can_toggle_stage, mark_stage
    cust = access.require_customer(current_user, customer_id)
    if not can_toggle_stage(current_user, cust, payload.stage.value):
        raise NotFoundException("Customer not found.")
    mark_stage(str(cust["_id"]), payload.stage.value, payload.done, current_user)
    return build_timeline(get_mongo_db()["customers"].find_one({"_id": cust["_id"]}))
