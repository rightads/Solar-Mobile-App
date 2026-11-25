"""Project quotations: prepared by the salesman (or an admin) and sent to one
customer, who approves or rejects them in the client app.

Lifecycle of each quotation document::

    sent ──► approved   (final: no endpoint can change or delete it)
      │
      ├────► rejected   (client remark required; staff then send a new version)
      │
      └────► superseded (staff sent a newer version before the client answered)

Quotations are never edited: a change is always a new version. Once one is
approved the customer's price and system specs are copied from it and locked
(see customers.QUOTATION_LOCKED_FIELDS), and no further quotations can be sent.
"""
from datetime import datetime, timezone
from typing import Dict, List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pymongo import ReturnDocument
import structlog
from app.core import access
from app.core.deps import MongoUserProxy, require_client, require_roles
from app.core.exceptions import BadRequestException, NotFoundException
from app.db.mongo import _format_mongo_doc, get_mongo_db, mongo_create_notification
from app.models.enums import UserRole
from app.schemas.customer import ProjectBom

logger = structlog.get_logger()
router = APIRouter(prefix="/quotations", tags=["Quotations"])
require_quote_staff = require_roles(UserRole.ADMIN, UserRole.SALES)

# Equipment lines of a quotation, in display order.
ITEM_LABELS: Dict[str, str] = {
    "solar_module": "Solar Module",
    "solar_inverter": "Solar Inverter",
    "solar_structure": "Solar Structure",
    "acdb": "ACDB",
    "dcdb": "DCDB",
    "ac_wire": "AC Wire",
    "dc_wire": "DC Wire",
    "earthing_wire": "Earthing Wire",
    "lightning_arrester": "Lightning Arrester",
    "earthing_kit": "Earthing Kit",
    "solar_meter": "Solar Meter",
    "civil_work": "Civil Work",
}
_MONEY = Field(0, ge=0, le=10_000_000, description="Rupees")


class QuoteItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    make: str = Field("", max_length=80, description="Brand")
    capacity: str = Field("", max_length=40, description="e.g. 540 W, 5 kW")
    size: str = Field("", max_length=40, description="e.g. 4 sq mm")
    quantity: float = Field(0, ge=0, le=100_000)
    technology: str = Field("", max_length=80)
    other: str = Field("", max_length=300)


class OtherItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str = Field(..., min_length=1, max_length=100)
    details: str = Field("", max_length=500)


class QuotationIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    customer_id: str = Field(..., min_length=1, max_length=64)
    capacity_kw: float = Field(..., gt=0, le=1000)
    load_kw: float = Field(0, ge=0, le=1000)
    project_cost: float = Field(..., gt=0, le=10_000_000, description="Rupees")
    discom_charges: float = _MONEY
    file_charges: float = _MONEY
    items: Dict[str, QuoteItem] = Field(default_factory=dict)
    other_items: List[OtherItem] = Field(default_factory=list, max_length=10)
    remark: str = Field(..., min_length=1, max_length=2000)
    revision_of: Optional[str] = Field(None, max_length=64, description="The rejected quotation this replaces")

    @field_validator("items")
    @classmethod
    def _known_items(cls, v: Dict[str, QuoteItem]) -> Dict[str, QuoteItem]:
        unknown = sorted(set(v) - set(ITEM_LABELS))
        if unknown:
            raise ValueError(f"Unknown quotation items: {', '.join(unknown)}.")
        return v

    @field_validator("remark")
    @classmethod
    def _remark_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("A remark is required.")
        return v


class RejectIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    remark: str = Field(..., min_length=3, max_length=2000)


def _col():
    return get_mongo_db()["quotations"]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _out(doc: dict) -> dict:
    out = _format_mongo_doc(doc)
    out["item_labels"] = ITEM_LABELS
    out["locked"] = doc.get("status") == "approved"
    return out


def _notify(title: str, body: str, *, user_id: Optional[str] = None, role: Optional[str] = None,
            target: Optional[str] = None) -> None:
    try:
        mongo_create_notification({"title": title, "body": body, "type": "quotation",
                                   "user_id": user_id, "target_role": None if user_id else role, "target_id": target})
    except Exception as e:  # never fail the request on a notification
        logger.warning("quotation_notify_failed", error=str(e))


def _client_user_id(target: dict) -> Optional[str]:
    """The client account for a project or lead: the linked one, else the verified
    client account matching the phone or email."""
    if target.get("user_id"):
        return str(target["user_id"])
    matched = access.find_verified_client_for_contact(
        phone=target.get("phone") or target.get("mobile"),
        email=target.get("email"),
    )
    return str(matched["_id"]) if matched else None


def _resolve_quote_target(user: MongoUserProxy, target_id: str, *, write: bool = False) -> tuple[str, dict]:
    """Resolve ``target_id`` as either a customer or an unconverted lead."""
    db = get_mongo_db()
    tid = str(target_id)
    if db["customers"].find_one({"$or": [{"_id": tid}, {"id": tid}]}, {"_id": 1}):
        cust = access.require_customer_write(user, tid) if write else access.require_customer(user, tid)
        return "customer", cust
    if db["leads"].find_one({"$or": [{"_id": tid}, {"id": tid}]}, {"_id": 1}):
        lead = access.require_lead_write(user, tid) if write else access.require_lead(user, tid)
        if lead.get("status") == "converted" and lead.get("customer_id"):
            cid = str(lead["customer_id"])
            if db["customers"].find_one({"$or": [{"_id": cid}, {"id": cid}]}, {"_id": 1}):
                cust = access.require_customer_write(user, cid) if write else access.require_customer(user, cid)
                return "customer", cust
        return "lead", lead
    raise NotFoundException("Customer or lead not found.")


def _staff_quote(user: MongoUserProxy, quotation_id: str) -> dict:
    doc = _col().find_one({"_id": str(quotation_id)})
    if not doc:
        raise NotFoundException("Quotation not found.")
    _resolve_quote_target(user, doc["customer_id"], write=False)
    return doc


def _apply_to_customer(cust: dict, q: dict) -> dict:
    """Customer fields set from the approved quotation (and then locked)."""
    items = q.get("items") or {}

    def item(key: str) -> dict:
        return items.get(key) or {}

    def as_int(value) -> Optional[int]:
        digits = "".join(ch for ch in str(value or "") if ch.isdigit() or ch == ".")
        try:
            return int(float(digits)) if digits else None
        except ValueError:
            return None

    total_paise = int(round(float(q["total_amount"]) * 100))
    module, inverter, structure = item("solar_module"), item("solar_inverter"), item("solar_structure")
    bom_raw = {
        "inverter_count": int(inverter.get("quantity") or 0) or None,
        "inverter_capacity_kw": float(as_int(inverter.get("capacity")) or 0) or None,
        "structure_count": int(structure.get("quantity") or 0) or None,
        "structure_height": (structure.get("size") or "")[:60] or None,
        "ac_wire_brand": (item("ac_wire").get("make") or "")[:60] or None,
        "ac_wire_size": (item("ac_wire").get("size") or "")[:60] or None,
        "dc_wire_brand": (item("dc_wire").get("make") or "")[:60] or None,
        "dc_wire_size": (item("dc_wire").get("size") or "")[:60] or None,
        "earthing_wire_brand": (item("earthing_wire").get("make") or "")[:60] or None,
        "earthing_wire_size": (item("earthing_wire").get("size") or "")[:60] or None,
        "solar_meter_brand": (item("solar_meter").get("make") or "")[:60] or None,
        "solar_meter_count": min(int(item("solar_meter").get("quantity") or 0), 20) or None,
        "civil_work": " ".join(filter(None, [item("civil_work").get("size"), item("civil_work").get("other")]))[:2000] or None,
    }
    updates = {
        "approved_quotation_id": q["_id"],
        "quotation_approved_at": q["decided_at"],
        "capacity_kw": float(q["capacity_kw"]),
        "kw": float(q["capacity_kw"]),
        "sanctioned_load_kw": float(q.get("load_kw") or 0),
        "final_price": total_paise,
        "total_amount": total_paise,
        "panel_brand": module.get("make") or cust.get("panel_brand"),
        "panel_watt": as_int(module.get("capacity")) or cust.get("panel_watt") or 0,
        "panel_count": int(module.get("quantity") or 0) or cust.get("panel_count") or 0,
        "inverter_brand": inverter.get("make") or cust.get("inverter_brand"),
        "structure_type": structure.get("technology") or structure.get("make") or cust.get("structure_type"),
        "bom": ProjectBom(**{k: v for k, v in bom_raw.items() if v is not None}).cleaned(),
        "updated_at": _now(),
    }
    return updates


# ── Staff (salesman / admin) ────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a quotation and send it to the customer or lead")
async def create_quotation(payload: QuotationIn, current_user: MongoUserProxy = Depends(require_quote_staff)):
    target_type, target = _resolve_quote_target(current_user, payload.customer_id, write=True)
    cid = str(target["_id"])
    lead_id = cid if target_type == "lead" else target.get("lead_id")
    if target.get("approved_quotation_id"):
        raise BadRequestException("This customer has already approved a quotation; it can no longer be changed.")
    if payload.revision_of:
        prev = _col().find_one({
            "_id": payload.revision_of,
            "$or": [{"customer_id": cid}, *([{"lead_id": str(lead_id)}] if lead_id else [])],
        })
        if not prev:
            raise NotFoundException("Quotation not found.")
    col = _col()
    now = _now()
    # Anything still awaiting the client is replaced by this version.
    match_target = {"$or": [{"customer_id": cid}, *([{"lead_id": str(lead_id)}] if lead_id else [])]}
    col.update_many({**match_target, "status": "sent"},
                    {"$set": {"status": "superseded", "superseded_at": now}})
    version = col.count_documents(match_target) + 1
    total = round(payload.project_cost + payload.discom_charges + payload.file_charges, 2)
    qid = str(uuid.uuid4())
    doc = {
        "_id": qid,
        "id": qid,
        "quote_no": f"QT-{cid[:4].upper()}-{version:02d}",
        "version": version,
        "customer_id": cid,
        "lead_id": str(lead_id) if lead_id else None,
        "target_type": target_type,
        "customer_name": target.get("name", ""),
        "customer_phone": target.get("phone") or target.get("mobile") or "",
        "customer_email": target.get("email") or "",
        "customer_address": target.get("address") or target.get("area") or "",
        "status": "sent",
        "capacity_kw": payload.capacity_kw,
        "load_kw": payload.load_kw,
        "project_cost": round(payload.project_cost, 2),
        "discom_charges": round(payload.discom_charges, 2),
        "file_charges": round(payload.file_charges, 2),
        "total_amount": total,
        "items": {k: v.model_dump() for k, v in payload.items.items()},
        "other_items": [o.model_dump() for o in payload.other_items],
        "remark": payload.remark,
        "revision_of": payload.revision_of,
        "created_by_id": current_user.id,
        "created_by_name": current_user.name,
        "created_by_role": access.role_of(current_user),
        "sent_at": now,
        "created_at": now,
        "client_remark": None,
        "decided_at": None,
    }
    col.insert_one(doc)
    _notify("New quotation for your solar project",
            f"{current_user.name} sent you quotation {doc['quote_no']} for a {payload.capacity_kw:g} kW system. "
            f"Please review and approve or reject it.",
            user_id=_client_user_id(target), target=qid)
    logger.info("quotation_sent", quotation_id=qid, customer_id=cid, target_type=target_type, by=current_user.id, version=version)
    return _out(doc)


@router.get("", summary="Quotations visible to the caller (filter by customer/lead or status)")
async def list_quotations(
    customer_id: Optional[str] = Query(None, max_length=64),
    status_filter: Optional[str] = Query(None, alias="status", max_length=20),
    current_user: MongoUserProxy = Depends(require_quote_staff),
):
    query: dict = {}
    if customer_id:
        _, target = _resolve_quote_target(current_user, customer_id, write=False)
        tid = str(target["_id"])
        target_ids = [tid]
        if target.get("lead_id"):
            target_ids.append(str(target["lead_id"]))
        if target.get("customer_id"):
            target_ids.append(str(target["customer_id"]))
        query["$or"] = [{"customer_id": {"$in": target_ids}}, {"lead_id": {"$in": target_ids}}]
    elif not access.is_admin(current_user):
        db = get_mongo_db()
        c_ids = [str(c["_id"]) for c in db["customers"].find(access.sales_customer_query(current_user), {"_id": 1})]
        l_ids = [
            str(l["_id"])
            for l in db["leads"].find(
                {"$or": [{"assigned_sales_id": current_user.id}, {"assigned_sales_id": None}, {"assigned_sales_id": ""}]},
                {"_id": 1},
            )
        ]
        all_ids = c_ids + l_ids
        query["$or"] = [{"customer_id": {"$in": all_ids}}, {"lead_id": {"$in": all_ids}}]
    if status_filter and status_filter != "all":
        query["status"] = status_filter
    return [_out(d) for d in _col().find(query).sort("created_at", -1).limit(200)]


# ── Client ──────────────────────────────────────────────────────────────────

def _client_target_ids(user: MongoUserProxy) -> List[str]:
    """Return all customer and lead IDs owned by the signed-in client."""
    cust = access.client_customer(user)
    lead = access.client_lead(user)
    ids: List[str] = []
    if cust:
        ids.append(str(cust["_id"]))
        if cust.get("lead_id"):
            ids.append(str(cust["lead_id"]))
    if lead:
        ids.append(str(lead["_id"]))
        if lead.get("customer_id"):
            ids.append(str(lead["customer_id"]))
    return list(dict.fromkeys(i for i in ids if i))


@router.get("/mine", summary="Quotations sent to the signed-in client")
async def my_quotations(current_user: MongoUserProxy = Depends(require_client)):
    target_ids = _client_target_ids(current_user)
    if not target_ids:
        return []
    cursor = _col().find({
        "$or": [{"customer_id": {"$in": target_ids}}, {"lead_id": {"$in": target_ids}}],
        "status": {"$ne": "superseded"},
    }).sort("created_at", -1)
    return [_out(d) for d in cursor]


def _client_quote(user: MongoUserProxy, quotation_id: str) -> dict:
    target_ids = _client_target_ids(user)
    if not target_ids:
        raise NotFoundException("No solar project or lead is linked to your account yet.")
    doc = _col().find_one({
        "_id": str(quotation_id),
        "$or": [{"customer_id": {"$in": target_ids}}, {"lead_id": {"$in": target_ids}}],
    })
    if not doc:
        raise NotFoundException("Quotation not found.")
    return doc


@router.post("/{quotation_id}/approve", summary="Approve a quotation (client). Final: it can never be changed.")
async def approve_quotation(quotation_id: str, current_user: MongoUserProxy = Depends(require_client)):
    q = _client_quote(current_user, quotation_id)
    if q.get("status") != "sent":
        raise BadRequestException(f"This quotation is already {q.get('status')}.")
    db = get_mongo_db()
    cid = str(q["customer_id"])
    now = _now()

    cust = db["customers"].find_one({"_id": cid})
    target_col = "customers" if cust is not None else "leads"
    target_doc = cust if cust is not None else db["leads"].find_one({"_id": cid})
    if not target_doc:
        raise NotFoundException("Project or lead not found.")

    # Claim the target (customer or lead) first so two quotations can never both be approved.
    claim = db[target_col].update_one(
        {"_id": cid, "$or": [{"approved_quotation_id": None}, {"approved_quotation_id": {"$exists": False}}]},
        {"$set": {"approved_quotation_id": q["_id"], "updated_at": now}},
    )
    if claim.modified_count != 1:
        raise BadRequestException("A quotation for this project has already been approved.")
    approved = _col().find_one_and_update(
        {"_id": q["_id"], "status": "sent"},
        {"$set": {"status": "approved", "decided_at": now, "decided_by_id": current_user.id,
                  "decided_by_name": current_user.name}},
        return_document=ReturnDocument.AFTER,
    )
    if not approved:
        db[target_col].update_one({"_id": cid, "approved_quotation_id": q["_id"]},
                                  {"$set": {"approved_quotation_id": None}})
        raise BadRequestException("This quotation was replaced by a newer version. Please review the latest one.")

    target_doc = db[target_col].find_one({"_id": cid}) or target_doc
    applied = _apply_to_customer(target_doc, approved)
    if target_col == "leads":
        applied["expected_kw"] = float(approved["capacity_kw"])
    db[target_col].update_one({"_id": cid}, {"$set": applied})

    match_clauses = [{"customer_id": cid}]
    if q.get("lead_id"):
        match_clauses.append({"lead_id": str(q["lead_id"])})
    _col().update_many({"$or": match_clauses, "status": "sent"},
                       {"$set": {"status": "superseded", "superseded_at": now}})

    if target_col == "customers":
        if target_doc.get("lead_id"):
            db["leads"].update_one(
                {"_id": str(target_doc["lead_id"])},
                {"$set": {"approved_quotation_id": q["_id"], "quotation_approved_at": now, "updated_at": now}},
            )
        from app.services import workflow
        workflow.on_quotation_approved(cid)

    msg = f"{target_doc.get('name', 'The customer')} approved quotation {approved['quote_no']}."
    _notify("Quotation approved", msg, user_id=approved.get("created_by_id"), target=q["_id"])
    _notify("Quotation approved", msg, role="admin", target=q["_id"])
    logger.info("quotation_approved", quotation_id=q["_id"], target_id=cid, target_type=target_col)
    return _out(approved)


@router.post("/{quotation_id}/reject", summary="Reject a quotation with a remark (client)")
async def reject_quotation(quotation_id: str, payload: RejectIn, current_user: MongoUserProxy = Depends(require_client)):
    q = _client_quote(current_user, quotation_id)
    remark = payload.remark.strip()
    if len(remark) < 3:
        raise BadRequestException("Please tell us why you are rejecting this quotation.")
    rejected = _col().find_one_and_update(
        {"_id": q["_id"], "status": "sent"},
        {"$set": {"status": "rejected", "client_remark": remark, "decided_at": _now(),
                  "decided_by_id": current_user.id, "decided_by_name": current_user.name}},
        return_document=ReturnDocument.AFTER,
    )
    if not rejected:
        raise BadRequestException(f"This quotation is already {q.get('status')}.")
    msg = f"{q.get('customer_name') or 'The customer'} rejected quotation {q['quote_no']}: \"{remark[:140]}\""
    _notify("Quotation rejected", msg, user_id=q.get("created_by_id"), target=q["_id"])
    _notify("Quotation rejected", msg, role="admin", target=q["_id"])
    return _out(rejected)


# Registered last so /mine is not captured as a quotation id.
@router.get("/{quotation_id}", summary="One quotation (staff who can see the customer)")
async def get_quotation(quotation_id: str, current_user: MongoUserProxy = Depends(require_quote_staff)):
    return _out(_staff_quote(current_user, quotation_id))
