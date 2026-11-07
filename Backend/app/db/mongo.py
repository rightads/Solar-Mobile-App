from datetime import datetime, timezone, timedelta
import uuid
from typing import Any, Dict, List, Optional
import structlog
from pymongo import ASCENDING, MongoClient
from pymongo.collection import Collection
from pymongo.database import Database
from app.core.config import settings
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
                serverSelectionTimeoutMS=15000,
                connectTimeoutMS=15000,
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
                # Use solar_app_db or portfolio_db
                _db = client["solar_app_db"]
            except Exception as e:
                logger.error("Failed to access MongoDB database", error=str(e))
    return _db



def init_mongo() -> bool:
    """Initialize collections, indexes, and seed demo accounts with salted bcrypt hashes."""
    db = get_mongo_db()
    if db is None:
        logger.warning("MongoDB not connected. Skipping MongoDB initialization.")
        return False

    try:
        # Check connection
        db.command("ping")
        logger.info("Successfully connected to MongoDB Atlas!")

        # Collections
        users_col: Collection = db["users"]
        leads_col: Collection = db["leads"]
        customers_col: Collection = db["customers"]

        # Ensure indexes (defends against race conditions & duplicates)
        users_col.create_index([("phone", ASCENDING)], unique=True)
        users_col.create_index([("email", ASCENDING)], unique=True, sparse=True)
        leads_col.create_index([("phone", ASCENDING)])
        customers_col.create_index([("phone", ASCENDING)])

        now = datetime.now(timezone.utc)

        # Seed or sync Super Admin account directly from environment variables
        super_admin_email = (settings.SUPER_ADMIN_EMAIL or "admin@solarpro.com").strip().lower()
        super_admin_phone = normalize_phone(settings.SUPER_ADMIN_PHONE or "9876543210")
        if super_admin_phone in ("9837039028", "+919837039028"):
            # 9837039028 is reserved for the primary mobile client (Aryan Singh Jadaun)
            super_admin_phone = "9876543210"
        super_admin_name = settings.SUPER_ADMIN_NAME or "Super Admin"
        super_admin_pwd = settings.SUPER_ADMIN_PASSWORD

        # 1. Locate primary admin account by email or is_superadmin
        existing_admin = users_col.find_one({"$or": [{"email": super_admin_email}, {"is_superadmin": True}]})
        admin_id = str(existing_admin["_id"]) if existing_admin else str(uuid.uuid4())

        if not existing_admin and not super_admin_pwd:
            logger.warning("SUPER_ADMIN_PASSWORD not set; skipping Super Admin creation")
        else:
            # 2. Check if another document holds super_admin_phone
            conflicting_phone_user = users_col.find_one({"phone": super_admin_phone, "_id": {"$ne": admin_id}})
            if conflicting_phone_user:
                if conflicting_phone_user.get("role") == "admin" or conflicting_phone_user.get("is_superadmin"):
                    users_col.delete_one({"_id": conflicting_phone_user["_id"]})
                else:
                    users_col.update_one(
                        {"_id": conflicting_phone_user["_id"]},
                        {"$set": {"phone": f"{conflicting_phone_user['phone']}_old_{int(now.timestamp())}"}}
                    )

            set_on_insert = {
                "created_at": now,
                "last_login_at": None,
            }
            if not existing_admin:
                # Password is only ever written when the admin is first created; existing hashes are never touched
                set_on_insert["password_hash"] = hash_password(super_admin_pwd)

            users_col.update_one(
                {"_id": admin_id},
                {
                    "$set": {
                        "id": admin_id,
                        "name": super_admin_name,
                        "email": super_admin_email,
                        "phone": super_admin_phone,
                        "role": "admin",
                        "is_superadmin": True,
                        "is_active": True,
                        "approval_status": "approved",
                        "is_email_verified": True,
                        "updated_at": now,
                    },
                    "$setOnInsert": set_on_insert,
                },
                upsert=True
            )
            logger.info("Synchronized Super Admin account from environment", email=super_admin_email, phone=super_admin_phone)

        # Email verification indexes
        db["email_verifications"].create_index([("email", ASCENDING)])
        users_col.create_index([("approval_status", ASCENDING)])
        return True
    except Exception as e:
        logger.error("MongoDB initialization error", error=str(e))
        return False


def mongo_find_user_by_identifier(identifier: str) -> Optional[Dict[str, Any]]:
    """
    Find user by phone or email with strict injection protection.
    Guarantees no raw query evaluation or operator injection.
    """
    global _client, _db
    clean_id = str(identifier).strip()
    phone_clean = None
    try:
        phone_clean = normalize_phone(clean_id)
    except Exception:
        phone_clean = None

    query_conditions = [{"email": clean_id.lower()}]
    if phone_clean:
        query_conditions.append({"phone": phone_clean})
    else:
        query_conditions.append({"phone": clean_id})

    # Try up to 2 times with auto-reconnect
    for attempt in range(2):
        db = get_mongo_db()
        if db is None:
            return None
        try:
            users_col = db["users"]
            user = users_col.find_one({"$or": query_conditions, "is_active": True})
            return user
        except Exception as e:
            logger.warning("MongoDB query attempt failed, reconnecting", attempt=attempt, error=str(e))
            _client = None
            _db = None
            if attempt == 1:
                return None
    return None



def mongo_create_user(
    name: str,
    phone: str,
    password: str,
    role: str = "client",
    email: Optional[str] = None,
    is_email_verified: Optional[bool] = None,
) -> Dict[str, Any]:
    """Create or update unverified user with salted bcrypt password in MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")

    users_col = db["users"]
    now = datetime.now(timezone.utc)
    phone_normalized = normalize_phone(phone)
    clean_email = email.strip().lower() if email else None

    # Check existence
    existing_phone = users_col.find_one({"phone": phone_normalized})
    existing_email = users_col.find_one({"email": clean_email}) if clean_email else None

    # 1. If an ALREADY VERIFIED user exists with this phone or email, reject with clear instructions
    if existing_phone and existing_phone.get("is_email_verified") is True:
        raise ValueError("An active, verified account already exists with this mobile number. Please log in directly.")

    if existing_email and existing_email.get("is_email_verified") is True:
        raise ValueError("An active, verified account already exists with this email address. Please log in directly.")

    pwd_hash = hash_password(password)
    is_client = role.lower() == "client"
    approval_status = "approved" if is_client else "pending"
    is_active = True if is_client else False
    if is_email_verified is None:
        is_email_verified = False if is_client else True

    # 2. If an UNVERIFIED user exists, allow them to re-register/update their details & finish verification
    existing_unverified = existing_phone or existing_email
    if existing_unverified:
        user_id = str(existing_unverified["_id"])
        updated_doc = {
            "name": sanitize_input(name),
            "phone": phone_normalized,
            "email": clean_email,
            "role": role.lower(),
            "requested_role": role.lower(),
            "password_hash": pwd_hash,
            "is_active": is_active,
            "approval_status": approval_status,
            "is_email_verified": is_email_verified,
            "updated_at": now,
        }
        users_col.update_one({"_id": existing_unverified["_id"]}, {"$set": updated_doc})
        doc = {**existing_unverified, **updated_doc}
        return doc

    # 3. Completely new user insertion
    user_id = str(uuid.uuid4())
    doc = {
        "_id": user_id,
        "id": user_id,
        "name": sanitize_input(name),
        "phone": phone_normalized,
        "email": clean_email,
        "role": role.lower(),
        "requested_role": role.lower(),
        "password_hash": pwd_hash,
        "is_active": is_active,
        "approval_status": approval_status,
        "is_email_verified": is_email_verified,
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
        if "sales" in role:
            prefix = "EMP-SLS"
        elif "kedl" in role:
            prefix = "EMP-KEDL"
        elif "service" in role or "tech" in role:
            prefix = "EMP-SRV"
        else:
            prefix = "EMP-SITE"
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
        {"$set": {"approval_status": "rejected", "is_active": False, "rejected_at": now, "updated_at": now}},
        return_document=ReturnDocument.AFTER,
    )
    if res:
        res["id"] = str(res["_id"])
        res.pop("password_hash", None)
    return res


def mongo_update_login_timestamp(user_id: str) -> None:
    db = get_mongo_db()
    if db is not None:
        now = datetime.now(timezone.utc)
        db["users"].update_one({"_id": user_id}, {"$set": {"last_login_at": now}})


def mongo_create_lead(lead_data: Dict[str, Any]) -> Dict[str, Any]:
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    leads_col = db["leads"]
    now = datetime.now(timezone.utc)
    lead_id = str(uuid.uuid4())
    doc = {
        "_id": lead_id,
        "id": lead_id,
        "name": sanitize_input(lead_data.get("name", "")),
        "phone": sanitize_input(lead_data.get("phone", "")),
        "area": sanitize_input(lead_data.get("area", "")),
        "kw": float(lead_data.get("kw", 3.0)),
        "status": lead_data.get("status", "new"),
        "source": lead_data.get("source", "Direct"),
        "created_at": now,
        "updated_at": now,
    }
    leads_col.insert_one(doc)
    return doc


def _format_mongo_doc(doc: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not doc:
        return doc
    res = dict(doc)
    doc_id = str(res.get("id") or res.get("_id"))
    res["id"] = doc_id
    res["_id"] = str(res["_id"])
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
        s = sanitize_input(search)
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
    customers_col = db["customers"]
    now = datetime.now(timezone.utc)
    cust_id = str(customer_data.get("id") or uuid.uuid4())
    final_price_val = int(customer_data.get("final_price") or customer_data.get("total_amount") or 250000)
    doc = {
        "_id": cust_id,
        "id": cust_id,
        "name": sanitize_input(customer_data.get("name", "")),
        "phone": sanitize_input(customer_data.get("phone", customer_data.get("mobile", ""))),
        "mobile": sanitize_input(customer_data.get("phone", customer_data.get("mobile", ""))),
        "email": sanitize_input(customer_data.get("email", "")),
        "address": sanitize_input(customer_data.get("address", "")),
        "location_gps": customer_data.get("location_gps") or customer_data.get("gps") or "",
        "kw": float(customer_data.get("kw", customer_data.get("capacity_kw", 5.0))),
        "capacity_kw": float(customer_data.get("capacity_kw", customer_data.get("kw", 5.0))),
        "final_price": final_price_val,
        "total_amount": final_price_val,
        "paid_amount": int(customer_data.get("paid_amount", 0)),
        "phase": customer_data.get("phase", "single"),
        "panel_brand": customer_data.get("panel_brand", "Waaree"),
        "panel_watt": int(customer_data.get("panel_watt", 540)),
        "panel_count": int(customer_data.get("panel_count", 10)),
        "inverter_brand": customer_data.get("inverter_brand", "Growatt"),
        "structure_type": customer_data.get("structure_type", "Rooftop GI"),
        "stage": customer_data.get("stage", "SALE_CONFIRMED"),
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
    return _format_mongo_doc(doc)



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
        s = sanitize_input(search)
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
    approver_email: str = "rajesh.sharma@solarpro.in",
    approver_name: Optional[str] = None,
    approver_emp_no: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    payments_col = db["payments"]
    now = datetime.now(timezone.utc)

    if not approver_name:
        u = db["users"].find_one({"$or": [{"email": approver_email.lower()}, {"phone": approver_email}]})
        if u:
            approver_name = u.get("name")
            approver_emp_no = u.get("employee_no")

    res = payments_col.find_one_and_update(
        {"$or": [{"_id": str(payment_id)}, {"id": str(payment_id)}]},
        {"$set": {
            "status": "sales_approved",
            "sales_approved_by": approver_email,
            "sales_approved_by_name": approver_name or "Rajesh Sharma",
            "sales_approver_emp_no": approver_emp_no or "EMP-SLS-042",
            "sales_approved_at": now,
            "updated_at": now,
        }},
        return_document=ReturnDocument.AFTER,
    )
    return _format_mongo_doc(res) if res else None


def mongo_store_otp(phone: str, code_hash: str, expires_at: datetime) -> None:
    db = get_mongo_db()
    if db is None:
        return
    db["otp_codes"].insert_one({
        "_id": str(uuid.uuid4()),
        "phone": phone,
        "code_hash": code_hash,
        "expires_at": expires_at,
        "attempts": 0,
        "consumed_at": None,
        "created_at": datetime.now(timezone.utc),
    })


def mongo_verify_otp(phone: str, otp: str) -> bool:
    from app.core.security import verify_token_hash, normalize_phone
    db = get_mongo_db()
    if db is None:
        return False
    now = datetime.now(timezone.utc)
    phone_clean = phone.strip()
    try:
        norm = normalize_phone(phone_clean)
    except Exception:
        norm = phone_clean

    rec = db["otp_codes"].find_one({
        "phone": {"$in": [phone_clean, norm]},
        "consumed_at": None,
        "expires_at": {"$gt": now},
    }, sort=[("created_at", -1)])
    if not rec:
        return False
    if rec.get("attempts", 0) >= 5:
        return False
    valid = verify_token_hash(otp.strip(), rec["code_hash"])
    if valid:
        db["otp_codes"].update_one({"_id": rec["_id"]}, {"$set": {"consumed_at": now}})
        return True
    else:
        db["otp_codes"].update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
        return False


def mongo_find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    """Look up user by email directly."""
    db = get_mongo_db()
    if db is None:
        return None
    return db["users"].find_one({"email": email.strip().lower(), "is_active": True})


def mongo_store_email_verification(email: str, code_hash: str, expires_at: datetime) -> None:
    """Store email verification token record in MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        return
    db["email_verifications"].insert_one({
        "_id": str(uuid.uuid4()),
        "email": email.strip().lower(),
        "code_hash": code_hash,
        "expires_at": expires_at,
        "attempts": 0,
        "consumed_at": None,
        "created_at": datetime.now(timezone.utc),
    })


def mongo_verify_email_code(email: str, code: str) -> bool:
    """Verify email code against Mongo records with attempts limit and expiry."""
    from app.core.security import verify_token_hash
    db = get_mongo_db()
    if db is None:
        return False
    now = datetime.now(timezone.utc)
    rec = db["email_verifications"].find_one({
        "email": email.strip().lower(),
        "consumed_at": None,
        "expires_at": {"$gt": now},
    }, sort=[("created_at", -1)])

    if not rec:
        return False

    if rec.get("attempts", 0) >= 5:
        return False

    valid = verify_token_hash(code.strip(), rec["code_hash"])

    if valid:
        db["email_verifications"].update_one({"_id": rec["_id"]}, {"$set": {"consumed_at": now}})
        return True
    else:
        db["email_verifications"].update_one({"_id": rec["_id"]}, {"$inc": {"attempts": 1}})
        return False


def mongo_mark_email_verified(email: str) -> bool:
    """Mark user as verified in MongoDB Atlas."""
    db = get_mongo_db()
    if db is None:
        return False
    now = datetime.now(timezone.utc)
    res = db["users"].update_one(
        {"email": email.strip().lower()},
        {"$set": {"is_email_verified": True, "email_verified_at": now, "updated_at": now}},
    )
    return res.modified_count > 0 or res.matched_count > 0


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
        cust_payload = {
            "name": customer_data.get("name") or lead.get("name"),
            "phone": customer_data.get("phone") or lead.get("phone"),
            "address": customer_data.get("address") or lead.get("area"),
            "kw": float(customer_data.get("kw") or lead.get("kw", 5.0)),
            "sales_id": lead.get("assigned_sales_id"),
            "sales_name": lead.get("assigned_sales_name"),
            "stage": "SALE_CONFIRMED",
            **customer_data,
        }
        cust = mongo_create_customer(cust_payload)
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

def mongo_create_employee(employee_data: Dict[str, Any]) -> Dict[str, Any]:
    """Add a new employee / labour / electrician / civil / sales team member with credentials."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    users_col = db["users"]
    now = datetime.now(timezone.utc)
    emp_id = str(employee_data.get("id") or uuid.uuid4())
    name = sanitize_input(employee_data.get("name", ""))
    phone = normalize_phone(employee_data.get("phone", ""))
    trade = employee_data.get("trade", "labour").lower()
    team = sanitize_input(employee_data.get("team", "Team A"))
    role = employee_data.get("role", "employee").lower()
    email = employee_data.get("email")
    if email:
        email = email.strip().lower()

    employee_no = employee_data.get("employee_no")
    if not employee_no:
        prefix = "EMP-SLS" if "sales" in role else ("EMP-KEDL" if "kedl" in role else "EMP-SITE")
        employee_no = f"{prefix}-{emp_id[:4].upper()}"

    doc = {
        "_id": emp_id,
        "id": emp_id,
        "name": name,
        "phone": phone,
        "role": role,
        "trade": trade,
        "team": team,
        "employee_no": employee_no,
        "is_active": True,
        "approval_status": "approved",
        "is_email_verified": True,
        "updated_at": now,
    }
    if email:
        doc["email"] = email

    raw_password = employee_data.get("password")
    if raw_password:
        doc["password_hash"] = hash_password(raw_password)

    query_or = [{"_id": emp_id}, {"phone": phone}]
    if email:
        query_or.append({"email": email})

    users_col.update_one(
        {"$or": query_or},
        {"$set": doc, "$setOnInsert": {"created_at": now, "last_login_at": None}},
        upsert=True,
    )
    return _format_mongo_doc(doc)


def mongo_get_employees(trade: Optional[str] = None, team: Optional[str] = None, status: Optional[str] = None) -> List[Dict[str, Any]]:
    """List labour, electricians, sales, service, and staff with active task counts. Only approved, active staff are listed unless status is specified."""
    db = get_mongo_db()
    if db is None:
        return []
    query: Dict[str, Any] = {
        "role": {
            "$in": [
                "employee",
                "labour",
                "sales",
                "salesman",
                "kedl",
                "technician",
                "service",
                "electrician",
                "civil",
                "structure",
                "site",
            ]
        }
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

    if trade and trade.lower() != "all":
        query["trade"] = trade.lower()
    if team and team.lower() != "all":
        query["team"] = team
    cursor = db["users"].find(query).sort("created_at", -1)
    results = []
    for doc in cursor:
        f_doc = _format_mongo_doc(doc)
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
    w_cursor = db["work_assignments"].find({
        "$or": [
            {"assigned_employee_id": eid},
            {"assigned_to": eid},
            {"assigned_employee_name": emp_name},
            {"assigned_staff": emp_name},
            {"assigned_employee_no": emp_no},
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
    t_cursor = db["tickets"].find({
        "$or": [
            {"assigned_to": eid},
            {"assigned_staff": emp_name},
            {"assigned_staff_emp_no": emp_no},
        ]
    }).sort("created_at", -1)
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
        "lead_phone": normalize_phone(team_data.get("lead_phone", "")),
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
    # If no custom teams saved yet, provide standard base teams
    if not items:
        defaults = [
            {"id": "t1", "name": "Team A", "trade_type": "structure", "lead_name": "Sunil Kumar", "lead_phone": "9811223344", "member_count": 4},
            {"id": "t2", "name": "Team B", "trade_type": "structure", "lead_name": "Ramesh Singh", "lead_phone": "9822334455", "member_count": 3},
            {"id": "t3", "name": "Team A", "trade_type": "electrical", "lead_name": "Mohit Sharma (Electrician)", "lead_phone": "9833445566", "member_count": 3},
            {"id": "t4", "name": "Team B", "trade_type": "electrical", "lead_name": "Vikram Wireman", "lead_phone": "9844556677", "member_count": 2},
            {"id": "t5", "name": "Team A", "trade_type": "civil", "lead_name": "Deepak Mistry", "lead_phone": "9855667788", "member_count": 4},
            {"id": "t6", "name": "Team B", "trade_type": "civil", "lead_name": "Suresh Foundation", "lead_phone": "9866778899", "member_count": 3},
        ]
        if trade_type and trade_type.lower() != "all":
            return [d for d in defaults if d["trade_type"] == trade_type.lower()]
        return defaults
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
    """Update work assignment status or dates."""
    from pymongo import ReturnDocument
    db = get_mongo_db()
    if db is None:
        return None
    aid = str(assignment_id)
    clean = {k: v for k, v in updates.items() if k not in ["_id", "id"]}
    clean["updated_at"] = datetime.now(timezone.utc)
    res = db["work_assignments"].find_one_and_update(
        {"$or": [{"_id": aid}, {"id": aid}]},
        {"$set": clean},
        return_document=ReturnDocument.AFTER,
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

def mongo_get_client_home(user_id_or_phone: str) -> Dict[str, Any]:
    """Fetch aggregated dynamic home data for client mobile dashboard."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")

    user = db["users"].find_one({
        "$or": [{"id": user_id_or_phone}, {"_id": user_id_or_phone}, {"phone": user_id_or_phone}]
    })
    user_name = user.get("name", "Aryan Singh Jadaun") if user else "Aryan Singh Jadaun"
    user_phone = user.get("phone", "9837039028") if user else "9837039028"

    customer = db["customers"].find_one({
        "$or": [{"phone": user_phone}, {"mobile": user_phone}, {"user_id": str(user.get("_id") if user else "")}]
    })

    now = datetime.now(timezone.utc)
    if not customer:
        cust_id = str(uuid.uuid4())
        customer = {
            "_id": cust_id,
            "id": cust_id,
            "user_id": str(user["_id"]) if user else cust_id,
            "name": user_name,
            "phone": user_phone,
            "mobile": user_phone,
            "address": "Plot 42, Sunrise Enclave, Sector 14, Jaipur, Rajasthan",
            "capacity_kw": 5.5,
            "final_price": 25000000,  # ₹2,50,000 in paise
            "phase": "single",
            "panel_brand": "Tata Power Solar 550W Mono PERC",
            "panel_watt": 550,
            "panel_count": 10,
            "inverter_brand": "Growatt 6kW Hybrid Inverter",
            "structure_type": "High-Rise Heavy Duty Galvanized Structure",
            "stage": "STRUCTURE_WORK",
            "created_at": now,
            "updated_at": now,
        }
        db["customers"].insert_one(customer)

    # Assigned Sales Rep from real DB users
    sales_rep = db["users"].find_one({"role": {"$in": ["sales", "salesman"]}})
    if not sales_rep:
        sales_rep = {
            "name": "Rajesh Sharma",
            "phone": "+91 98290 12345",
            "email": "rajesh.sharma@solarpro.in",
            "employee_no": "EMP-SLS-042",
        }

    # Assigned Site / Technician lead from real DB users
    site_emp = db["users"].find_one({"role": {"$in": ["labour", "structure", "technician", "electrician"]}})
    if not site_emp:
        site_emp = {
            "name": "Sunil Kumar",
            "phone": "+91 98290 98765",
            "email": "sunil.kumar@solarpro.in",
            "employee_no": "EMP-SITE-015",
            "trade": "structure",
        }

    # 10-Stage Milestone Timeline
    from app.core.constants import STAGE_ORDER
    stage_keys = [s[0] for s in STAGE_ORDER]
    cust_stage = customer.get("stage", "STRUCTURE_WORK")
    curr_idx = stage_keys.index(cust_stage) if cust_stage in stage_keys else 3

    timeline = []
    stage_notes = {
        "SALE_CONFIRMED": "Sales agreement signed and advance token verified.",
        "DOCUMENTS_RECEIVED": "Aadhaar, Electricity Bill and rooftop pictures verified.",
        "ADVANCE_VERIFIED": "Payment approved by salesman & verified by admin.",
        "STRUCTURE_WORK": "Hot-dip galvanized mounting structure installation ongoing.",
        "ELECTRICAL_WORK": "DC cabling, conduits and earthing connection.",
        "CIVIL_WORK": "Grouting and rooftop water-proofing inspection.",
        "INSTALLATION_COMPLETE": "Solar panels and inverter physically mounted.",
        "KEDL_PROCESS": "Discom paperwork and inspection liaison.",
        "SYSTEM_LIVE": "Bi-directional net meter sync with grid.",
        "HANDED_OVER": "Project handed over with 25-year solar warranty kit.",
    }

    for idx, (s_key, s_title) in enumerate(STAGE_ORDER):
        if idx < curr_idx:
            status_str = "done"
            dt = (now - timedelta(days=(curr_idx - idx) * 3)).isoformat()
        elif idx == curr_idx:
            status_str = "current"
            dt = now.isoformat()
        else:
            status_str = "upcoming"
            dt = None

        timeline.append({
            "stage": s_key,
            "title": s_title,
            "status": status_str,
            "date": dt,
            "note": stage_notes.get(s_key, ""),
        })

    # Financials
    payments_info = mongo_get_customer_payments(str(customer["_id"]))
    verified_paise = payments_info["summary"]["verified"]
    total_paid_paise = payments_info["summary"]["total_paid"]
    final_price_paise = int(customer.get("final_price", 25000000))
    remaining_paise = max(0, final_price_paise - verified_paise)

    # Responsible Contact
    if cust_stage in ["STRUCTURE_WORK", "ELECTRICAL_WORK", "CIVIL_WORK", "INSTALLATION_COMPLETE"]:
        trade_name = site_emp.get("trade", "Structure").capitalize()
        resp_contact = {
            "name": f"{site_emp.get('name', 'Sunil Kumar')}",
            "phone": site_emp.get("phone", "+91 98290 98765"),
            "role_title": f"{trade_name} Installation Lead",
            "employee_no": site_emp.get("employee_no", "EMP-SITE-015"),
            "email": site_emp.get("email", "site@solarpro.in"),
        }
    else:
        resp_contact = {
            "name": sales_rep.get("name", "Rajesh Sharma"),
            "phone": sales_rep.get("phone", "+91 98290 12345"),
            "role_title": "Senior Sales Representative",
            "employee_no": sales_rep.get("employee_no", "EMP-SLS-042"),
            "email": sales_rep.get("email", "rajesh.sharma@solarpro.in"),
        }

    sales_contact = {
        "name": sales_rep.get("name", "Rajesh Sharma"),
        "phone": sales_rep.get("phone", "+91 98290 12345"),
        "role_title": "Sales Executive",
        "employee_no": sales_rep.get("employee_no", "EMP-SLS-042"),
        "email": sales_rep.get("email", "rajesh.sharma@solarpro.in"),
    }

    return {
        "customer": {
            "id": str(customer["_id"]),
            "name": customer["name"],
            "mobile": customer["phone"],
            "address": customer.get("address", ""),
            "capacity_kw": float(customer.get("capacity_kw", 5.5)),
            "final_price": final_price_paise,
            "stage": cust_stage,
        },
        "stage": cust_stage,
        "timeline": timeline,
        "responsible_contact": resp_contact,
        "sales_contact": sales_contact,
        "payment_summary": {
            "final_price": final_price_paise,
            "total_amount": final_price_paise / 100.0,
            "total_paid": total_paid_paise / 100.0 if total_paid_paise > 0 else 75000.0,
            "remaining_balance": remaining_paise / 100.0 if total_paid_paise > 0 else 175000.0,
            "next_milestone": "Structure Work Completion (₹50,000)",
        },
        "system_specs": {
            "capacity_kw": float(customer.get("capacity_kw", 5.5)),
            "phase": customer.get("phase", "single"),
            "panel_brand": customer.get("panel_brand", "Tata Power Solar 550W Mono PERC"),
            "panel_watt": int(customer.get("panel_watt", 550)),
            "panel_count": int(customer.get("panel_count", 10)),
            "inverter_brand": customer.get("inverter_brand", "Growatt 6kW Hybrid Inverter"),
            "structure_type": customer.get("structure_type", "High-Rise Heavy Duty Galvanized Structure"),
        },
    }


def mongo_get_client_payments(user_id_or_phone: str) -> List[Dict[str, Any]]:
    """Retrieve payments list for client payments tab."""
    db = get_mongo_db()
    if db is None:
        return []
    payments_col = db["payments"]

    cursor = payments_col.find({
        "$or": [
            {"client_phone": user_id_or_phone},
            {"customer_id": user_id_or_phone},
            {"submitted_by": user_id_or_phone},
        ]
    }).sort("created_at", -1)
    items = [_format_mongo_doc(doc) for doc in cursor]

    if not items:
        # Seed the initial 2 verified/approved payments in Mongo
        cust = db["customers"].find_one({"$or": [{"phone": user_id_or_phone}, {"mobile": user_id_or_phone}]})
        cust_id = str(cust["_id"]) if cust else str(uuid.uuid4())
        sales_rep = db["users"].find_one({"role": {"$in": ["sales", "salesman"]}})
        sales_name = sales_rep.get("name", "Rajesh Sharma") if sales_rep else "Rajesh Sharma"
        sales_emp_no = sales_rep.get("employee_no", "EMP-SLS-042") if sales_rep else "EMP-SLS-042"

        now = datetime.now(timezone.utc)
        p1 = {
            "_id": "pay-001",
            "id": "pay-001",
            "customer_id": cust_id,
            "client_phone": user_id_or_phone,
            "stage_no": 1,
            "stage_name": "Token Advance (Booking Confirmed)",
            "amount": 2500000,
            "amount_paise": 2500000,
            "amount_rupees": 25000.0,
            "mode": "UPI",
            "reference_no": "UPI/4891238910",
            "paid_on": now - timedelta(days=12),
            "proof_url": "assets/images/receipt_sample.png",
            "status": "verified",
            "sales_approved_by": sales_name,
            "sales_approved_by_name": sales_name,
            "sales_approver_emp_no": sales_emp_no,
            "verified_by_name": "Accounts Admin",
            "remarks": "Booking token payment received and verified",
            "created_at": now - timedelta(days=12),
            "updated_at": now - timedelta(days=12),
        }
        p2 = {
            "_id": "pay-002",
            "id": "pay-002",
            "customer_id": cust_id,
            "client_phone": user_id_or_phone,
            "stage_no": 2,
            "stage_name": "Structure Work Advance (Milestone 2)",
            "amount": 5000000,
            "amount_paise": 5000000,
            "amount_rupees": 50000.0,
            "mode": "IMPS",
            "reference_no": "IMPS/9812481023",
            "paid_on": now - timedelta(days=4),
            "proof_url": "assets/images/receipt_sample.png",
            "status": "sales_approved",
            "sales_approved_by": sales_name,
            "sales_approved_by_name": sales_name,
            "sales_approver_emp_no": sales_emp_no,
            "remarks": f"Payment proof verified by Salesman {sales_name}. Pending Admin verification.",
            "created_at": now - timedelta(days=4),
            "updated_at": now - timedelta(days=4),
        }
        payments_col.insert_many([p1, p2])
        items = [_format_mongo_doc(p2), _format_mongo_doc(p1)]

    return items


def mongo_record_client_payment(
    client_phone: str,
    amount_paise: int,
    mode: str,
    reference_no: Optional[str] = None,
    paid_on: Optional[datetime] = None,
    remarks: Optional[str] = None,
    proof_filename: Optional[str] = None,
) -> Dict[str, Any]:
    """Store new client submitted payment in MongoDB."""
    db = get_mongo_db()
    if db is None:
        raise RuntimeError("MongoDB is not available.")
    payments_col = db["payments"]
    now = datetime.now(timezone.utc)

    cust = db["customers"].find_one({"$or": [{"phone": client_phone}, {"mobile": client_phone}]})
    cust_id = str(cust["_id"]) if cust else str(uuid.uuid4())
    count = payments_col.count_documents({"customer_id": cust_id})

    pay_id = f"pay-{int(now.timestamp())}"
    doc = {
        "_id": pay_id,
        "id": pay_id,
        "customer_id": cust_id,
        "client_phone": client_phone,
        "stage_no": count + 1,
        "stage_name": "Rooftop Solar Milestone Payment",
        "amount": int(amount_paise),
        "amount_paise": int(amount_paise),
        "amount_rupees": float(amount_paise) / 100.0,
        "mode": str(mode).upper(),
        "reference_no": reference_no or f"TXN-{int(now.timestamp())}",
        "paid_on": paid_on or now,
        "proof_url": proof_filename or "assets/images/receipt_sample.png",
        "status": "pending",
        "sales_approved_by": None,
        "sales_approved_by_name": None,
        "sales_approver_emp_no": None,
        "remarks": remarks or "Submitted by customer with photo receipt for salesman approval.",
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

    cursor = kedl_col.find({"status": "demand_raised"})
    total_demand_amt = sum(int(doc.get("demand_amount", 0)) for doc in cursor)

    return {
        "total_files": total,
        "open_demands": demands_raised,
        "total_demand_paise": total_demand_amt * 100,  # paise
        "completed_files": approved,
        "pending_files": max(0, total - approved),
        "demands_paid_count": demands_paid,
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
    query: Dict[str, Any] = {}
    if customer_id:
        query["$or"] = [{"customer_id": str(customer_id)}, {"customer_phone": str(customer_id)}]
    if status and status.lower() != "all":
        query["status"] = status.lower()
    if ticket_type and ticket_type.lower() != "all":
        query["type"] = ticket_type.lower()
    if assigned_to:
        query["$or"] = [
            {"assigned_to": str(assigned_to)},
            {"assigned_staff": str(assigned_to)},
            {"assigned_staff_emp_no": str(assigned_to)},
            {"assigned_to": None},
            {"assigned_to": ""},
            {"assigned_to": {"$exists": False}},
        ]

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
        "assigned_staff": data.get("assigned_staff", "Vikram Singh"),
        "assigned_staff_emp_no": data.get("assigned_staff_emp_no", "EMP-SRV-104"),
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

    query: Dict[str, Any] = {}
    or_clauses = []
    if user_id:
        or_clauses.append({"user_id": str(user_id)})
    if role:
        role_clean = role.lower()
        or_clauses.append({"target_role": role_clean})
        if "admin" in role_clean:
            or_clauses.append({"target_role": "admin"})
            or_clauses.append({"target_role": "main_admin"})
            or_clauses.append({"target_role": "super_admin"})
    if not or_clauses:
        or_clauses.append({"target_role": {"$in": ["admin", "all", None]}})

    query["$or"] = or_clauses

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
    notifs_col = db["notifications"]

    or_clauses = []
    if user_id:
        or_clauses.append({"user_id": str(user_id)})
    if role:
        role_clean = role.lower()
        or_clauses.append({"target_role": role_clean})
        if "admin" in role_clean:
            or_clauses.append({"target_role": "admin"})
            or_clauses.append({"target_role": "main_admin"})
            or_clauses.append({"target_role": "super_admin"})
    if not or_clauses:
        or_clauses.append({"target_role": {"$in": ["admin", "all", None]}})

    query: Dict[str, Any] = {
        "$or": or_clauses,
        "$and": [{"is_read": False}, {"read": False}],
    }
    return notifs_col.count_documents(query)


def mongo_mark_notification_read(notification_id: str) -> bool:
    """Mark a single notification as read."""
    db = get_mongo_db()
    if db is None:
        return False
    now = datetime.now(timezone.utc)
    res = db["notifications"].update_one(
        {"$or": [{"_id": str(notification_id)}, {"id": str(notification_id)}]},
        {"$set": {"is_read": True, "read": True, "read_at": now.isoformat()}},
    )
    return res.modified_count > 0


def mongo_mark_all_notifications_read(
    user_id: Optional[str] = None,
    role: Optional[str] = None,
) -> int:
    """Mark all matching notifications as read."""
    db = get_mongo_db()
    if db is None:
        return 0
    now = datetime.now(timezone.utc)
    or_clauses = []
    if user_id:
        or_clauses.append({"user_id": str(user_id)})
    if role:
        role_clean = role.lower()
        or_clauses.append({"target_role": role_clean})
        if "admin" in role_clean:
            or_clauses.append({"target_role": "admin"})
    query = {"$or": or_clauses} if or_clauses else {}
    res = db["notifications"].update_many(
        query,
        {"$set": {"is_read": True, "read": True, "read_at": now.isoformat()}},
    )
    return res.modified_count



