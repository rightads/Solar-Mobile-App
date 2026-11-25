from datetime import datetime, timezone, timedelta
import uuid
import re
from typing import Any, Dict, List, Optional
import structlog
from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection
from pymongo.database import Database
from app.core.config import settings
from app.core.constants import FIRST_STAGE
from app.core.security import hash_password, normalize_phone, sanitize_input, verify_password

logger = structlog.get_logger()

_client: Optional[MongoClient] = None
_db: Optional[Database] = None


def get_mongo_client() -> Optional[MongoClient]:
    global _client
    if _client is None and settings.MONGODB_URI:
        try:
            _client = MongoClient(
                settings.MONGODB_URI,
                tz_aware=True,
                serverSelectionTimeoutMS=5000,
                connectTimeoutMS=5000,
                socketTimeoutMS=20000,
                retryWrites=True,
            )
        except Exception as e:
            logger.error("Failed to initialize MongoDB client", error=str(e))
    return _client


def get_mongo_db() -> Optional[Database]:
    global _db
    if _db is None:
        client = get_mongo_client()
        if client:
            try:
                _db = client[settings.MONGODB_DB_NAME]
            except Exception as e:
                logger.error("Failed to access MongoDB database", error=str(e))
    return _db



def init_mongo() -> bool:
    """Create indexes and seed the Super Admin from the environment (first run only)."""
    db = get_mongo_db()
    if db is None:
        logger.warning("MongoDB not connected. Skipping MongoDB initialization.")
        return False

    try:
        db.command("ping")
        users_col: Collection = db["users"]

        # Uniqueness (also defends against duplicate-registration races)
        users_col.create_index([("phone", ASCENDING)], unique=True)
        users_col.create_index([("email", ASCENDING)], unique=True, sparse=True)
        users_col.create_index([("approval_status", ASCENDING)])
        db["leads"].create_index([("phone", ASCENDING)])
        db["customers"].create_index([("phone", ASCENDING)])
        db["customers"].create_index([("user_id", ASCENDING)], sparse=True)
        db["files"].create_index([("customer_id", ASCENDING)])

        # Auth artefacts expire automatically
        db["otp_codes"].create_index([("phone", ASCENDING), ("created_at", ASCENDING)])
        db["otp_codes"].create_index("expires_at", expireAfterSeconds=3600)
        db["email_verifications"].create_index([("email", ASCENDING), ("created_at", ASCENDING)])
        db["email_verifications"].create_index("expires_at", expireAfterSeconds=3600)
        db["refresh_tokens"].create_index([("user_id", ASCENDING)])
        db["refresh_tokens"].create_index([("family_id", ASCENDING)])
        db["refresh_tokens"].create_index("expires_at", expireAfterSeconds=0)
        db["rate_limits"].create_index("expires_at", expireAfterSeconds=0)

        _seed_super_admin(users_col)
        return True
    except Exception as e:
        logger.error("MongoDB initialization error", error=str(e))
        return False


def _seed_super_admin(users_col: Collection) -> None:
    """Create the Super Admin once. Existing accounts and passwords are never modified."""
    if users_col.find_one({"is_superadmin": True}):
        return
    email, phone, pwd = settings.SUPER_ADMIN_EMAIL, settings.SUPER_ADMIN_PHONE, settings.SUPER_ADMIN_PASSWORD
    if not (email and phone and pwd):
        logger.warning("SUPER_ADMIN_EMAIL / SUPER_ADMIN_PHONE / SUPER_ADMIN_PASSWORD not set; skipping Super Admin creation")
        return
    try:
        from app.core.security import normalize_email, validate_password_strength
        email = normalize_email(email)
        phone = normalize_phone(phone)
        validate_password_strength(pwd)
    except ValueError as e:
        logger.error("Invalid Super Admin configuration; not created", error=str(e))
        return
    if users_col.find_one({"$or": [{"email": email}, {"phone": phone}]}):
        logger.error("Super Admin email/phone already belongs to another account; not created")
        return
    now = datetime.now(timezone.utc)
    admin_id = str(uuid.uuid4())
    users_col.insert_one({
        "_id": admin_id,
        "id": admin_id,
        "name": settings.SUPER_ADMIN_NAME or "Super Admin",
        "email": email,
        "phone": phone,
        "role": "admin",
        "is_superadmin": True,
        "is_active": True,
        "approval_status": "approved",
        "is_email_verified": True,
        "is_phone_verified": False,
        "token_version": 0,
        "password_hash": hash_password(pwd),
        "created_at": now,
        "updated_at": now,
        "last_login_at": None,
    })
    logger.info("Super Admin account created")


def mongo_create_user(
    name: str,
    phone: str,
    password: str,
    role: str = "client",
    email: Optional[str] = None,
    is_email_verified: Optional[bool] = None,
) -> Dict[str, Any]:
    """Insert a new user (used by admin seed scripts). Never overwrites an existing account."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    from app.core.security import normalize_email, validate_password_strength
    users_col = db["users"]
    now = datetime.now(timezone.utc)
    phone_normalized = normalize_phone(phone)
    clean_email = normalize_email(email) if email else None
    validate_password_strength(password)

    conds: List[Dict[str, Any]] = [{"phone": phone_normalized}]
    if clean_email:
        conds.append({"email": clean_email})
    if users_col.find_one({"$or": conds}):
        raise ValueError("An account with this mobile number or email already exists.")

    is_client = role.lower() == "client"
    user_id = str(uuid.uuid4())
    doc = {
        "_id": user_id,
        "id": user_id,
        "name": sanitize_input(name),
        "phone": phone_normalized,
        "email": clean_email,
        "role": role.lower(),
        "requested_role": role.lower(),
        "password_hash": hash_password(password),
        "is_active": is_client,
        "approval_status": "approved" if is_client else "pending",
        "is_email_verified": bool(is_email_verified),
        "is_phone_verified": False,
        "token_version": 0,
        "created_at": now,
        "updated_at": now,
        "last_login_at": None,
    }
    users_col.insert_one(doc)
    return doc


def mongo_get_registration_approvals(status: str = "pending") -> List[Dict[str, Any]]:
    """Fetch employee/admin registration requests for Super Admin review."""
    db = get_mongo_db()
    if db is None:
        return []
    users_col = db["users"]
    query: Dict[str, Any] = {"role": {"$ne": "client"}, "is_superadmin": {"$ne": True}}
    if status and status.lower() != "all":
        status_clean = status.lower()
        query["$or"] = [
            {"approval_status": status_clean},
            {"approval_status": status_clean.upper()},
            {"approval_status": status_clean.capitalize()},
        ]
        if status_clean == "pending":
            query["$or"].extend([
                {"approval_status": {"$exists": False}, "is_active": False},
                {"approval_status": None, "is_active": False},
            ])

    cursor = users_col.find(query).sort("created_at", -1)
    results = []
    for doc in cursor:
        results.append({
            "id": str(doc["_id"]),
            "name": doc.get("name", ""),
            "phone": doc.get("phone", ""),
            "email": doc.get("email"),
            "role": doc.get("role", "employee"),
            "requested_role": doc.get("requested_role") or doc.get("role", "employee"),
            "approval_status": doc.get("approval_status", "pending"),
            "is_active": doc.get("is_active", False),
            "created_at": doc.get("created_at").isoformat() if doc.get("created_at") else None,
            "approved_at": doc.get("approved_at").isoformat() if doc.get("approved_at") else None,
        })
    return results


def mongo_approve_user(user_id: str) -> Optional[Dict[str, Any]]:
    """Approve a pending employee/admin registration and activate their account."""
    from pymongo import ReturnDocument
    from bson import ObjectId
    db = get_mongo_db()
    if db is None:
        return None
    users_col = db["users"]
    now = datetime.now(timezone.utc)

    id_conds = [{"_id": user_id}, {"id": user_id}]
    if ObjectId.is_valid(user_id):
        id_conds.append({"_id": ObjectId(user_id)})
    user = users_col.find_one({"$or": id_conds})
    if not user:
        return None

    role = str(user.get("role", "employee")).lower()
    employee_no = user.get("employee_no")
    if not employee_no and role != "client":
        from app.core.access import EMPLOYEE_NO_PREFIX, normalize_department
        prefix = EMPLOYEE_NO_PREFIX.get(normalize_department(role) or "", "EMP-STF")
        employee_no = f"{prefix}-{str(user['_id'])[:4].upper()}"

    update_fields = {
        "approval_status": "approved",
        "is_active": True,
        "approved_at": now,
        "updated_at": now,
    }
    if employee_no:
        update_fields["employee_no"] = employee_no

    res = users_col.find_one_and_update(
        {"_id": user["_id"]},
        {"$set": update_fields},
        return_document=ReturnDocument.AFTER,
    )
    if res:
        res["id"] = str(res["_id"])
        res.pop("password_hash", None)
    return res


def mongo_reject_user(user_id: str) -> Optional[Dict[str, Any]]:
    """Reject a pending employee/admin registration and disable account."""
    from pymongo import ReturnDocument
    from bson import ObjectId
    db = get_mongo_db()
    if db is None:
        return None
    users_col = db["users"]
    now = datetime.now(timezone.utc)

    id_conds = [{"_id": user_id}, {"id": user_id}]
    if ObjectId.is_valid(user_id):
        id_conds.append({"_id": ObjectId(user_id)})
    user = users_col.find_one({"$or": id_conds})
    if not user:
        return None

    res = users_col.find_one_and_update(
        {"_id": user["_id"]},
        {"$set": {"approval_status": "rejected", "is_active": False, "rejected_at": now, "updated_at": now},
         "$inc": {"token_version": 1}},
        return_document=ReturnDocument.AFTER,
    )
    if res:
        res["id"] = str(res["_id"])
        res.pop("password_hash", None)
    return res


def mongo_create_lead(lead_data: Dict[str, Any]) -> Dict[str, Any]:
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    from app.core.access import find_verified_client_for_contact
    leads_col = db["leads"]
    now = datetime.now(timezone.utc)
    lead_id = str(uuid.uuid4())
    raw_phone = sanitize_input(lead_data.get("phone", ""))
    try:
        clean_phone = normalize_phone(raw_phone)
    except Exception:
        clean_phone = raw_phone
    raw_email = sanitize_input(lead_data.get("email") or "")
    clean_email = raw_email.strip().lower() if raw_email else None
    matched_client = find_verified_client_for_contact(phone=clean_phone, email=clean_email)
    linked_uid = str(matched_client["_id"]) if matched_client else lead_data.get("user_id")
    if not clean_email and matched_client and matched_client.get("email"):
        clean_email = str(matched_client["email"]).strip().lower()
    kw_val = float(lead_data.get("kw") if lead_data.get("kw") is not None else (lead_data.get("expected_kw") or 3.0))
    doc = {
        "_id": lead_id,
        "id": lead_id,
        "user_id": linked_uid,
        "name": sanitize_input(lead_data.get("name", "")),
        "phone": clean_phone,
        "email": clean_email,
        "area": sanitize_input(lead_data.get("area") or lead_data.get("address") or ""),
        "address": sanitize_input(lead_data.get("address") or lead_data.get("area") or ""),
        "kw": kw_val,
        "expected_kw": kw_val,
        "status": lead_data.get("status", "new"),
        "source": lead_data.get("source", "Direct"),
        "created_at": now,
        "updated_at": now,
    }
    leads_col.insert_one(doc)
    return doc


_SENSITIVE_FIELDS = (
    "password_hash", "hashed_password", "otp_hash", "code_hash",
    "token_version", "fcm_token", "phone_verified_at",
)


def _format_mongo_doc(doc: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not doc:
        return doc
    res = dict(doc)
    doc_id = str(res.get("id") or res.get("_id"))
    res["id"] = doc_id
    res["_id"] = str(res["_id"])
    # Security: never leak credential material in API responses
    for field in _SENSITIVE_FIELDS:
        res.pop(field, None)
    for k, v in list(res.items()):
        if isinstance(v, datetime):
            res[k] = v.isoformat()
    return res


def mongo_get_leads(status: Optional[str] = None, search: Optional[str] = None, assigned_sales_id: Optional[str] = None) -> List[Dict[str, Any]]:
    db = get_mongo_db()
    if db is None:
        return []
    leads_col = db["leads"]
    query: Dict[str, Any] = {}
    if status and status.lower() != "all":
        query["status"] = status.lower()
    if assigned_sales_id:
        query["$or"] = [
            {"assigned_sales_id": assigned_sales_id},
            {"sales_id": assigned_sales_id},
            {"assigned_sales_id": None},
        ]
    if search:
        s = re.escape(sanitize_input(search))
        query["$or"] = [
            {"name": {"$regex": s, "$options": "i"}},
            {"phone": {"$regex": s, "$options": "i"}},
            {"area": {"$regex": s, "$options": "i"}},
            {"address": {"$regex": s, "$options": "i"}},
        ]
    cursor = leads_col.find(query).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_create_customer(customer_data: Dict[str, Any]) -> Dict[str, Any]:
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    from app.core.access import find_verified_client_for_contact
    customers_col = db["customers"]
    now = datetime.now(timezone.utc)
    cust_id = str(customer_data.get("id") or uuid.uuid4())
    final_price_val = int(customer_data.get("final_price") or customer_data.get("total_amount") or 0)
    raw_phone = sanitize_input(customer_data.get("phone", customer_data.get("mobile", "")))
    try:
        clean_phone = normalize_phone(raw_phone) if raw_phone else ""
    except Exception:
        clean_phone = raw_phone
    raw_email = sanitize_input(customer_data.get("email", ""))
    clean_email = raw_email.strip().lower() if raw_email else ""
    linked_uid = customer_data.get("user_id")
    if not linked_uid:
        matched_client = find_verified_client_for_contact(phone=clean_phone, email=clean_email)
        if matched_client:
            linked_uid = str(matched_client["_id"])
            if not clean_email and matched_client.get("email"):
                clean_email = str(matched_client["email"]).strip().lower()
    doc = {
        "_id": cust_id,
        "id": cust_id,
        "user_id": linked_uid,
        "name": sanitize_input(customer_data.get("name", "")),
        "phone": clean_phone,
        "mobile": clean_phone,
        "email": clean_email,
        "address": sanitize_input(customer_data.get("address", "")),
        "location_gps": customer_data.get("location_gps") or customer_data.get("gps") or (
            f"{customer_data['latitude']:.6f},{customer_data['longitude']:.6f}"
            if customer_data.get("latitude") is not None and customer_data.get("longitude") is not None else ""),
        "latitude": customer_data.get("latitude"),
        "longitude": customer_data.get("longitude"),
        "bom": customer_data.get("bom") or {},
        "lead_id": customer_data.get("lead_id"),
        "approved_quotation_id": customer_data.get("approved_quotation_id"),
        "quotation_approved_at": customer_data.get("quotation_approved_at"),
        "kw": float(customer_data.get("kw") or customer_data.get("capacity_kw") or 0),
        "capacity_kw": float(customer_data.get("capacity_kw") or customer_data.get("kw") or 0),
        "final_price": final_price_val,
        "total_amount": final_price_val,
        "paid_amount": int(customer_data.get("paid_amount", 0)),
        "phase": customer_data.get("phase", "single"),
        "panel_brand": sanitize_input(customer_data.get("panel_brand") or ""),
        "panel_watt": int(customer_data.get("panel_watt") or 0),
        "panel_count": int(customer_data.get("panel_count") or 0),
        "inverter_brand": sanitize_input(customer_data.get("inverter_brand") or ""),
        "structure_type": sanitize_input(customer_data.get("structure_type") or ""),
        "stage": FIRST_STAGE,
        "workflow_version": 2,
        "sales_id": customer_data.get("sales_id"),
        "sales_name": customer_data.get("sales_name"),
        "status": customer_data.get("status", "active"),
        "documents": customer_data.get("documents") or {
            "e_bill": None,
            "aadhaar": None,
            "pan": None,
            "cancelled_cheque": None,
            "registry": None,
        },
        "documents_count": int(customer_data.get("documents_count", 0)),
        "milestones": customer_data.get("milestones") or [],
        "payment_summary": customer_data.get("payment_summary"),
        "created_at": customer_data.get("created_at") or now,
        "updated_at": customer_data.get("updated_at") or now,
    }
    customers_col.insert_one(doc)
    merge_self_registered_projects(doc)
    return _format_mongo_doc(doc)


# Auto-created site tasks nobody has worked on (safe to discard with a placeholder).
_UNTOUCHED_WORK = {
    "status": {"$in": ["assigned", "pending"]},
    "started_at": None,
    "$or": [{"photos": {"$exists": False}}, {"photos": None}, {"photos": {"$size": 0}}],
}


def is_self_registered_project(cust: Dict[str, Any]) -> bool:
    """A placeholder a client created by signing up (``client._ensure_project``)
    that no sales owner has taken on yet. Staff-created projects always carry a
    ``sales_id`` (direct create) or a ``lead_id`` (lead conversion)."""
    if not cust or cust.get("sales_id") or cust.get("lead_id"):
        return False
    if cust.get("self_registered"):
        return True
    # Older placeholders carry no flag: recognise the sign-up shape (linked to
    # a client, never quoted or sized, no stage ever completed).
    stage_done = any((v or {}).get("done") for v in (cust.get("stage_status") or {}).values())
    return bool(
        cust.get("user_id")
        and float(cust.get("capacity_kw") or 0) == 0
        and int(cust.get("final_price") or 0) == 0
        and not stage_done
    )


def merge_self_registered_projects(project: Dict[str, Any]) -> int:
    """Fold a client's sign-up placeholder into the staff-created ``project``
    with the same phone or email, so the client follows the real project.

    Without this the client stays linked to the empty placeholder and never
    sees anything staff do. The client account is linked to the real project
    only if it has proven the phone number by OTP or email by verification code
    (same rule as ``access.client_customer``); otherwise it is unlinked and the
    client is asked to verify. The placeholder is archived to ``customers_merged``
    and removed. Idempotent.
    """
    db = get_mongo_db()
    if db is None or is_self_registered_project(project):
        return 0
    phone = str(project.get("phone") or project.get("mobile") or "").strip()
    email = str(project.get("email") or "").strip().lower()
    uid_proj = str(project.get("user_id") or "").strip()
    pid = str(project["_id"])
    match_clauses = []
    if phone:
        match_clauses.extend([{"phone": phone}, {"mobile": phone}])
    if email:
        match_clauses.append({"email": email})
    if uid_proj:
        match_clauses.append({"user_id": uid_proj})
    if not match_clauses:
        return 0
    merged = 0
    for ph in db["customers"].find({"_id": {"$ne": project["_id"]}, "$or": match_clauses}):
        if not is_self_registered_project(ph):
            continue
        old_id = str(ph["_id"])
        uid = ph.get("user_id")
        user = db["users"].find_one({"$or": [{"_id": str(uid)}, {"id": str(uid)}]}) if uid else None
        phone_ok = bool(phone and user and str(user.get("phone") or "") == phone)
        email_ok = bool(email and user and str(user.get("email") or "").lower() == email)
        verified = bool(phone_ok or email_ok or (uid_proj and str(uid) == uid_proj))
        now = datetime.now(timezone.utc)
        if verified and not project.get("user_id"):
            db["customers"].update_one({"_id": project["_id"]}, {"$set": {"user_id": str(uid), "updated_at": now}})
            project["user_id"] = str(uid)
            # The client's own submissions follow them to the real project.
            for col in ("payments", "tickets"):
                db[col].update_many({"customer_id": old_id}, {"$set": {
                    "customer_id": pid, "customer_name": project.get("name"), "updated_at": now}})
        # Site tasks auto-created for the placeholder were never worked on.
        db["work_assignments"].delete_many({"customer_id": old_id, **_UNTOUCHED_WORK})
        db["customers_merged"].insert_one({**ph, "merged_into": pid, "merged_at": now,
                                           "client_linked": verified})
        db["customers"].delete_one({"_id": ph["_id"]})
        merged += 1
        logger.info("self_registered_project_merged", placeholder=old_id, project=pid, client_linked=verified)
    if merged:
        recalc = sum(int(p.get("amount", 0)) for p in db["payments"].find({"customer_id": pid, "status": "verified"}))
        db["customers"].update_one({"_id": project["_id"]}, {"$set": {"paid_amount": recalc}})
    return merged


def backfill_customer_lead_ids() -> int:
    """Converted customers created before ``lead_id`` was stored get it back
    from their lead (``leads.customer_id``). Idempotent."""
    db = get_mongo_db()
    if db is None:
        return 0
    fixed = 0
    for lead in db["leads"].find({"customer_id": {"$nin": [None, ""]}}, {"customer_id": 1}):
        res = db["customers"].update_one(
            {"_id": str(lead["customer_id"]), "$or": [{"lead_id": {"$exists": False}}, {"lead_id": None}]},
            {"$set": {"lead_id": str(lead["_id"])}},
        )
        fixed += res.modified_count
    return fixed


def repair_self_registered_projects() -> Dict[str, int]:
    """Startup repair for sign-up placeholders created before the merge existed.

    * A placeholder whose phone now has a staff-created project is merged into it.
    * A lone placeholder is reset to "awaiting survey": the legacy workflow
      migration had handed it to Site-ops and created unassigned site tasks
      that showed up in every site employee's queue.
    """
    db = get_mongo_db()
    if db is None:
        return {"merged": 0, "reset": 0}
    merged = reset = 0
    placeholders = [c for c in db["customers"].find({"$or": [{"sales_id": None}, {"sales_id": ""}, {"sales_id": {"$exists": False}}]})
                    if is_self_registered_project(c)]
    for ph in placeholders:
        phone = str(ph.get("phone") or ph.get("mobile") or "")
        real = None
        if phone:
            real = next((c for c in db["customers"].find({"_id": {"$ne": ph["_id"]}, "$or": [{"phone": phone}, {"mobile": phone}]})
                         if not is_self_registered_project(c)), None)
        if real:
            merged += merge_self_registered_projects(real)
            continue
        if ph.get("self_registered") and not ph.get("assigned_role"):
            continue  # already clean
        cid = str(ph["_id"])
        db["work_assignments"].delete_many({"customer_id": cid, **_UNTOUCHED_WORK})
        db["customers"].update_one({"_id": ph["_id"]}, {
            "$set": {"self_registered": True, "workflow_version": 2, "stage": "REGISTRATION_SUBMITTED"},
            "$unset": {"assigned_role": "", "assigned_to": ""},
        })
        reset += 1
    return {"merged": merged, "reset": reset}



def mongo_get_customers(stage: Optional[str] = None, search: Optional[str] = None, sales_id: Optional[str] = None) -> List[Dict[str, Any]]:
    db = get_mongo_db()
    if db is None:
        return []
    customers_col = db["customers"]
    query: Dict[str, Any] = {}
    if stage and stage.lower() != "all":
        query["stage"] = stage.upper()
    if sales_id:
        query["$or"] = [
            {"sales_id": sales_id},
            {"sales_id": None},
        ]
    if search:
        s = re.escape(sanitize_input(search))
        query["$or"] = [
            {"name": {"$regex": s, "$options": "i"}},
            {"phone": {"$regex": s, "$options": "i"}},
            {"mobile": {"$regex": s, "$options": "i"}},
            {"address": {"$regex": s, "$options": "i"}},
        ]
    cursor = customers_col.find(query).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_get_pending_payments(sales_id: Optional[str] = None) -> List[Dict[str, Any]]:
    db = get_mongo_db()
    if db is None:
        return []
    payments_col = db["payments"]
    query: Dict[str, Any] = {"status": {"$in": ["pending", "sales_approved"]}}
    cursor = payments_col.find(query).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_get_customer_payments(customer_id: str) -> Dict[str, Any]:
    db = get_mongo_db()
    if db is None:
        return {"items": [], "summary": {"total_paid": 0, "verified": 0, "pending": 0, "balance": 0}}
    payments_col = db["payments"]
    cursor = payments_col.find({"customer_id": str(customer_id)}).sort("created_at", -1)
    items = [_format_mongo_doc(doc) for doc in cursor]

    verified = sum(int(p.get("amount", 0)) for p in items if p.get("status") == "verified")
    pending = sum(int(p.get("amount", 0)) for p in items if p.get("status") in ["pending", "sales_approved"])
    total_paid = verified + pending

    cust = db["customers"].find_one({"$or": [{"_id": str(customer_id)}, {"id": str(customer_id)}]})
    final_price = int(cust.get("final_price", 0)) if cust else 0
    balance = max(0, final_price - verified)

    return {
        "items": items,
        "summary": {
            "final_price": final_price,
            "total_paid": total_paid,
            "verified": verified,
            "pending": pending,
            "balance": balance,
            "percent_collected": round((verified / final_price * 100), 1) if final_price > 0 else 0.0,
        }
    }


def mongo_sales_approve_payment(
    payment_id: str,
    approver_email: str = "",
    approver_name: Optional[str] = None,
    approver_emp_no: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    payments_col = db["payments"]
    now = datetime.now(timezone.utc)

    if not approver_name and approver_email:
        u = db["users"].find_one({"$or": [{"email": approver_email.lower()}, {"phone": approver_email}]})
        if u:
            approver_name = u.get("name")
            approver_emp_no = u.get("employee_no")

    res = payments_col.find_one_and_update(
        {"$or": [{"_id": str(payment_id)}, {"id": str(payment_id)}]},
        {"$set": {
            "status": "sales_approved",
            "sales_approved_by": approver_email,
            "sales_approved_by_name": approver_name or "Sales Staff",
            "sales_approver_emp_no": approver_emp_no or "",
            "sales_approved_at": now,
            "updated_at": now,
        }},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


def mongo_get_customer_by_id(customer_id: str) -> Optional[Dict[str, Any]]:
    """Retrieve customer by UUID or string id from MongoDB."""
    db = get_mongo_db()
    if db is None:
        return None
    cid = str(customer_id)
    doc = db["customers"].find_one({"$or": [{"_id": cid}, {"id": cid}]})
    return _format_mongo_doc(doc)


def mongo_update_customer(customer_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Update customer details in MongoDB."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    cid = str(customer_id)
    clean_updates = {k: v for k, v in updates.items() if k not in ["_id", "id"]}
    clean_updates["updated_at"] = datetime.now(timezone.utc)
    res = db["customers"].find_one_and_update(
        {"$or": [{"_id": cid}, {"id": cid}]},
        {"$set": clean_updates},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


def mongo_update_customer_milestone(customer_id: str, milestone_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Verify or update a payment milestone for customer."""
    db = get_mongo_db()
    if db is None:
        return None
    cid = str(customer_id)
    cust = db["customers"].find_one({"$or": [{"_id": cid}, {"id": cid}]})
    if not cust:
        return None
    milestones = cust.get("milestones", [])
    found = False
    now = datetime.now(timezone.utc)
    for m in milestones:
        if str(m.get("id")) == str(milestone_id) or str(m.get("title")) == str(milestone_id):
            m.update(updates)
            m["updated_at"] = now.isoformat()
            found = True
            break
    if not found and updates.get("title"):
        milestones.append({
            "id": str(milestone_id or uuid.uuid4()),
            "title": updates.get("title", f"Milestone {len(milestones)+1}"),
            "amount": int(updates.get("amount", 0)),
            "status": updates.get("status", "pending"),
            "due_date": updates.get("due_date"),
            "verified_by": updates.get("verified_by"),
            "verified_at": now.isoformat() if updates.get("status") == "verified" else None,
        })
    # Recalculate verified paid amount
    paid_sum = sum(int(m.get("amount", 0)) for m in milestones if m.get("status") == "verified")
    db["customers"].update_one(
        {"_id": cust["_id"]},
        {"$set": {"milestones": milestones, "paid_amount": paid_sum, "updated_at": now}}
    )
    return mongo_get_customer_by_id(cid)


# ── Page 1: Sales Person Assign & Lead Management ──────────────────────────

def mongo_assign_lead(lead_id: str, sales_id: str, sales_name: str) -> Optional[Dict[str, Any]]:
    """Assign lead to a sales person."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    now = datetime.now(timezone.utc)
    res = db["leads"].find_one_and_update(
        {"$or": [{"_id": str(lead_id)}, {"id": str(lead_id)}]},
        {"$set": {
            "assigned_sales_id": str(sales_id),
            "assigned_sales_name": sanitize_input(sales_name),
            "status": "contacted",
            "updated_at": now,
        }},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


def mongo_convert_lead(lead_id: str, customer_data: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
    """Convert lead to confirmed closed sale and optionally create customer."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    now = datetime.now(timezone.utc)
    lead = db["leads"].find_one_and_update(
        {"$or": [{"_id": str(lead_id)}, {"id": str(lead_id)}]},
        {"$set": {"status": "converted", "closed_at": now, "updated_at": now}},
        return_document=ReturnDocument.AFTER,
    )
    if not lead:
        return None
    if customer_data:
        lid_str = str(lead["_id"])
        cust_payload = {
            "name": customer_data.get("name") or lead.get("name"),
            "phone": customer_data.get("phone") or lead.get("phone"),
            "email": customer_data.get("email") or lead.get("email") or "",
            "user_id": lead.get("user_id"),
            "address": customer_data.get("address") or lead.get("address") or lead.get("area"),
            "kw": float(customer_data.get("kw") or customer_data.get("capacity_kw") or lead.get("capacity_kw") or lead.get("kw", 5.0)),
            "sales_id": lead.get("assigned_sales_id"),
            "sales_name": lead.get("assigned_sales_name"),
            "lead_id": lid_str,
            "approved_quotation_id": lead.get("approved_quotation_id"),
            "quotation_approved_at": lead.get("quotation_approved_at"),
            **customer_data,
        }
        cust = mongo_create_customer(cust_payload)
        db["leads"].update_one({"_id": lead["_id"]}, {"$set": {"customer_id": cust["id"]}})
        db["quotations"].update_many(
            {"$or": [{"customer_id": lid_str}, {"lead_id": lid_str}]},
            {"$set": {"customer_id": cust["id"], "lead_id": lid_str, "target_type": "customer"}},
        )
        return cust
    return _format_mongo_doc(lead)


def mongo_get_salespersons() -> List[Dict[str, Any]]:
    """List staff with sales role for assignment dropdown."""
    db = get_mongo_db()
    if db is None:
        return []
    cursor = db["users"].find(
        {"role": {"$in": ["sales", "employee", "admin"]}, "is_active": True}
    ).sort("name", 1)
    results = []
    for doc in cursor:
        results.append({
            "id": str(doc["_id"]),
            "name": doc.get("name", "Staff"),
            "phone": doc.get("phone", ""),
            "role": doc.get("role", "sales"),
        })
    return results


# ── Page 1 & 2: Employees Add Like Labour & Labour Teams ─────────────────────

_INVALID_DEPARTMENT = ("Invalid employee role. Choose Salesman, Discom, Structure, Wiring, "
                       "Civil Work, Subsidy or Account / Bill.")


def mongo_create_admin(data: Dict[str, Any], created_by: str) -> Dict[str, Any]:
    """Create an administrator account (Super Admin only; checked by the caller)."""
    from app.core.security import normalize_email, validate_password_strength
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    name = " ".join(str(data.get("name") or "").split())[:100]
    if len(name) < 2:
        raise ValueError("Admin name is required.")
    phone = normalize_phone(data.get("phone", ""))
    email = normalize_email(data.get("email") or "")
    password = str(data.get("password") or "")
    validate_password_strength(password)
    if db["users"].find_one({"$or": [{"phone": phone}, {"email": email}]}):
        raise ValueError("An account with this mobile number or email already exists.")
    now = datetime.now(timezone.utc)
    uid = str(uuid.uuid4())
    doc = {
        "_id": uid, "id": uid, "name": name, "phone": phone, "email": email,
        "role": "admin", "is_superadmin": False, "is_active": True, "approval_status": "approved",
        "employee_no": f"ADM-{uid[:6].upper()}",
        # The Super Admin vouches for the email, so password resets reach it.
        "is_email_verified": True, "is_phone_verified": False, "token_version": 0,
        "password_hash": hash_password(password), "created_by": created_by,
        "created_at": now, "updated_at": now, "last_login_at": None,
    }
    db["users"].insert_one(doc)
    doc.pop("password_hash")
    return _format_mongo_doc(doc)


def mongo_create_employee(employee_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new staff account (admin only). Never modifies an existing account."""
    from app.core.access import ASSIGNABLE_STAFF_ROLES, EMPLOYEE_NO_PREFIX, normalize_department
    from app.core.security import normalize_email, validate_password_strength
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    users_col = db["users"]
    now = datetime.now(timezone.utc)

    raw_role = str(employee_data.get("role") or "").strip().lower()
    if raw_role in ("admin", "main_admin", "co_admin", "super_admin", "vendor", "manager", "client"):
        raise ValueError(_INVALID_DEPARTMENT)
    role = normalize_department(raw_role) or normalize_department(employee_data.get("trade"))
    if role not in ASSIGNABLE_STAFF_ROLES:
        raise ValueError(_INVALID_DEPARTMENT)
    name = " ".join(str(employee_data.get("name") or "").split())[:100]
    if len(name) < 2:
        raise ValueError("Employee name is required.")
    phone = normalize_phone(employee_data.get("phone", ""))
    email = normalize_email(employee_data["email"]) if employee_data.get("email") else None
    trade = role
    team = sanitize_input(str(employee_data.get("team") or ""))[:60]

    conds: List[Dict[str, Any]] = [{"phone": phone}]
    if email:
        conds.append({"email": email})
    if users_col.find_one({"$or": conds}):
        raise ValueError("An account with this mobile number or email already exists.")

    emp_id = str(uuid.uuid4())
    prefix = EMPLOYEE_NO_PREFIX[role]
    doc = {
        "_id": emp_id,
        "id": emp_id,
        "name": name,
        "phone": phone,
        "email": email,
        "role": role,
        "trade": trade,
        "team": team,
        "employee_no": f"{prefix}-{emp_id[:6].upper()}",
        "is_active": True,
        "approval_status": "approved",
        "is_email_verified": False,
        "is_phone_verified": False,
        "token_version": 0,
        "created_at": now,
        "updated_at": now,
        "last_login_at": None,
    }
    raw_password = employee_data.get("password")
    if raw_password:
        validate_password_strength(str(raw_password))
        doc["password_hash"] = hash_password(str(raw_password))
    if not email:
        doc.pop("email")
    users_col.insert_one(doc)
    return _format_mongo_doc(doc)


def mongo_get_employees(trade: Optional[str] = None, team: Optional[str] = None, status: Optional[str] = None) -> List[Dict[str, Any]]:
    """Staff directory with active task counts.

    ``trade`` filters by department (see access.DEPARTMENTS); legacy labels such
    as "kedl" or "electrician" are mapped onto their department.
    Only approved, active staff are listed unless ``status`` is specified.
    """
    from app.core.access import MANAGER_ROLES, STAFF_ROLES, department_of, normalize_department
    db = get_mongo_db()
    if db is None:
        return []
    query: Dict[str, Any] = {
        "role": {"$in": sorted(STAFF_ROLES - MANAGER_ROLES)},
        "deleted_at": None,
    }
    if status and status.lower() == "pending":
        query["$or"] = [
            {"approval_status": "pending"},
            {"approval_status": "PENDING"},
            {"approval_status": "Pending"},
            {"is_active": False, "approval_status": {"$ne": "rejected"}},
        ]
    elif status and status.lower() == "rejected":
        query["approval_status"] = {"$in": ["rejected", "REJECTED"]}
    elif status and status.lower() != "all":
        query["approval_status"] = status.lower()
    else:
        # Default: only approved, non-pending, non-rejected, active staff
        query["approval_status"] = {"$nin": ["pending", "rejected", "PENDING", "REJECTED"]}
        query["is_active"] = {"$ne": False}

    wanted_department = normalize_department(trade) if trade and trade.lower() != "all" else None
    if trade and trade.lower() != "all" and wanted_department is None:
        return []
    if team and team.lower() != "all":
        query["team"] = team
    cursor = db["users"].find(query).sort("created_at", -1)
    results = []
    for doc in cursor:
        department = department_of(doc)
        if wanted_department and department != wanted_department:
            continue
        f_doc = _format_mongo_doc(doc)
        f_doc["department"] = department
        emp_id = str(f_doc.get("id") or f_doc.get("_id") or "")
        emp_name = f_doc.get("name", "")
        emp_no = f_doc.get("employee_no", "")
        w_count = db["work_assignments"].count_documents({
            "$or": [
                {"assigned_employee_id": emp_id},
                {"assigned_to": emp_id},
                {"assigned_employee_name": emp_name},
                {"assigned_staff": emp_name},
                {"assigned_employee_no": emp_no},
            ],
            "status": {"$nin": ["completed", "cancelled"]}
        })
        t_count = db["tickets"].count_documents({
            "$or": [
                {"assigned_to": emp_id},
                {"assigned_staff": emp_name},
                {"assigned_staff_emp_no": emp_no},
            ],
            "status": {"$nin": ["resolved", "closed"]}
        })
        l_count = db["leads"].count_documents({
            "$or": [
                {"assigned_sales_id": emp_id},
                {"sales_id": emp_id},
            ],
            "status": {"$nin": ["converted", "lost"]}
        }) if "sales" in f_doc.get("role", "").lower() else 0
        f_doc["task_count"] = w_count + t_count + l_count
        results.append(f_doc)
    return results


def mongo_get_employee_tasks(employee_id: str) -> List[Dict[str, Any]]:
    """Retrieve all assigned tasks (work assignments, tickets, leads) for a specific employee."""
    db = get_mongo_db()
    if db is None:
        return []
    emp_query = {"$or": [{"_id": str(employee_id)}, {"id": str(employee_id)}, {"employee_no": str(employee_id)}]}
    emp = db["users"].find_one(emp_query)
    emp_name = emp.get("name", "") if emp else ""
    emp_no = emp.get("employee_no", "") if emp else ""
    eid = str(emp.get("id") or emp.get("_id") or employee_id) if emp else str(employee_id)

    tasks = []

    # 1. Work Assignments
    # Match by id only: names are not unique and blank employee numbers would
    # match every unnumbered task.
    id_values = list({eid, str(employee_id)})
    w_cursor = db["work_assignments"].find({
        "duplicate_of": {"$exists": False},
        "$or": [
            {"assigned_employee_id": {"$in": id_values}},
            {"assigned_to": {"$in": id_values}},
        ]
    }).sort("created_at", -1)
    for w in w_cursor:
        fw = _format_mongo_doc(w)
        tasks.append({
            "id": fw.get("id") or fw.get("_id"),
            "title": fw.get("title") or f"{fw.get('work_type', 'Installation').capitalize()} Assignment",
            "description": fw.get("description") or fw.get("notes") or "",
            "customer_name": fw.get("customer_name") or "Customer",
            "location": fw.get("location") or "",
            "category": fw.get("work_type", "general"),
            "status": fw.get("status", "assigned"),
            "priority": fw.get("priority", "normal"),
            "start_date": fw.get("start_date") or "",
            "end_date": fw.get("end_date") or "",
            "assigned_to": fw.get("assigned_employee_name") or emp_name,
            "type": "work_assignment",
            "created_at": fw.get("created_at"),
        })

    # 2. Service Tickets
    t_cursor = db["tickets"].find({"assigned_to": {"$in": id_values}}).sort("created_at", -1)
    for t in t_cursor:
        ft = _format_mongo_doc(t)
        tasks.append({
            "id": ft.get("id") or ft.get("_id"),
            "title": ft.get("title") or f"Ticket #{ft.get('ticket_no', '')}",
            "description": ft.get("description") or "",
            "customer_name": ft.get("customer_name") or "Client",
            "location": ft.get("customer_address") or "",
            "category": "service",
            "status": ft.get("status", "assigned"),
            "priority": ft.get("priority", "normal"),
            "start_date": str(ft.get("created_at", ""))[:10],
            "end_date": str(ft.get("updated_at", ""))[:10],
            "assigned_to": emp_name,
            "type": "ticket",
            "created_at": ft.get("created_at"),
        })

    # 3. Sales Leads (if sales employee)
    if emp and "sales" in emp.get("role", "").lower():
        l_cursor = db["leads"].find({
            "$or": [
                {"assigned_sales_id": eid},
                {"sales_id": eid},
            ]
        }).sort("created_at", -1)
        for l in l_cursor:
            fl = _format_mongo_doc(l)
            tasks.append({
                "id": fl.get("id") or fl.get("_id"),
                "title": f"Lead: {fl.get('name', 'Prospect')} ({fl.get('system_size_kw', 5)} kW)",
                "description": f"Phone: {fl.get('phone', '')} • Status: {fl.get('status', 'new')}",
                "customer_name": fl.get("name") or "Lead",
                "location": fl.get("city") or fl.get("address") or "",
                "category": "sales",
                "status": "in_progress" if fl.get("status") in ["contacted", "qualified"] else fl.get("status", "assigned"),
                "priority": "high" if fl.get("status") == "site_survey_scheduled" else "normal",
                "start_date": str(fl.get("created_at", ""))[:10],
                "end_date": "",
                "assigned_to": emp_name,
                "type": "lead",
                "created_at": fl.get("created_at"),
            })

    tasks.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
    return tasks


def mongo_assign_task_to_employee(employee_id: str, task_data: dict) -> dict:
    """Create and assign a task directly to an employee in MongoDB."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")

    emp_query = {"$or": [{"_id": str(employee_id)}, {"id": str(employee_id)}, {"employee_no": str(employee_id)}]}
    emp = db["users"].find_one(emp_query)
    emp_name = emp.get("name", "Employee") if emp else sanitize_input(task_data.get("assigned_employee_name", "Employee"))
    emp_no = emp.get("employee_no", "") if emp else ""
    eid = str(emp.get("id") or emp.get("_id") or employee_id) if emp else str(employee_id)
    emp_team = emp.get("team", "Operations") if emp else "Operations"

    assignment_id = str(task_data.get("id") or uuid.uuid4())
    now = datetime.now(timezone.utc)
    work_type = str(task_data.get("work_type") or task_data.get("category") or "general").lower()

    # A project has one task per site trade: hand the existing one to this
    # employee instead of creating a duplicate card.
    from app.services.workflow import LIVE_WORK, SITE_SEQUENCE
    cust_id = str(task_data.get("customer_id") or "")
    if cust_id and work_type in SITE_SEQUENCE:
        existing = db["work_assignments"].find_one(
            {"customer_id": cust_id, "work_type": work_type, **LIVE_WORK}, sort=[("created_at", 1)])
        if existing:
            updates: Dict[str, Any] = {
                "assigned_employee_id": eid, "assigned_employee_name": emp_name, "assigned_employee_no": emp_no,
                "assigned_to": eid, "assigned_staff": emp_name, "updated_at": now,
            }
            for key in ("start_date", "end_date"):
                if task_data.get(key):
                    updates[key] = task_data[key]
            if task_data.get("notes"):
                updates["notes"] = sanitize_input(task_data["notes"])
            db["work_assignments"].update_one({"_id": existing["_id"]}, {"$set": updates})
            return _format_mongo_doc(db["work_assignments"].find_one({"_id": existing["_id"]}))

    doc = {
        "_id": assignment_id,
        "id": assignment_id,
        "title": sanitize_input(task_data.get("title", f"{work_type.capitalize()} Task")),
        "description": sanitize_input(task_data.get("description", task_data.get("notes", ""))),
        "customer_id": str(task_data.get("customer_id", "")),
        "customer_name": sanitize_input(task_data.get("customer_name", "Direct Assignment")),
        "location": sanitize_input(task_data.get("location", "")),
        "work_type": work_type,
        "category": work_type,
        "team": sanitize_input(task_data.get("team", emp_team)),
        "team_id": str(task_data.get("team_id", "")),
        "assigned_employee_id": eid,
        "assigned_employee_name": emp_name,
        "assigned_employee_no": emp_no,
        "assigned_to": eid,
        "assigned_staff": emp_name,
        "priority": str(task_data.get("priority", "normal")).lower(),
        "start_date": task_data.get("start_date", now.strftime("%Y-%m-%d")),
        "end_date": task_data.get("end_date", now.strftime("%Y-%m-%d")),
        "status": task_data.get("status", "assigned"),
        "notes": sanitize_input(task_data.get("notes", "")),
        "created_at": now,
        "updated_at": now,
    }

    db["work_assignments"].insert_one(doc)
    return _format_mongo_doc(doc)


def mongo_create_team(team_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new labour team (e.g. Structure Team A, Electrical Team B, etc.)."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    teams_col = db["teams"]
    now = datetime.now(timezone.utc)
    team_id = str(team_data.get("id") or uuid.uuid4())
    doc = {
        "_id": team_id,
        "id": team_id,
        "name": sanitize_input(team_data.get("name", "Team A")),
        "trade_type": team_data.get("trade_type", "structure").lower(),  # structure, electrical, civil
        "lead_name": sanitize_input(team_data.get("lead_name", "")),
        "lead_phone": normalize_phone(team_data["lead_phone"]) if team_data.get("lead_phone") else "",
        "member_count": int(team_data.get("member_count", 3)),
        "is_active": True,
        "created_at": now,
        "updated_at": now,
    }
    teams_col.update_one({"name": doc["name"], "trade_type": doc["trade_type"]}, {"$set": doc}, upsert=True)
    return _format_mongo_doc(doc)


def mongo_get_teams(trade_type: Optional[str] = None) -> List[Dict[str, Any]]:
    """List available teams for Structure, Electrical, Civil labor."""
    db = get_mongo_db()
    if db is None:
        return []
    teams_col = db["teams"]
    query: Dict[str, Any] = {"is_active": True}
    if trade_type and trade_type.lower() != "all":
        query["trade_type"] = trade_type.lower()
    cursor = teams_col.find(query).sort("name", 1)
    items = [_format_mongo_doc(doc) for doc in cursor]
    return items


# ── Page 2: Work Assignment to Structure, Electrical & Civil Labour ─────────

def mongo_create_work_assignment(data: Dict[str, Any]) -> Dict[str, Any]:
    """Assign installation work to structure, electrical or civil labor team."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    assignments_col = db["work_assignments"]
    now = datetime.now(timezone.utc)
    assignment_id = str(data.get("id") or uuid.uuid4())
    doc = {
        "_id": assignment_id,
        "id": assignment_id,
        "customer_id": str(data.get("customer_id", "")),
        "customer_name": sanitize_input(data.get("customer_name", "Customer")),
        "location": sanitize_input(data.get("location", "")),
        "work_type": data.get("work_type", "structure").lower(),  # structure, electrical, civil
        "team_name": sanitize_input(data.get("team_name", "Team A")),
        "lead_name": sanitize_input(data.get("lead_name", "")),
        "lead_phone": sanitize_input(data.get("lead_phone", "")),
        "start_date": data.get("start_date") or now.strftime("%Y-%m-%d"),
        "end_date": data.get("end_date") or now.strftime("%Y-%m-%d"),
        "status": data.get("status", "assigned"),  # assigned, in_progress, completed
        "notes": sanitize_input(data.get("notes", "")),
        "created_at": now,
        "updated_at": now,
    }
    assignments_col.insert_one(doc)
    return _format_mongo_doc(doc)


def mongo_get_work_assignments(
    customer_id: Optional[str] = None,
    work_type: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """List work assignments with optional filtering by customer or trade."""
    db = get_mongo_db()
    if db is None:
        return []
    assignments_col = db["work_assignments"]
    query: Dict[str, Any] = {}
    if customer_id:
        query["customer_id"] = str(customer_id)
    if work_type and work_type.lower() != "all":
        query["work_type"] = work_type.lower()
    cursor = assignments_col.find(query).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_update_work_assignment(assignment_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Update work assignment status or dates and sync completed work to client milestones."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    aid = str(assignment_id)
    clean = {k: v for k, v in updates.items() if k not in ["_id", "id"]}
    now = datetime.now(timezone.utc)
    clean["updated_at"] = now
    res = db["work_assignments"].find_one_and_update(
        {"$or": [{"_id": aid}, {"id": aid}]},
        {"$set": clean},
        return_document=ReturnDocument.AFTER,
    )
    if res and clean.get("status") == "completed":
        cust_id = str(res.get("customer_id", ""))
        work_type = str(res.get("work_type", "")).lower()
        stage_map = {
            "structure": "STRUCTURE_WORK",
            "electrical": "ELECTRICAL_WORK",
            "civil": "CIVIL_WORK",
            "installation": "INSTALLATION_COMPLETE",
        }
        target_stage = stage_map.get(work_type)
        if target_stage and cust_id:
            mongo_update_customer_milestone(
                cust_id,
                target_stage,
                {
                    "stage": target_stage,
                    "status": "done",
                    "completed_by": res.get("assigned_employee_name") or res.get("assigned_staff"),
                    "completed_by_emp_no": res.get("assigned_employee_no") or res.get("assigned_staff_emp_no"),
                    "completed_at": now.isoformat(),
                }
            )
    return _format_mongo_doc(res) if res else None


# ── Page 3: KEDL Work Employee (Name Change, Load, Net Meter Files) ─────────

def mongo_create_or_update_kedl_file(data: Dict[str, Any]) -> Dict[str, Any]:
    """Create or update KEDL liaison file with demand notice tracking."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    kedl_col = db["kedl_files"]
    now = datetime.now(timezone.utc)
    file_id = str(data.get("id") or uuid.uuid4())
    customer_id = str(data.get("customer_id", ""))
    file_type = data.get("file_type", "net").lower()  # name_change, load, net
    doc = {
        "_id": file_id,
        "id": file_id,
        "customer_id": customer_id,
        "customer_name": sanitize_input(data.get("customer_name", "")),
        "location": sanitize_input(data.get("location", "")),
        "file_type": file_type,
        "status": data.get("status", "not_started"),  # not_started, submitted, demand_raised, demand_paid, approved
        "demand_amount": int(data.get("demand_amount", 0)),
        "demand_notice_ref": sanitize_input(data.get("demand_notice_ref", "")),
        "demand_paid_date": data.get("demand_paid_date"),
        "meter_no": sanitize_input(data.get("meter_no", "")),
        "sanctioned_kw": float(data.get("sanctioned_kw", 5.0)),
        "assigned_employee_name": sanitize_input(data.get("assigned_employee_name", "KEDL Liaison")),
        "notes": sanitize_input(data.get("notes", "")),
        "updated_at": now,
    }
    # Update or insert by customer_id + file_type
    if customer_id and file_type:
        kedl_col.update_one(
            {"customer_id": customer_id, "file_type": file_type},
            {"$set": doc, "$setOnInsert": {"created_at": now}},
            upsert=True,
        )
        found = kedl_col.find_one({"customer_id": customer_id, "file_type": file_type})
        return _format_mongo_doc(found)
    else:
        doc["created_at"] = now
        kedl_col.insert_one(doc)
        return _format_mongo_doc(doc)


def mongo_get_kedl_files(
    customer_id: Optional[str] = None,
    file_type: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Fetch KEDL tracking files with demand notice state."""
    db = get_mongo_db()
    if db is None:
        return []
    kedl_col = db["kedl_files"]
    query: Dict[str, Any] = {}
    if customer_id:
        query["customer_id"] = str(customer_id)
    if file_type and file_type.lower() != "all":
        query["file_type"] = file_type.lower()
    cursor = kedl_col.find(query).sort("updated_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_update_kedl_demand(
    file_id: str,
    demand_amount: int,
    status: str = "demand_raised",
    demand_ref: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Update demand notice amount and status for a KEDL file."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    now = datetime.now(timezone.utc)
    fid = str(file_id)
    updates = {
        "demand_amount": int(demand_amount),
        "status": status,
        "updated_at": now,
    }
    if demand_ref:
        updates["demand_notice_ref"] = sanitize_input(demand_ref)
    if status == "demand_paid":
        updates["demand_paid_date"] = now.strftime("%Y-%m-%d")
    res = db["kedl_files"].find_one_and_update(
        {"$or": [{"_id": fid}, {"id": fid}]},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


# ── Client Mobile Experience (Home & Payments) ───────────────────────────────

def access_department_field(department: str) -> Optional[str]:
    from app.core.access import DEPARTMENT_FIELD
    return DEPARTMENT_FIELD.get(department)


def mongo_get_client_home(
    user: Dict[str, Any],
    customer: Optional[Dict[str, Any]],
    lead: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Aggregate dashboard data for a client.

    ``customer`` must already be resolved through ``access.client_customer`` and
    ``lead`` through ``access.client_lead`` (matching by user id, verified phone,
    or verified email). While the client is linked to an unconverted lead, their
    lead details and assigned salesman are shown until Sales converts the lead.
    """
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")

    user_name = user.get("name") or "Solar Client"
    user_phone = user.get("phone") or ""

    now = datetime.now(timezone.utc)
    is_lead_only = customer is None and lead is not None
    if not customer and lead:
        customer = {
            "_id": "",
            "id": str(lead.get("_id") or lead.get("id") or ""),
            "name": lead.get("name") or user_name,
            "phone": lead.get("phone") or user_phone,
            "mobile": lead.get("phone") or user_phone,
            "email": lead.get("email") or user.get("email") or "",
            "address": lead.get("address") or lead.get("area") or "",
            "capacity_kw": float(lead.get("capacity_kw") or lead.get("kw") or lead.get("expected_kw") or 0.0),
            "final_price": int(lead.get("final_price") or 0),
            "phase": lead.get("phase") or "single",
            "panel_brand": lead.get("panel_brand") or "",
            "panel_watt": int(lead.get("panel_watt") or 0),
            "panel_count": int(lead.get("panel_count") or 0),
            "inverter_brand": lead.get("inverter_brand") or "",
            "structure_type": lead.get("structure_type") or "",
            "stage": "REGISTRATION_SUBMITTED",
            "assigned_to": None,
            "sales_id": lead.get("assigned_sales_id") or lead.get("sales_id"),
            "sales_name": lead.get("assigned_sales_name") or lead.get("sales_name"),
            "approved_quotation_id": lead.get("approved_quotation_id"),
            "milestones": [],
            "created_at": lead.get("created_at") or now,
            "updated_at": lead.get("updated_at") or now,
        }
    elif not customer:
        customer = {
            "_id": "",
            "id": "",
            "name": user_name,
            "phone": user_phone,
            "mobile": user_phone,
            "email": user.get("email") or "",
            "address": "",
            "capacity_kw": 0.0,
            "final_price": 0,
            "phase": "single",
            "panel_brand": "",
            "panel_watt": 0,
            "panel_count": 0,
            "inverter_brand": "",
            "structure_type": "",
            "stage": "REGISTRATION_SUBMITTED",
            "assigned_to": None,
            "sales_id": None,
            "milestones": [],
            "created_at": now,
            "updated_at": now,
        }

    # Assigned Sales Rep only if explicitly linked to customer or lead
    sales_rep = None
    sales_id = customer.get("sales_id") or customer.get("assigned_sales_id")
    if sales_id:
        sales_rep = db["users"].find_one({"$or": [{"id": str(sales_id)}, {"_id": str(sales_id)}]})
    elif customer.get("sales_name"):
        sales_rep = db["users"].find_one({"name": customer["sales_name"]})
    if not sales_rep and (sales_id or customer.get("sales_name")):
        sales_rep = {
            "_id": str(sales_id or ""),
            "name": customer.get("sales_name") or "Sales Representative",
            "phone": "",
            "email": "",
            "employee_no": f"EMP-SLS-{str(sales_id)[:4].upper()}" if sales_id else "EMP-SLS",
        }

    from app.services import workflow

    def _user(uid: Any) -> Optional[Dict[str, Any]]:
        return db["users"].find_one({"$or": [{"_id": str(uid)}, {"id": str(uid)}]}) if uid else None

    cid = str(customer.get("_id") or customer.get("id") or "")
    # A project the client created themselves stays "awaiting survey" until a
    # sales owner takes it on; it must not look like installation has started.
    awaiting_survey = not cid or is_self_registered_project(customer)
    cust_stage = "REGISTRATION_SUBMITTED" if awaiting_survey else customer.get("stage", "REGISTRATION_SUBMITTED")

    # Site work: one live row per trade (structure → electrical → civil).
    site_rows = list(db["work_assignments"].find({"customer_id": cid, **workflow.LIVE_WORK})) if cid else []
    work_by_type = workflow.site_work_by_type(sorted(site_rows, key=lambda w: str(w.get("created_at") or "")))

    # Timeline: the same stage_status source of truth the employee portal uses.
    timeline = workflow.build_timeline(customer)["stages"]
    if awaiting_survey:
        for item in timeline:
            item.update({"status": "upcoming", "done": False, "date": None, "by": None})

    # Installation breakdown so the client sees each trade finish, not only
    # the whole installation.
    task_label = {"completed": "done", "in_progress": "in_progress", "active": "in_progress"}
    # Site trade progress (structure / wiring / civil) shown on its own stage.
    for item in timeline:
        wt = workflow.STAGE_WORK_TYPE.get(item["stage"])
        w = work_by_type.get(wt) if wt else None
        if w and item["status"] == "current" and not awaiting_survey:
            item["work_status"] = task_label.get(str(w.get("status") or ""), "pending")

    completed_count = sum(1 for item in timeline if item["status"] == "done")
    total_stages = len(timeline)
    progress_pct = int((completed_count / total_stages) * 100) if total_stages > 0 else 0

    # Responsible contact: whoever owns the project right now (see workflow.advance).
    officer, officer_title = None, None
    role = str(customer.get("assigned_role") or "")
    field = access_department_field(role)
    if field and not awaiting_survey and role != "sales":
        from app.core.access import DEPARTMENT_LABELS
        officer_title = f"{DEPARTMENT_LABELS.get(role, role.title())} Officer"
        officer = _user(customer.get(field) or customer.get("assigned_to"))
        if not officer:
            wt = workflow.STAGE_WORK_TYPE.get(str(customer.get("stage") or ""))
            active = work_by_type.get(wt) if wt else None
            if active and active.get("assigned_to"):
                officer = _user(active["assigned_to"]) or {
                    "name": active.get("assigned_employee_name") or active.get("assigned_staff") or "Site Lead",
                    "phone": "", "employee_no": active.get("assigned_employee_no") or "", "email": "",
                }
    if not officer and customer.get("assigned_officer_id"):
        officer, officer_title = _user(customer["assigned_officer_id"]), "Project Officer"

    # Financials
    final_price_paise = int(customer.get("final_price", 0))
    payments_info = mongo_get_customer_payments(cid) if cid else {"summary": {"verified": 0, "total_paid": 0}}
    verified_paise = payments_info["summary"]["verified"]
    total_paid_paise = payments_info["summary"]["total_paid"]
    remaining_paise = max(0, final_price_paise - verified_paise)

    resp_contact = None
    if officer:
        resp_contact = {
            "name": officer.get("name", "Project Lead"),
            "phone": officer.get("phone", ""),
            "role_title": officer_title,
            "employee_no": officer.get("employee_no", ""),
            "email": officer.get("email", ""),
        }
    elif sales_rep:
        emp_no = sales_rep.get("employee_no") or (
            f"EMP-SLS-{str(sales_rep.get('_id') or sales_rep.get('id') or '')[:4].upper()}"
            if (sales_rep.get("_id") or sales_rep.get("id")) else "EMP-SLS"
        )
        resp_contact = {
            "name": sales_rep.get("name", "Sales Representative"),
            "phone": sales_rep.get("phone", ""),
            "role_title": "Assigned Sales Representative",
            "employee_no": emp_no,
            "email": sales_rep.get("email", ""),
        }

    # Sales Contact (null if no salesman assigned)
    sales_contact = None
    if sales_rep:
        emp_no = sales_rep.get("employee_no") or (
            f"EMP-SLS-{str(sales_rep.get('_id') or sales_rep.get('id') or '')[:4].upper()}"
            if (sales_rep.get("_id") or sales_rep.get("id")) else "EMP-SLS"
        )
        sales_contact = {
            "name": sales_rep.get("name", "Sales Representative"),
            "phone": sales_rep.get("phone", ""),
            "role_title": "Sales Executive",
            "employee_no": emp_no,
            "email": sales_rep.get("email", ""),
        }

    has_specs = bool(
        float(customer.get("capacity_kw", 0)) > 0 and
        customer.get("panel_brand") and
        customer.get("panel_brand") != "Pending Survey"
    )

    return {
        "customer": {
            "id": str(customer.get("_id") or customer.get("id") or ""),
            "name": customer.get("name", user_name),
            "mobile": customer.get("phone", user_phone),
            "address": customer.get("address", ""),
            "capacity_kw": float(customer.get("capacity_kw", 0.0)),
            "final_price": final_price_paise,
            "stage": cust_stage,
        },
        "lead": _format_mongo_doc(lead) if lead else None,
        "is_lead_linked": is_lead_only,
        "stage": cust_stage,
        "timeline": timeline,
        "progress": {
            "completed_stages": completed_count,
            "total_stages": total_stages,
            "percentage": progress_pct,
            "current_stage_index": (completed_count + 1) if completed_count < total_stages else total_stages,
        },
        "responsible_contact": resp_contact,
        "sales_contact": sales_contact,
        "payment_summary": {
            "final_price": final_price_paise,
            "total_amount": final_price_paise / 100.0,
            "total_paid": total_paid_paise / 100.0,
            "remaining_balance": remaining_paise / 100.0,
            "next_milestone": "Awaiting Project Quote" if final_price_paise == 0 else "Milestone Payment",
        },
        "system_specs": {
            "capacity_kw": float(customer.get("capacity_kw", 0.0)),
            "phase": customer.get("phase", "Single Phase"),
            "panel_brand": customer.get("panel_brand") or "Pending Survey",
            "panel_watt": int(customer.get("panel_watt", 0)),
            "panel_count": int(customer.get("panel_count", 0)),
            "inverter_brand": customer.get("inverter_brand") or "Pending Survey",
            "structure_type": customer.get("structure_type") or "Pending Survey",
            "is_configured": has_specs,
        },
    }


def mongo_get_client_payments(customer_id: str) -> List[Dict[str, Any]]:
    """Payments for one (already authorised) customer."""
    db = get_mongo_db()
    if db is None or not customer_id:
        return []
    cursor = db["payments"].find({"customer_id": str(customer_id)}).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_record_client_payment(
    customer: Dict[str, Any],
    submitted_by: str,
    amount_paise: int,
    mode: str,
    reference_no: Optional[str] = None,
    paid_on: Optional[datetime] = None,
    remarks: Optional[str] = None,
    proof: Optional[Dict[str, Any]] = None,
    submitted_by_role: str = "client",
) -> Dict[str, Any]:
    """Record a payment submission for an authorised customer (status: pending)."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    payments_col = db["payments"]
    now = datetime.now(timezone.utc)
    cust_id = str(customer["_id"])
    count = payments_col.count_documents({"customer_id": cust_id})

    pay_id = f"pay-{uuid.uuid4().hex[:16]}"
    doc = {
        "_id": pay_id,
        "id": pay_id,
        "customer_id": cust_id,
        "customer_name": customer.get("name"),
        "client_phone": customer.get("phone"),
        "submitted_by": str(submitted_by),
        "submitted_by_role": submitted_by_role,
        "stage_no": count + 1,
        "stage_name": "Rooftop Solar Milestone Payment",
        "amount": int(amount_paise),
        "amount_paise": int(amount_paise),
        "amount_rupees": float(amount_paise) / 100.0,
        "mode": str(mode).upper(),
        "reference_no": sanitize_input(reference_no) or None,
        "paid_on": paid_on or now,
        "proof": proof,
        "proof_url": proof["url"] if proof else None,
        "status": "pending",
        "sales_approved_by": None,
        "sales_approved_by_name": None,
        "sales_approver_emp_no": None,
        "remarks": sanitize_input(remarks) or None,
        "created_at": now,
        "updated_at": now,
    }
    payments_col.insert_one(doc)
    return _format_mongo_doc(doc)


# ── KEDL Dashboard & Details ─────────────────────────────────────────────────

def mongo_get_kedl_file_by_id(file_id: str) -> Optional[Dict[str, Any]]:
    """Retrieve single KEDL file by id."""
    db = get_mongo_db()
    if db is None:
        return None
    fid = str(file_id)
    doc = db["kedl_files"].find_one({"$or": [{"_id": fid}, {"id": fid}]})
    return _format_mongo_doc(doc) if doc else None


def _parse_dt(value: Any) -> Optional[datetime]:
    """Parse a stored date (datetime or ISO string, with or without time) as UTC."""
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def mongo_get_kedl_dashboard() -> Dict[str, Any]:
    """Calculate aggregate KEDL tracking counts and metrics."""
    db = get_mongo_db()
    if db is None:
        return {
            "total_files": 0,
            "open_demands": 0,
            "total_demand_paise": 0,
            "completed_files": 0,
            "pending_files": 0,
        }
    kedl_col = db["kedl_files"]
    total = kedl_col.count_documents({})
    demands_raised = kedl_col.count_documents({"status": "demand_raised"})
    demands_paid = kedl_col.count_documents({"status": "demand_paid"})
    approved = kedl_col.count_documents({"status": "approved"})

    # Breakdown the app's KEDL desk reads (by type/status, open + overdue demands).
    by_file_type: Dict[str, int] = {}
    by_status: Dict[str, int] = {}
    open_demands_count = 0
    overdue_demands_count = 0
    open_demand_paise = 0
    now = datetime.now(timezone.utc)
    for doc in kedl_col.find({}, {"file_type": 1, "status": 1, "demands": 1}):
        ftype = str(doc.get("file_type") or "unknown")
        fstatus = str(doc.get("status") or "not_started")
        by_file_type[ftype] = by_file_type.get(ftype, 0) + 1
        by_status[fstatus] = by_status.get(fstatus, 0) + 1
        for demand in doc.get("demands") or []:
            if str(demand.get("status", "open")) != "open":
                continue
            open_demands_count += 1
            open_demand_paise += int(demand.get("amount_paise") or demand.get("amount") or 0)
            due = _parse_dt(demand.get("due_date"))
            if due is not None and due < now:
                overdue_demands_count += 1

    return {
        "total_files": total,
        "open_demands": demands_raised,
        "total_demand_paise": open_demand_paise,  # demand amounts are stored in paise
        "completed_files": approved,
        "pending_files": max(0, total - approved),
        "demands_paid_count": demands_paid,
        "by_file_type": by_file_type,
        "by_status": by_status,
        "open_demands_count": open_demands_count,
        "overdue_demands_count": overdue_demands_count,
    }


# ── Calendar & Work Assignments ──────────────────────────────────────────────

def mongo_get_calendar_schedule(start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict[str, Any]]:
    """Retrieve work assignments organized by date for calendar tab."""
    db = get_mongo_db()
    if db is None:
        return []
    cursor = db["work_assignments"].find({}).sort("start_date", 1)
    return [_format_mongo_doc(doc) for doc in cursor]


# ── Service Tickets ──────────────────────────────────────────────────────────

def mongo_get_tickets(
    customer_id: Optional[str] = None,
    status: Optional[str] = None,
    ticket_type: Optional[str] = None,
    assigned_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Query service tickets with filtering."""
    db = get_mongo_db()
    if db is None:
        return []
    clauses: List[Dict[str, Any]] = []
    if customer_id:
        clauses.append({"customer_id": str(customer_id)})
    if status and status.lower() != "all":
        clauses.append({"status": status.lower()})
    if ticket_type and ticket_type.lower() != "all":
        clauses.append({"type": ticket_type.lower()})
    if assigned_to:
        clauses.append({"$or": [
            {"assigned_to": str(assigned_to)},
            {"assigned_to": None},
            {"assigned_to": ""},
            {"assigned_to": {"$exists": False}},
        ]})
    query: Dict[str, Any] = {"$and": clauses} if clauses else {}

    cursor = db["tickets"].find(query).sort("created_at", -1)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_get_ticket_by_id(ticket_id: str) -> Optional[Dict[str, Any]]:
    """Get single service ticket with full details."""
    db = get_mongo_db()
    if db is None:
        return None
    tid = str(ticket_id)
    doc = db["tickets"].find_one({"$or": [{"_id": tid}, {"id": tid}, {"ticket_no": tid}]})
    return _format_mongo_doc(doc) if doc else None


def mongo_create_ticket(data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new service ticket in MongoDB."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    tickets_col = db["tickets"]
    now = datetime.now(timezone.utc)
    ticket_id = str(data.get("id") or uuid.uuid4())
    ticket_no = data.get("ticket_no") or f"TCK-{now.year}-{int(now.timestamp()) % 10000:04d}"

    doc = {
        "_id": ticket_id,
        "id": ticket_id,
        "ticket_no": ticket_no,
        "customer_id": str(data.get("customer_id", "")),
        "customer_name": sanitize_input(data.get("customer_name", "Customer")),
        "customer_phone": sanitize_input(data.get("customer_phone", "")),
        "customer_address": sanitize_input(data.get("customer_address", "")),
        "type": data.get("type", "inverter").lower(),
        "title": sanitize_input(data.get("title", "")),
        "description": sanitize_input(data.get("description", "")),
        "error_code": sanitize_input(data.get("error_code", "")),
        "status": data.get("status", "open").lower(),
        "priority": data.get("priority", "normal").lower(),
        "assigned_to": data.get("assigned_to"),
        "assigned_staff": data.get("assigned_staff"),
        "assigned_staff_emp_no": data.get("assigned_staff_emp_no"),
        "images": data.get("images", []),
        "comments": data.get("comments", []),
        "created_at": now,
        "updated_at": now,
    }
    tickets_col.insert_one(doc)
    return _format_mongo_doc(doc)


def mongo_update_ticket_status(ticket_id: str, new_status: str, note: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Update ticket resolution status."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    tid = str(ticket_id)
    now = datetime.now(timezone.utc)
    updates: Dict[str, Any] = {
        "status": new_status.lower(),
        "updated_at": now,
    }
    if new_status.lower() == "resolved":
        updates["resolved_at"] = now
    if note:
        updates["resolution_notes"] = sanitize_input(note)

    res = db["tickets"].find_one_and_update(
        {"$or": [{"_id": tid}, {"id": tid}, {"ticket_no": tid}]},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


def mongo_add_ticket_comment(ticket_id: str, author_name: str, author_role: str, message: str) -> Optional[Dict[str, Any]]:
    """Add a customer or staff comment to service ticket."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    tid = str(ticket_id)
    now = datetime.now(timezone.utc)
    comment = {
        "id": str(uuid.uuid4()),
        "author_name": sanitize_input(author_name),
        "author_role": author_role.lower(),
        "message": sanitize_input(message),
        "created_at": now.isoformat(),
    }
    res = db["tickets"].find_one_and_update(
        {"$or": [{"_id": tid}, {"id": tid}, {"ticket_no": tid}]},
        {"$push": {"comments": comment}, "$set": {"updated_at": now}},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


# ── Notifications in MongoDB Atlas ──────────────────────────────────────────

def mongo_create_notification(notif_data: Dict[str, Any]) -> Dict[str, Any]:
    """Insert an in-app notification into MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        return notif_data
    notifs_col = db["notifications"]
    now = datetime.now(timezone.utc)
    nid = str(notif_data.get("id") or uuid.uuid4())
    doc = {
        "_id": nid,
        "id": nid,
        "title": sanitize_input(notif_data.get("title", "")),
        "body": sanitize_input(notif_data.get("body", "")),
        "type": str(notif_data.get("type", "system")).lower(),
        "target_id": str(notif_data.get("target_id", "")) if notif_data.get("target_id") else None,
        "target_role": str(notif_data.get("target_role", "")).lower() if notif_data.get("target_role") else None,
        "user_id": str(notif_data.get("user_id", "")) if notif_data.get("user_id") else None,
        "is_read": False,
        "read": False,
        "metadata": notif_data.get("metadata", {}),
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }
    notifs_col.insert_one(doc)
    return _format_mongo_doc(doc)


def _notification_visibility(user_id: Optional[str], role: Optional[str]) -> List[Dict[str, Any]]:
    """Notifications a user may see: addressed to them, or broadcast to their role."""
    clauses: List[Dict[str, Any]] = []
    if user_id:
        clauses.append({"user_id": str(user_id)})
    if role:
        role_clean = role.lower()
        role_targets = {role_clean}
        if role_clean in ("admin", "main_admin", "super_admin", "co_admin", "vendor"):
            role_targets |= {"admin", "main_admin", "super_admin"}
        clauses.append({"target_role": {"$in": sorted(role_targets)}, "$or": [{"user_id": None}, {"user_id": {"$exists": False}}]})
    return clauses


def mongo_get_notifications(
    user_id: Optional[str] = None,
    role: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> List[Dict[str, Any]]:
    """List in-app notifications for a user or role from MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        return []
    notifs_col = db["notifications"]

    or_clauses = _notification_visibility(user_id, role)
    if not or_clauses:
        return []
    query: Dict[str, Any] = {"$or": or_clauses}

    cursor = notifs_col.find(query).sort("created_at", -1).skip(offset).limit(limit)
    return [_format_mongo_doc(doc) for doc in cursor]


def mongo_get_unread_notification_count(
    user_id: Optional[str] = None,
    role: Optional[str] = None,
) -> int:
    """Get count of unread notifications from MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        return 0
    or_clauses = _notification_visibility(user_id, role)
    if not or_clauses:
        return 0
    query: Dict[str, Any] = {"$or": or_clauses, "is_read": False}
    return db["notifications"].count_documents(query)


def mongo_mark_notification_read(notification_id: str, user_id: str, role: str) -> bool:
    """Mark one notification read, only if it is visible to the caller."""
    db = get_mongo_db()
    if db is None:
        return False
    visibility = _notification_visibility(user_id, role)
    if not visibility:
        return False
    nid = str(notification_id)
    now = datetime.now(timezone.utc)
    res = db["notifications"].update_one(
        {"$and": [{"$or": [{"_id": nid}, {"id": nid}]}, {"$or": visibility}]},
        {"$set": {"is_read": True, "read": True, "read_at": now.isoformat()}},
    )
    return res.matched_count > 0


def mongo_mark_all_notifications_read(
    user_id: Optional[str] = None,
    role: Optional[str] = None,
) -> int:
    """Mark all matching notifications as read."""
    db = get_mongo_db()
    if db is None:
        return 0
    now = datetime.now(timezone.utc)
    or_clauses = _notification_visibility(user_id, role)
    if not or_clauses:
        return 0
    query = {"$or": or_clauses, "is_read": False}
    res = db["notifications"].update_many(
        query,
        {"$set": {"is_read": True, "read": True, "read_at": now.isoformat()}},
    )
    return res.modified_count



