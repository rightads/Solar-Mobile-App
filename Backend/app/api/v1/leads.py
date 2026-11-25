"""Sales leads. Sales staff see their own leads plus the unassigned pool.

Any employee may create a lead (a referral). A salesman's own lead is assigned
to them; anyone else's goes to the unassigned pool for sales (and admins are
notified), and the referrer can follow it under /leads/referred.
"""
from datetime import datetime, timezone
from typing import Literal, Optional
import re
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.helpers import paginate_list
from app.core.security import normalize_email, normalize_phone
from app.schemas.customer import ProjectBom
from app.db.mongo import _format_mongo_doc, get_mongo_db, mongo_create_customer, mongo_get_salespersons
from app.models.enums import UserRole
from app.services import workflow

router = APIRouter(prefix="/leads", tags=["Leads"])
require_sales = require_roles(UserRole.ADMIN, UserRole.SALES)
require_staff = require_roles(*access.STAFF_ROLES)

LeadStatusT = Literal["new", "contacted", "qualified", "follow_up", "returned", "converted", "lost", "closed"]


class LeadIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., max_length=15)
    email: Optional[str] = Field(None, max_length=120)
    area: Optional[str] = Field(None, max_length=200)
    address: Optional[str] = Field(None, max_length=300)
    kw: Optional[float] = Field(None, ge=0, le=1000)
    expected_kw: Optional[float] = Field(None, ge=0, le=1000)
    source: Optional[str] = Field("Direct", max_length=60)
    notes: Optional[str] = Field(None, max_length=2000)
    status: Optional[LeadStatusT] = None


class LeadPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone: Optional[str] = Field(None, max_length=15)
    email: Optional[str] = Field(None, max_length=120)
    area: Optional[str] = Field(None, max_length=200)
    address: Optional[str] = Field(None, max_length=300)
    kw: Optional[float] = Field(None, ge=0, le=1000)
    expected_kw: Optional[float] = Field(None, ge=0, le=1000)
    source: Optional[str] = Field(None, max_length=60)
    notes: Optional[str] = Field(None, max_length=2000)
    status: Optional[LeadStatusT] = None
    follow_up_date: Optional[datetime] = None
    reason: Optional[str] = Field(None, max_length=500)


class AssignIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    sales_id: Optional[str] = Field(None, max_length=64)
    assigned_sales_id: Optional[str] = Field(None, max_length=64)


class LostIn(BaseModel):
    reason: str = Field("Lost", min_length=2, max_length=500)


class ConvertIn(BaseModel):
    """Only quote/specification fields; ownership, stage and money are server-set."""
    model_config = ConfigDict(extra="ignore")
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    address: Optional[str] = Field(None, max_length=300)
    email: Optional[str] = Field(None, max_length=120)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_gps: Optional[str] = Field(None, max_length=60)
    final_price: Optional[int] = Field(None, ge=0, le=10_000_000_00)
    capacity_kw: Optional[float] = Field(None, ge=0, le=1000)
    phase: Optional[Literal["single", "three"]] = None
    panel_brand: Optional[str] = Field(None, max_length=100)
    panel_watt: Optional[int] = Field(None, ge=0, le=2000)
    panel_count: Optional[int] = Field(None, ge=0, le=10000)
    inverter_brand: Optional[str] = Field(None, max_length=100)
    structure_type: Optional[str] = Field(None, max_length=100)
    bom: Optional[ProjectBom] = None


def _scope(user: MongoUserProxy) -> dict:
    if access.is_admin(user):
        return {}
    return {"$or": [{"assigned_sales_id": user.id}, {"assigned_sales_id": None},
                    {"assigned_sales_id": ""}, {"assigned_sales_id": {"$exists": False}}]}


def _require_lead(user: MongoUserProxy, lead_id: str) -> dict:
    lid = str(lead_id)
    lead = get_mongo_db()["leads"].find_one({"$and": [{"$or": [{"_id": lid}, {"id": lid}]}, _scope(user)]})
    if not lead:
        raise NotFoundException("Lead not found.")
    return lead


def _phone(raw: str) -> str:
    try:
        return normalize_phone(raw)
    except ValueError as e:
        raise BadRequestException(str(e))


def _email(raw: Optional[str]) -> Optional[str]:
    if not raw or not str(raw).strip():
        return None
    try:
        return normalize_email(raw)
    except ValueError as e:
        raise BadRequestException(str(e))


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a lead (any employee)")
async def create_lead(payload: LeadIn, current_user: MongoUserProxy = Depends(require_staff)):
    import uuid
    db = get_mongo_db()
    now = datetime.now(timezone.utc)
    lid = str(uuid.uuid4())
    kw = payload.kw if payload.kw is not None else (payload.expected_kw or 0)
    role = access.role_of(current_user)
    is_sales = role in access.SALES_ROLES
    referral = not is_sales and not access.is_admin(current_user)
    phone = _phone(payload.phone)
    email = _email(payload.email)
    if referral and db["leads"].find_one({"phone": phone, "status": {"$nin": ["lost", "closed"]}}):
        raise BadRequestException("This customer is already a lead. Sales is on it.")
    matched_client = access.find_verified_client_for_contact(phone=phone, email=email)
    linked_uid = str(matched_client["_id"]) if matched_client else None
    if not email and matched_client and matched_client.get("email"):
        email = str(matched_client["email"]).strip().lower()
    department = access.DEPARTMENT_LABELS.get(access.normalize_department(role) or "", role.title())
    doc = {
        "_id": lid, "id": lid, "name": payload.name.strip(), "phone": phone, "email": email,
        "user_id": linked_uid,
        "area": (payload.area or payload.address or "").strip(), "address": (payload.address or payload.area or "").strip(),
        "kw": float(kw), "expected_kw": float(kw),
        "source": (f"Referral: {current_user.name} ({department})" if referral else (payload.source or "Direct")).strip()[:60],
        "notes": (payload.notes or "").strip(), "status": "new" if referral else (payload.status or "new"),
        # A salesman keeps their own lead; admins and other employees feed the sales pool.
        "assigned_sales_id": current_user.id if is_sales else None,
        "assigned_sales_name": current_user.name if is_sales else None,
        "created_by": current_user.id, "created_by_name": current_user.name, "created_by_role": role,
        "referred_by_id": current_user.id if referral else None,
        "referred_by_name": current_user.name if referral else None,
        "created_at": now, "updated_at": now,
    }
    db["leads"].insert_one(doc)
    if referral:
        try:
            from app.db.mongo import mongo_create_notification
            mongo_create_notification({
                "title": "New lead referred",
                "body": f"{current_user.name} ({department}) referred {doc['name']}. Assign it to a salesman.",
                "type": "lead", "target_role": "admin", "target_id": lid,
            })
        except Exception:
            pass
    return _format_mongo_doc(doc)


@router.get("/referred", summary="Leads I referred (any employee) and how they are going")
async def my_referred_leads(current_user: MongoUserProxy = Depends(require_staff)):
    cursor = get_mongo_db()["leads"].find({"created_by": current_user.id}).sort("created_at", -1).limit(200)
    fields = ("id", "name", "area", "kw", "status", "assigned_sales_name", "created_at", "updated_at")
    out = []
    for d in cursor:
        f = _format_mongo_doc(d)
        out.append({k: f.get(k) for k in fields})
    return out


@router.get("", summary="Leads visible to the caller")
async def list_leads(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status: Optional[str] = Query(default=None, max_length=20),
    search: Optional[str] = Query(default=None, max_length=60),
    current_user: MongoUserProxy = Depends(require_sales),
):
    clauses = [_scope(current_user)]
    if status and status.lower() != "all":
        clauses.append({"status": status.lower()})
    if search:
        s = re.escape(search.strip())
        clauses.append({"$or": [{f: {"$regex": s, "$options": "i"}} for f in ("name", "phone", "email", "area", "address")]})
    col = get_mongo_db()["leads"]
    query = {"$and": clauses}
    total = col.count_documents(query)
    cursor = col.find(query).sort("created_at", -1).skip((page - 1) * page_size).limit(page_size)
    return paginate_list(items=[_format_mongo_doc(d) for d in cursor], page=page, page_size=page_size, total=total)


@router.get("/salespersons", summary="Sales staff available for assignment")
async def list_salespersons(current_user: MongoUserProxy = Depends(require_sales)):
    return mongo_get_salespersons()


@router.get("/sales-closed", summary="Converted leads")
async def list_sales_closed(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: MongoUserProxy = Depends(require_sales),
):
    query = {"$and": [_scope(current_user), {"status": "converted"}]}
    col = get_mongo_db()["leads"]
    cursor = col.find(query).sort("closed_at", -1).skip((page - 1) * page_size).limit(page_size)
    return paginate_list(items=[_format_mongo_doc(d) for d in cursor], page=page, page_size=page_size,
                         total=col.count_documents(query))


@router.get("/{lead_id}", summary="Lead details")
async def get_lead(lead_id: str, current_user: MongoUserProxy = Depends(require_sales)):
    return _format_mongo_doc(_require_lead(current_user, lead_id))


@router.patch("/{lead_id}", summary="Update a lead")
async def update_lead(lead_id: str, payload: LeadPatch, current_user: MongoUserProxy = Depends(require_sales)):
    lead = _require_lead(current_user, lead_id)
    updates = payload.model_dump(exclude_unset=True)
    if "phone" in updates and updates["phone"]:
        updates["phone"] = _phone(updates["phone"])
    if "email" in updates:
        updates["email"] = _email(updates["email"])
    if updates.get("status") == "converted":
        raise BadRequestException("Use the convert action to close a sale.")
    if "reason" in updates:
        updates["lost_reason"] = updates.pop("reason")
    if not lead.get("assigned_sales_id") and not access.is_admin(current_user):
        updates["assigned_sales_id"], updates["assigned_sales_name"] = current_user.id, current_user.name
    if not lead.get("user_id") or "phone" in updates or "email" in updates:
        matched_client = access.find_verified_client_for_contact(
            phone=updates.get("phone") or lead.get("phone"),
            email=updates.get("email") if "email" in updates else lead.get("email"),
        )
        if matched_client:
            updates["user_id"] = str(matched_client["_id"])
    updates["updated_at"] = datetime.now(timezone.utc)
    from pymongo import ReturnDocument
    res = get_mongo_db()["leads"].find_one_and_update({"_id": lead["_id"]}, {"$set": updates},
                                                       return_document=ReturnDocument.AFTER)
    return _format_mongo_doc(res)


@router.post("/{lead_id}/assign", summary="Assign a lead to a salesperson")
async def reassign_lead(lead_id: str, payload: AssignIn, current_user: MongoUserProxy = Depends(require_sales)):
    lead = _require_lead(current_user, lead_id)
    target = payload.sales_id or payload.assigned_sales_id or current_user.id
    if not access.is_admin(current_user) and target != current_user.id:
        raise BadRequestException("Only an admin can assign leads to other salespeople.")
    sales = get_mongo_db()["users"].find_one({"_id": target, "is_active": True})
    if not sales or str(sales.get("role", "")).lower() not in access.SALES_ROLES:
        raise BadRequestException("Leads can only be assigned to active sales staff.")
    from pymongo import ReturnDocument
    res = get_mongo_db()["leads"].find_one_and_update(
        {"_id": lead["_id"]},
        {"$set": {"assigned_sales_id": str(sales["_id"]), "assigned_sales_name": sales.get("name"),
                  "status": "contacted" if lead.get("status") == "new" else lead.get("status"),
                  "updated_at": datetime.now(timezone.utc)}},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res)


@router.post("/{lead_id}/mark-lost", summary="Mark a lead as lost")
async def mark_lead_lost(lead_id: str, payload: LostIn, current_user: MongoUserProxy = Depends(require_sales)):
    lead = _require_lead(current_user, lead_id)
    get_mongo_db()["leads"].update_one(
        {"_id": lead["_id"]},
        {"$set": {"status": "lost", "lost_reason": payload.reason.strip(), "updated_at": datetime.now(timezone.utc)}},
    )
    return {"status": "success", "lead_id": str(lead["_id"])}


@router.post("/{lead_id}/convert", summary="Convert a lead into a customer (closed sale)")
async def convert_lead(lead_id: str, payload: Optional[ConvertIn] = None, current_user: MongoUserProxy = Depends(require_sales)):
    lead = _require_lead(current_user, lead_id)
    if lead.get("status") == "converted":
        raise BadRequestException("This lead has already been converted.")
    payload = payload or ConvertIn()
    now = datetime.now(timezone.utc)
    sales_id = lead.get("assigned_sales_id") or (None if access.is_admin(current_user) else current_user.id)
    sales_name = lead.get("assigned_sales_name") or (None if access.is_admin(current_user) else current_user.name)
    spec = payload.model_dump(exclude_none=True)
    if payload.bom is not None:
        spec["bom"] = payload.bom.cleaned()
    lid_str = str(lead["_id"])
    lead_email = _email(spec.get("email")) or lead.get("email") or ""
    cust = mongo_create_customer({
        **spec,
        "name": spec.get("name") or lead.get("name"),
        "phone": lead.get("phone"),
        "email": lead_email,
        "user_id": lead.get("user_id"),
        "address": spec.get("address") or lead.get("address") or lead.get("area") or "",
        "capacity_kw": spec.get("capacity_kw") or lead.get("capacity_kw") or lead.get("kw") or 0,
        "final_price": spec.get("final_price") or lead.get("final_price") or 0,
        "panel_brand": spec.get("panel_brand") or lead.get("panel_brand") or "",
        "panel_watt": spec.get("panel_watt") or lead.get("panel_watt") or 0,
        "panel_count": spec.get("panel_count") or lead.get("panel_count") or 0,
        "inverter_brand": spec.get("inverter_brand") or lead.get("inverter_brand") or "",
        "structure_type": spec.get("structure_type") or lead.get("structure_type") or "",
        "bom": spec.get("bom") or lead.get("bom") or {},
        "approved_quotation_id": lead.get("approved_quotation_id"),
        "quotation_approved_at": lead.get("quotation_approved_at"),
        "sales_id": sales_id,
        "sales_name": sales_name,
        "lead_id": lid_str,
    })
    db = get_mongo_db()
    db["leads"].update_one(
        {"_id": lead["_id"]},
        {"$set": {"status": "converted", "closed_at": now, "customer_id": cust["id"], "updated_at": now}},
    )
    # Transfer any quotations created on this lead over to the new customer record.
    db["quotations"].update_many(
        {"$or": [{"customer_id": lid_str}, {"lead_id": lid_str}]},
        {"$set": {"customer_id": cust["id"], "lead_id": lid_str, "target_type": "customer"}},
    )
    if lead.get("approved_quotation_id"):
        approved_q = db["quotations"].find_one({"_id": str(lead["approved_quotation_id"])})
        if approved_q:
            from app.api.v1.quotations import _apply_to_customer
            cust_doc = db["customers"].find_one({"_id": cust["id"]}) or cust
            db["customers"].update_one({"_id": cust["id"]}, {"$set": _apply_to_customer(cust_doc, approved_q)})
    workflow.on_customer_created(cust["id"])
    if lead.get("approved_quotation_id"):
        workflow.on_quotation_approved(cust["id"])
    return _format_mongo_doc(db["customers"].find_one({"_id": cust["id"]}))
