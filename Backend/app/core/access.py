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
SITE_ROLES: Set[str] = {"site", "technician", "labour", "electrician", "structure", "civil"}
KEDL_ROLES: Set[str] = {"kedl"}
SERVICE_ROLES: Set[str] = {"service", "technician"}
CLIENT_ROLES: Set[str] = {"client"}
STAFF_ROLES: Set[str] = MANAGER_ROLES | SALES_ROLES | SITE_ROLES | KEDL_ROLES | SERVICE_ROLES

# Roles anyone may request through public self-registration (always pending
# admin approval except "client"). Admin accounts are never self-service.
PUBLIC_REGISTRATION_ROLES: Set[str] = {"client", "sales", "site", "kedl", "service"}

# Roles an admin may create or assign through the employee APIs.
ASSIGNABLE_STAFF_ROLES: Set[str] = {"sales", "site", "kedl", "service", "technician", "labour",
                                    "electrician", "structure", "civil", "office_staff"}


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
    return _db()[collection].find_one({"$or": [{"_id": oid}, {"id": oid}]})


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
    linked = db["customers"].find_one({"user_id": uid})
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
            {"$or": [{"user_id": None}, {"user_id": {"$exists": False}}, {"user_id": ""}]},
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

def staff_can_view_customer(user: Any, cust: Dict[str, Any]) -> bool:
    role = role_of(user)
    uid = user_id(user)
    cid = str(cust.get("id") or cust.get("_id"))
    if role in MANAGER_ROLES:
        return True
    if role in SALES_ROLES:
        return str(cust.get("sales_id") or "") in ("", uid)
    db = _db()
    if role in KEDL_ROLES:
        if cust.get("kedl_employee_id") == uid:
            return True
        return db["kedl_files"].find_one({"customer_id": cid}) is not None
    if role in SITE_ROLES and db["work_assignments"].find_one({
        "customer_id": cid,
        "$or": [{"assigned_to": uid}, {"assigned_employee_id": uid},
                {"assigned_to": None}, {"assigned_to": {"$exists": False}}],
    }):
        return True
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
    if role in SALES_ROLES and str(cust.get("sales_id") or "") in ("", user_id(user)):
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
    return {t for t in trades if t in {"structure", "electrical", "civil", "electrician"}} or set()


def work_scope_query(user: Any) -> Dict[str, Any]:
    """Mongo filter limiting which work assignments a user can see."""
    role = role_of(user)
    if role in MANAGER_ROLES or role in SALES_ROLES:
        return {}
    if role in SITE_ROLES:
        uid = user_id(user)
        unassigned: Dict[str, Any] = {"$or": [{"assigned_to": None}, {"assigned_to": ""}, {"assigned_to": {"$exists": False}}]}
        trades = {"electrical" if t == "electrician" else t for t in site_trades(user)}
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
