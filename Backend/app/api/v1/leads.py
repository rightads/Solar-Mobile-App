"""Sales leads. Sales staff see their own leads plus the unassigned pool."""
from datetime import datetime, timezone
from typing import Literal, Optional
import re
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles
from app.core.exceptions import BadRequestException, NotFoundException
from app.core.helpers import paginate_list
from app.core.security import normalize_phone
from app.db.mongo import _format_mongo_doc, get_mongo_db, mongo_create_customer, mongo_get_salespersons
from app.models.enums import UserRole
from app.services import workflow

router = APIRouter(prefix="/leads", tags=["Leads"])
require_sales = require_roles(UserRole.ADMIN, UserRole.SALES)

LeadStatusT = Literal["new", "contacted", "qualified", "follow_up", "returned", "converted", "lost", "closed"]


class LeadIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., max_length=15)
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


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a lead")
async def create_lead(payload: LeadIn, current_user: MongoUserProxy = Depends(require_sales)):
    import uuid
    now = datetime.now(timezone.utc)
    lid = str(uuid.uuid4())
    kw = payload.kw if payload.kw is not None else (payload.expected_kw or 0)
    doc = {
        "_id": lid, "id": lid, "name": payload.name.strip(), "phone": _phone(payload.phone),
        "area": (payload.area or payload.address or "").strip(), "address": (payload.address or payload.area or "").strip(),
        "kw": float(kw), "expected_kw": float(kw), "source": (payload.source or "Direct").strip(),
        "notes": (payload.notes or "").strip(), "status": payload.status or "new",
        "assigned_sales_id": None if access.is_admin(current_user) else current_user.id,
        "assigned_sales_name": None if access.is_admin(current_user) else current_user.name,
        "created_by": current_user.id, "created_at": now, "updated_at": now,
    }
    get_mongo_db()["leads"].insert_one(doc)
    return _format_mongo_doc(doc)


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
        clauses.append({"$or": [{f: {"$regex": s, "$options": "i"}} for f in ("name", "phone", "area", "address")]})
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
    if updates.get("status") == "converted":
        raise BadRequestException("Use the convert action to close a sale.")
    if "reason" in updates:
        updates["lost_reason"] = updates.pop("reason")
    if not lead.get("assigned_sales_id") and not access.is_admin(current_user):
        updates["assigned_sales_id"], updates["assigned_sales_name"] = current_user.id, current_user.name
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
    cust = mongo_create_customer({
        **spec,
        "name": spec.get("name") or lead.get("name"),
        "phone": lead.get("phone"),
        "address": spec.get("address") or lead.get("address") or lead.get("area") or "",
        "capacity_kw": spec.get("capacity_kw") or lead.get("kw") or 0,
        "sales_id": sales_id,
        "sales_name": sales_name,
        "lead_id": str(lead["_id"]),
    })
    get_mongo_db()["leads"].update_one(
        {"_id": lead["_id"]},
        {"$set": {"status": "converted", "closed_at": now, "customer_id": cust["id"], "updated_at": now}},
    )
    workflow.mark_stage(cust["id"], "SALE_CONFIRMED", True, current_user)
    return _format_mongo_doc(get_mongo_db()["customers"].find_one({"_id": cust["id"]}))
