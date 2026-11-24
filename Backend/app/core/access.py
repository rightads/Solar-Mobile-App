"""Role groups and object-level access checks (IDOR protection).

Every router resolves *what* a user may touch through these helpers instead of
trusting IDs from the request. Lookups that fail authorization raise 404 rather
than 403 so callers cannot probe which IDs exist.
"""
from typing import Any, Dict, Iterable, Optional, Set
from app.core.exceptions import ForbiddenException, NotFoundException

ADMIN_ROLES: Set[str] = {"admin", "main_admin", "co_admin", "super_admin", "vendor"}
MANAGER_ROLES: Set[str] = ADMIN_ROLES | {"manager"}
SALES_ROLES: Set[str] = {"sales", "salesman", "employee", "office_staff"}
# Discom (electricity board) paperwork. "kedl" is the legacy name.
KEDL_ROLES: Set[str] = {"discom", "kedl"}
DISCOM_ROLES = KEDL_ROLES
# Installation trades. "site", "labour", "electrician" and "technician" are
# legacy names for the same field crews.
SITE_ROLES: Set[str] = {"structure", "wiring", "civil", "site", "technician", "labour", "electrician"}
SUBSIDY_ROLES: Set[str] = {"subsidy"}
ACCOUNT_ROLES: Set[str] = {"account"}
# Legacy: Service is no longer a department, but existing service accounts
# keep handling the client tickets assigned to them.
SERVICE_ROLES: Set[str] = {"service", "technician"}
CLIENT_ROLES: Set[str] = {"client"}
STAFF_ROLES: Set[str] = (MANAGER_ROLES | SALES_ROLES | SITE_ROLES | KEDL_ROLES | SERVICE_ROLES
                         | SUBSIDY_ROLES | ACCOUNT_ROLES)

# The employee departments, in project order. Older accounts may carry legacy
# role names; department_of() maps those onto a department.
DEPARTMENTS = ("sales", "discom", "structure", "wiring", "civil", "subsidy", "account")
DEPARTMENT_LABELS = {
    "sales": "Salesman", "discom": "Discom", "structure": "Structure", "wiring": "Wiring",
    "civil": "Civil Work", "subsidy": "Subsidy", "account": "Account / Bill",
}
EMPLOYEE_NO_PREFIX = {
    "sales": "EMP-SLS", "discom": "EMP-DSC", "structure": "EMP-STR", "wiring": "EMP-WIR",
    "civil": "EMP-CVL", "subsidy": "EMP-SUB", "account": "EMP-ACC",
}

# Roles anyone may request through public self-registration (always pending
# admin approval except "client"). Admin accounts are never self-service.
PUBLIC_REGISTRATION_ROLES: Set[str] = {"client", *DEPARTMENTS}

# Roles an admin may create or assign through the employee APIs.
ASSIGNABLE_STAFF_ROLES: Set[str] = set(DEPARTMENTS)

_DEPARTMENT_ALIASES = {
    "salesman": "sales", "employee": "sales", "office_staff": "sales",
    "kedl": "discom",
    "site": "structure", "site_ops": "structure", "site-ops": "structure", "labour": "structure",
    "electrician": "wiring", "electrical": "wiring", "technician": "wiring",
    "accounts": "account", "billing": "account",
}

# Customer field holding the assigned employee of each department.
DEPARTMENT_FIELD = {
    "sales": "sales_id", "discom": "discom_employee_id", "structure": "structure_employee_id",
    "wiring": "wiring_employee_id", "civil": "civil_employee_id",
    "subsidy": "subsidy_employee_id", "account": "account_employee_id",
}


def normalize_department(value: Any) -> Optional[str]:
    """Map a role / legacy trade label to one of the departments."""
    key = str(value or "").strip().lower()
    if key in DEPARTMENTS:
        return key
    return _DEPARTMENT_ALIASES.get(key)


def department_of(user_or_doc: Any) -> Optional[str]:
    """Department of a user object or a raw user document."""
    role = user_or_doc.get("role") if isinstance(user_or_doc, dict) else role_of(user_or_doc)
    return normalize_department(role)


def role_of(user: Any) -> str:
    role = getattr(user, "role", "")
    return str(getattr(role, "value", role) or "").lower()


def user_id(user: Any) -> str:
    return str(getattr(user, "id", ""))


def in_roles(user: Any, roles: Iterable[str]) -> bool:
    return role_of(user) in set(roles)


def is_admin(user: Any) -> bool:
    return in_roles(user, ADMIN_ROLES)


def require_in(user: Any, roles: Iterable[str]) -> None:
    if not in_roles(user, roles):
        raise ForbiddenException("You do not have permission to perform this action.")


def _db():
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    if db is None:
        raise NotFoundException("Resource not found.")
    return db


def _by_id(collection: str, oid: str) -> Optional[Dict[str, Any]]:
    oid = str(oid)
    or_clauses = [{"_id": oid}, {"id": oid}]
    try:
        from bson import ObjectId
        if ObjectId.is_valid(oid):
            or_clauses.append({"_id": ObjectId(oid)})
    except Exception:
        pass
    return _db()[collection].find_one({"$or": or_clauses})


# ── Clients ──────────────────────────────────────────────────────────────────

def client_customer(user: Any) -> Optional[Dict[str, Any]]:
    """Return the customer record owned by a client user, linking it if safe.

    A customer created by sales is matched to a client account by phone only
    after that account has *proven* ownership of the number via SMS OTP
    (``is_phone_verified``). Registering with someone else's phone number
    therefore never exposes their project data.
    """
    if role_of(user) not in CLIENT_ROLES:
        return None
    db = _db()
    uid = user_id(user)
    raw_id = str(getattr(user, "_id", "") or "")
    id_conds = [{"user_id": uid}]
    if raw_id and raw_id != uid:
        id_conds.append({"user_id": raw_id})
    linked = db["customers"].find_one({"$or": id_conds})
    if linked:
        return linked
    if not getattr(user, "is_phone_verified", False):
        return None
    phone = str(getattr(user, "phone", "") or "")
    if not phone:
        return None
    candidate = db["customers"].find_one({
        "$and": [
            {"$or": [{"phone": phone}, {"mobile": phone}]},
            {"$or": [{"user_id": None}, {"user_id": {"$exists": False}}, {"user_id": ""}, {"user_id": uid}]},
        ]
    })
    if candidate:
        db["customers"].update_one({"_id": candidate["_id"]}, {"$set": {"user_id": uid}})
        candidate["user_id"] = uid
    return candidate


def require_client_customer(user: Any) -> Dict[str, Any]:
    cust = client_customer(user)
    if not cust:
        raise NotFoundException("No solar project is linked to your account yet.")
    return cust


# ── Customers ────────────────────────────────────────────────────────────────

def sales_customer_query(user: Any) -> Dict[str, Any]:
    """Mongo filter for the customers a sales user owns.

    Customers without a sales owner (client self-sign-ups, leads an admin
    converted without assigning them) stay admin-only until an admin assigns
    a salesperson; otherwise every salesperson could read and edit their KYC.
    """
    uid = user_id(user)
    return {"sales_id": uid} if uid else {"_id": {"$in": []}}


def _owns_customer(user: Any, cust: Dict[str, Any]) -> bool:
    uid = user_id(user)
    return bool(uid) and str(cust.get("sales_id") or "") == uid


def staff_can_view_customer(user: Any, cust: Dict[str, Any]) -> bool:
    role = role_of(user)
    uid = user_id(user)
    cid = str(cust.get("id") or cust.get("_id"))
    if role in MANAGER_ROLES:
        return True
    if role in SALES_ROLES:
        return _owns_customer(user, cust)
    department = normalize_department(role)
    field = DEPARTMENT_FIELD.get(department or "")
    if field and cust.get(field) == uid:
        return True
    db = _db()
    if role in KEDL_ROLES:
        if cust.get("kedl_employee_id") == uid:
            return True
        # Only files handed to this employee, or still in the unassigned queue.
        return db["kedl_files"].find_one({
            "customer_id": cid,
            "$or": [{"assigned_to": uid}, {"assigned_to": None}, {"assigned_to": ""}, {"assigned_to": {"$exists": False}}],
        }) is not None
    if role in SITE_ROLES and db["work_assignments"].find_one({
        "customer_id": cid,
        "$or": [{"assigned_to": uid}, {"assigned_employee_id": uid},
                {"assigned_to": None}, {"assigned_to": {"$exists": False}}],
    }):
        return True
    if role in SUBSIDY_ROLES | ACCOUNT_ROLES:
        # Unassigned projects currently waiting on this department (the queue).
        from app.services.workflow import STAGE_DEPARTMENT
        return not cust.get(field) and STAGE_DEPARTMENT.get(str(cust.get("stage") or "")) == department
    if role in SERVICE_ROLES:
        if cust.get("service_employee_id") == uid:
            return True
        return db["tickets"].find_one({
            "customer_id": cid,
            "$or": [{"assigned_to": uid}, {"assigned_to": None}, {"assigned_to": {"$exists": False}}],
        }) is not None
    return False


def can_view_customer(user: Any, cust: Dict[str, Any]) -> bool:
    if role_of(user) in CLIENT_ROLES:
        own = client_customer(user)
        return bool(own) and str(own["_id"]) == str(cust["_id"])
    return staff_can_view_customer(user, cust)


def require_customer(user: Any, customer_id: str) -> Dict[str, Any]:
    cust = _by_id("customers", customer_id)
    if not cust or not can_view_customer(user, cust):
        raise NotFoundException("Customer not found.")
    return cust


def require_customer_write(user: Any, customer_id: str) -> Dict[str, Any]:
    """Admins, or the sales owner of the customer, may modify it."""
    cust = _by_id("customers", customer_id)
    if not cust:
        raise NotFoundException("Customer not found.")
    role = role_of(user)
    if role in ADMIN_ROLES:
        return cust
    if role in SALES_ROLES and _owns_customer(user, cust):
        return cust
    raise NotFoundException("Customer not found.")


# ── Tickets ──────────────────────────────────────────────────────────────────

def can_view_ticket(user: Any, ticket: Dict[str, Any]) -> bool:
    role = role_of(user)
    uid = user_id(user)
    if role in MANAGER_ROLES:
        return True
    if role in CLIENT_ROLES:
        own = client_customer(user)
        return bool(own) and str(ticket.get("customer_id")) == str(own["_id"])
    if role in STAFF_ROLES and uid and ticket.get("assigned_to") == uid:
        return True  # any employee an admin assigned the ticket to
    if role in SERVICE_ROLES:
        return ticket.get("assigned_to") in (None, "", uid)
    return False


def require_ticket(user: Any, ticket_id: str) -> Dict[str, Any]:
    tid = str(ticket_id)
    ticket = _db()["tickets"].find_one({"$or": [{"_id": tid}, {"id": tid}, {"ticket_no": tid}]})
    if not ticket or not can_view_ticket(user, ticket):
        raise NotFoundException("Ticket not found.")
    return ticket


# ── Work assignments ────────────────────────────────────────────────────────

def site_trades(user: Any) -> Set[str]:
    trades = {str(getattr(user, "trade", "") or "").lower(), str(getattr(user, "team", "") or "").lower(), role_of(user)}
    return {t for t in trades if t in {"structure", "electrical", "civil", "electrician", "wiring"}} or set()


def work_scope_query(user: Any) -> Dict[str, Any]:
    """Mongo filter limiting which work assignments a user can see."""
    role = role_of(user)
    if role in MANAGER_ROLES:
        return {}
    if role in SALES_ROLES:
        # Sales plans work only for its own (or still unowned) customers.
        ids = [str(c["_id"]) for c in _db()["customers"].find(sales_customer_query(user), {"_id": 1})]
        return {"customer_id": {"$in": ids}}
    if role in SITE_ROLES:
        uid = user_id(user)
        unassigned: Dict[str, Any] = {"$or": [{"assigned_to": None}, {"assigned_to": ""}, {"assigned_to": {"$exists": False}}]}
        # Wiring work is stored as work_type "electrical".
        trades = {"electrical" if t in ("electrician", "wiring") else t for t in site_trades(user)}
        if trades:
            unassigned = {"$and": [unassigned, {"work_type": {"$in": sorted(trades)}}]}
        return {"$or": [{"assigned_to": uid}, {"assigned_employee_id": uid}, unassigned]}
    return {"_id": {"$in": []}}


def require_work(user: Any, assignment_id: str, *, write: bool = False) -> Dict[str, Any]:
    aid = str(assignment_id)
    query = {"$and": [{"$or": [{"_id": aid}, {"id": aid}]}, work_scope_query(user)]}
    work = _db()["work_assignments"].find_one(query)
    if not work:
        raise NotFoundException("Work assignment not found.")
    if write and role_of(user) not in MANAGER_ROLES | SITE_ROLES | SALES_ROLES:
        raise ForbiddenException("You do not have permission to update this work.")
    return work
