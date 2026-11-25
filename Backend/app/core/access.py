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
    if isinstance(user, dict):
        return str(user.get("role") or "").lower()
    role = getattr(user, "role", "")
    return str(getattr(role, "value", role) or "").lower()


def user_id(user: Any) -> str:
    if isinstance(user, dict):
        return str(user.get("id") or user.get("_id") or "")
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

def _user_attr(user: Any, key: str) -> Any:
    if isinstance(user, dict):
        return user.get(key)
    return getattr(user, key, None)


def _verified_contact_clauses(user: Any) -> list:
    """Return Mongo match clauses for the phone and/or email of ``user``.

    Matches even if the client tapped 'Verify later' during sign-up so their
    Lead or Customer links immediately upon signing in.
    """
    import re
    clauses = []
    phone = str(_user_attr(user, "phone") or "").strip()
    if phone:
        clauses.append({"phone": phone})
        clauses.append({"mobile": phone})
    email = str(_user_attr(user, "email") or "").strip().lower()
    if email:
        clauses.append({"email": email})
        clauses.append({"email": {"$regex": f"^{re.escape(email)}$", "$options": "i"}})
    return clauses


def find_verified_client_for_contact(phone: Optional[str] = None, email: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """Find an already-registered client account whose phone or email matches."""
    import re
    conds = []
    if phone:
        clean_p = str(phone).strip()
        if clean_p:
            conds.append({"phone": clean_p})
    if email:
        clean_e = str(email).strip().lower()
        if clean_e:
            conds.append({
                "$or": [
                    {"email": clean_e},
                    {"email": {"$regex": f"^{re.escape(clean_e)}$", "$options": "i"}},
                ],
            })
    if not conds:
        return None
    return _db()["users"].find_one({
        "role": "client",
        "deleted_at": None,
        "$or": conds,
    })


def client_lead(user: Any) -> Optional[Dict[str, Any]]:
    """Return the active (unconverted) lead owned by a client user, linking it by verified phone or email if safe.

    Also links any converted lead (and its target customer) that matches the client's verified phone or email.
    """
    if role_of(user) not in CLIENT_ROLES:
        return None
    db = _db()
    uid = user_id(user)
    raw_id = str(_user_attr(user, "_id") or "")
    id_conds = [{"user_id": uid}]
    if raw_id and raw_id != uid:
        id_conds.append({"user_id": raw_id})

    contact_clauses = _verified_contact_clauses(user)
    unowned_clause = {"$or": [{"user_id": None}, {"user_id": {"$exists": False}}, {"user_id": ""}, *id_conds]}

    # Link any matching leads (active or converted) to this client's user_id.
    if contact_clauses:
        matching_leads = list(
            db["leads"].find({"$and": [{"$or": contact_clauses}, unowned_clause]}).sort("created_at", -1)
        )
        for ld in matching_leads:
            updates: Dict[str, Any] = {"user_id": uid}
            user_email = str(_user_attr(user, "email") or "").strip().lower()
            if user_email and not ld.get("email"):
                updates["email"] = user_email
            if ld.get("user_id") != uid or "email" in updates:
                db["leads"].update_one({"_id": ld["_id"]}, {"$set": updates})
                ld.update(updates)
            # If this lead was already converted into a customer, ensure the customer is linked too.
            if ld.get("status") == "converted" and ld.get("customer_id"):
                cid = str(ld["customer_id"])
                db["customers"].update_one(
                    {"$and": [{"$or": [{"_id": cid}, {"id": cid}]}, unowned_clause]},
                    {"$set": {"user_id": uid}},
                )

    # Return the latest unconverted lead linked to this client (preferring non-lost/non-closed).
    active_lead = db["leads"].find_one(
        {"$and": [{"$or": id_conds}, {"status": {"$nin": ["converted", "lost", "closed"]}}]},
        sort=[("created_at", -1)],
    )
    if active_lead:
        return active_lead
    return db["leads"].find_one(
        {"$and": [{"$or": id_conds}, {"status": {"$ne": "converted"}}]},
        sort=[("created_at", -1)],
    )


def client_customer(user: Any) -> Optional[Dict[str, Any]]:
    """Return the customer record owned by a client user, linking it if safe.

    A customer created by sales is matched to a client account by phone or email
    only after that account has *proven* ownership of that phone (``is_phone_verified``)
    or email (``is_email_verified``). Registering with someone else's unverified
    contact details therefore never exposes their project data.
    """
    if role_of(user) not in CLIENT_ROLES:
        return None
    db = _db()
    uid = user_id(user)
    raw_id = str(_user_attr(user, "_id") or "")
    id_conds = [{"user_id": uid}]
    if raw_id and raw_id != uid:
        id_conds.append({"user_id": raw_id})

    # Ensure any converted lead matching by phone/email also links its customer.
    lead = client_lead(user)

    from app.db.mongo import is_self_registered_project, merge_self_registered_projects
    linked_docs = list(db["customers"].find({"$or": id_conds}).sort("created_at", -1))
    real_linked = next((c for c in linked_docs if not is_self_registered_project(c)), None)
    if real_linked:
        return real_linked

    contact_clauses = _verified_contact_clauses(user)
    if contact_clauses:
        unowned_clause = {"$or": [{"user_id": None}, {"user_id": {"$exists": False}}, {"user_id": ""}, *id_conds]}
        candidates = list(
            db["customers"].find({"$and": [{"$or": contact_clauses}, unowned_clause]}).sort("created_at", -1)
        )
        real_candidate = next((c for c in candidates if not is_self_registered_project(c)), None)
        candidate = real_candidate or (candidates[0] if candidates else None)
        if candidate:
            updates: Dict[str, Any] = {"user_id": uid}
            user_email = str(_user_attr(user, "email") or "").strip().lower()
            if user_email and not candidate.get("email"):
                updates["email"] = user_email
            db["customers"].update_one({"_id": candidate["_id"]}, {"$set": updates})
            candidate.update(updates)
            if not is_self_registered_project(candidate):
                merge_self_registered_projects(candidate)
                return candidate
            if not lead:
                return candidate

    # If the user only has an untouched self-registered placeholder customer, but an
    # active staff-created Lead exists for them, return None here so the client stays
    # linked to their Lead until Sales converts it to a full Customer.
    if lead and linked_docs:
        return None
    return linked_docs[0] if linked_docs else None


def link_client_records(user: Any) -> None:
    """Eagerly link any matching lead and/or customer records for a newly verified client."""
    try:
        client_lead(user)
        client_customer(user)
    except Exception:
        pass


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


def can_access_lead(user: Any, lead: Dict[str, Any]) -> bool:
    role = role_of(user)
    uid = user_id(user)
    if role in MANAGER_ROLES:
        return True
    if role in SALES_ROLES:
        owner = str(lead.get("assigned_sales_id") or lead.get("sales_id") or "")
        return not owner or owner == uid
    if role in CLIENT_ROLES:
        own = client_lead(user)
        return bool(own) and str(own["_id"]) == str(lead["_id"])
    return False


def require_lead(user: Any, lead_id: str) -> Dict[str, Any]:
    lead = _by_id("leads", lead_id)
    if not lead or not can_access_lead(user, lead):
        raise NotFoundException("Lead not found.")
    return lead


def require_lead_write(user: Any, lead_id: str) -> Dict[str, Any]:
    lead = _by_id("leads", lead_id)
    if not lead:
        raise NotFoundException("Lead not found.")
    role = role_of(user)
    if role in ADMIN_ROLES:
        return lead
    if role in SALES_ROLES and can_access_lead(user, lead):
        return lead
    raise NotFoundException("Lead not found.")


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
