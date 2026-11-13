"""4-stage project lifecycle and the automatic hand-off between departments.

Single source of truth: ``customer.stage_status[STAGE] = {done, at, by, by_id}``.
Every event (stage toggle, site work completion, KEDL approval, customer
creation, employee assignment) goes through :func:`mark_stage` /
:func:`advance`, which re-derive ``customer.stage`` / ``progress`` and perform
hand-offs:

  Site-ops (1: installation) → KEDL (2-3) → Service / Handover (4)

Sales creates the customer and assigns the Site-ops and KEDL employees; it has
no stage of its own. Service picks up raised tickets.
"""
from datetime import datetime, timezone
import uuid
from typing import Any, Dict, Iterable, List, Optional
import structlog
from app.core import access
from app.core.constants import STAGE_ORDER

logger = structlog.get_logger()

STAGES: List[str] = [s.value for s, _ in STAGE_ORDER]
TITLES: Dict[str, str] = {s.value: t for s, t in STAGE_ORDER}

NOTES = {
    "INSTALLATION_COMPLETE": "Structure, electrical and civil work by the Site-ops team.",
    "KEDL_PROCESS": "Name change, load enhancement and net-metering files with the discom.",
    "SYSTEM_LIVE": "Net meter installed and system synced with the grid.",
    "HANDED_OVER": "Project handed over with warranty documents.",
}

SITE_SEQUENCE = ["structure", "electrical", "civil"]

# Which roles own which stages (admins may toggle any stage).
STAGE_OWNERS = {
    "INSTALLATION_COMPLETE": access.SITE_ROLES,
    "KEDL_PROCESS": access.KEDL_ROLES, "SYSTEM_LIVE": access.KEDL_ROLES,
    "HANDED_OVER": access.SERVICE_ROLES,
}
STAGE_OWNER_FIELD = {
    "INSTALLATION_COMPLETE": "site_employee_id",
    "KEDL_PROCESS": "kedl_employee_id", "SYSTEM_LIVE": "kedl_employee_id",
    "HANDED_OVER": "service_employee_id",
}

# Customer fields holding an assigned employee, and the department each must be in.
ASSIGNMENT_FIELDS = {
    "sales_id": ("sales", "sales_name", None),
    "site_employee_id": ("site", "site_employee_name", None),
    "kedl_employee_id": ("kedl", "kedl_employee_name", None),
    "service_employee_id": ("service", "service_employee_name", "service_employee_no"),
}


def _db():
    from app.db.mongo import get_mongo_db
    return get_mongo_db()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(v: Any) -> Optional[str]:
    return v.isoformat() if isinstance(v, datetime) else v


def _status_map(cust: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    return dict(cust.get("stage_status") or {})


def is_done(cust: Dict[str, Any], stage: str) -> bool:
    return bool(_status_map(cust).get(stage, {}).get("done"))


def build_timeline(cust: Dict[str, Any]) -> Dict[str, Any]:
    statuses = _status_map(cust)
    stages = []
    current_found = False
    done_count = 0
    for key in STAGES:
        entry = statuses.get(key) or {}
        if entry.get("done"):
            status = "done"
            done_count += 1
        elif not current_found:
            status = "current"
            current_found = True
        else:
            status = "upcoming"
        stages.append({
            "stage": key,
            "title": TITLES[key],
            "status": status,
            "done": status == "done",
            "date": _iso(entry.get("at")) if entry.get("done") else None,
            "by": entry.get("by") if entry.get("done") else None,
            "note": NOTES.get(key, ""),
        })
    return {
        "customer_id": str(cust.get("_id")),
        "stage": cust.get("stage"),
        "assigned_to": cust.get("assigned_to"),
        "assigned_role": cust.get("assigned_role"),
        "completed": done_count,
        "total": len(STAGES),
        "percentage": round(done_count * 100 / len(STAGES)),
        "stages": stages,
    }


def can_toggle_stage(user: Any, cust: Dict[str, Any], stage: str) -> bool:
    if access.is_admin(user):
        return True
    role = access.role_of(user)
    if role not in STAGE_OWNERS.get(stage, set()):
        return False
    owner_field = STAGE_OWNER_FIELD.get(stage)
    return owner_field is not None and str(cust.get(owner_field) or "") in ("", access.user_id(user))


def _notify(title: str, body: str, *, user_id: Optional[str] = None, role: Optional[str] = None, target: Optional[str] = None) -> None:
    try:
        from app.db.mongo import mongo_create_notification
        mongo_create_notification({"title": title, "body": body, "type": "workflow",
                                   "user_id": user_id, "target_role": None if user_id else role, "target_id": target})
    except Exception as e:  # notifications must never break the workflow
        logger.warning("workflow_notify_failed", error=str(e))


def mark_stage(customer_id: str, stage: str, done: bool, actor: Any = None, *, cascade: bool = True) -> None:
    """Set one stage Done/Incomplete, then recompute stage, progress and hand-offs."""
    if stage not in STAGES:
        return
    db = _db()
    if db is None:
        return
    now = _now()
    entry = {"done": bool(done), "at": now,
             "by": getattr(actor, "name", None) if actor else "System",
             "by_id": access.user_id(actor) if actor else None}
    db["customers"].update_one({"_id": customer_id}, {"$set": {f"stage_status.{stage}": entry, "updated_at": now}})
    if cascade:
        advance(customer_id)


def advance(customer_id: str) -> None:
    db = _db()
    cust = db["customers"].find_one({"_id": customer_id}) if db is not None else None
    if not cust:
        return
    timeline = build_timeline(cust)
    current = next((s["stage"] for s in timeline["stages"] if s["status"] == "current"), "HANDED_OVER")
    updates: Dict[str, Any] = {
        "stage": current,
        "progress": timeline["percentage"],
        "is_system_live": is_done(cust, "SYSTEM_LIVE"),
        "is_handed_over": is_done(cust, "HANDED_OVER"),
    }
    cid = str(cust["_id"])
    name = cust.get("name", "Customer")

    # ── Hand-offs ──────────────────────────────────────────────────────────
    if is_done(cust, "SYSTEM_LIVE"):
        handoff = ("service", cust.get("service_employee_id"))
    elif is_done(cust, "INSTALLATION_COMPLETE"):
        handoff = ("kedl", cust.get("kedl_employee_id"))
    else:
        handoff = ("site", cust.get("site_employee_id"))
    role, emp_id = handoff
    if cust.get("assigned_role") != role:
        updates["assigned_role"] = role
        updates["assigned_to"] = emp_id
        label = {"site": "Site-ops", "kedl": "KEDL", "service": "Service"}[role]
        _notify(
            f"{name}: now with {label}",
            f"{name}'s project moved to the {label} stage.",
            user_id=emp_id, role="admin" if not emp_id else None, target=cid,
        )
        if role == "site":
            _activate_site_work(db, cust)
        elif role == "kedl":
            _init_kedl_files(db, cust)
    db["customers"].update_one({"_id": cust["_id"]}, {"$set": updates})


def _activate_site_work(db, cust: Dict[str, Any]) -> None:
    """Create the structure → electrical → civil tasks for the Site-ops team."""
    cid = str(cust["_id"])
    now = _now()
    for wt in SITE_SEQUENCE:
        if db["work_assignments"].find_one({"customer_id": cid, "work_type": wt}):
            continue
        aid = str(uuid.uuid4())
        emp_id = cust.get("site_employee_id")
        db["work_assignments"].insert_one({
            "_id": aid, "id": aid, "customer_id": cid, "customer_name": cust.get("name", ""),
            "location": cust.get("address", ""), "work_type": wt, "team_name": "",
            "assigned_to": emp_id, "assigned_employee_id": emp_id,
            "assigned_employee_name": cust.get("site_employee_name"), "assigned_staff": cust.get("site_employee_name"),
            "status": "assigned" if wt == "structure" else "pending",
            "start_date": now.strftime("%Y-%m-%d"), "end_date": now.strftime("%Y-%m-%d"),
            "notes": "", "photos": [], "created_at": now, "updated_at": now,
        })


def _init_kedl_files(db, cust: Dict[str, Any]) -> None:
    cid = str(cust["_id"])
    now = _now()
    for ft in ("name_change", "load", "net"):
        if db["kedl_files"].find_one({"customer_id": cid, "file_type": ft}):
            continue
        fid = str(uuid.uuid4())
        db["kedl_files"].insert_one({
            "_id": fid, "id": fid, "customer_id": cid, "customer_name": cust.get("name", ""),
            "location": cust.get("address", ""), "file_type": ft, "status": "not_started",
            "demand_amount": 0, "assigned_to": cust.get("kedl_employee_id"),
            "documents": [], "created_at": now, "updated_at": now,
        })


# ── Event hooks ─────────────────────────────────────────────────────────────

def on_customer_created(customer_id: str) -> None:
    """A new project starts with Site-ops: create its installation tasks."""
    advance(customer_id)


def on_assignment_changed(customer_id: str, fields: Iterable[str], actor: Any = None) -> None:
    """Push a newly assigned Site-ops / KEDL employee onto the open work items."""
    db = _db()
    cust = db["customers"].find_one({"_id": customer_id}) if db is not None else None
    if not cust:
        return
    cid = str(cust["_id"])
    now = _now()
    fields = set(fields)
    if "site_employee_id" in fields:
        emp_id, emp_name = cust.get("site_employee_id"), cust.get("site_employee_name")
        db["work_assignments"].update_many(
            {"customer_id": cid, "work_type": {"$in": SITE_SEQUENCE}, "status": {"$nin": ["completed", "cancelled"]}},
            {"$set": {"assigned_to": emp_id, "assigned_employee_id": emp_id,
                      "assigned_employee_name": emp_name, "assigned_staff": emp_name, "updated_at": now}},
        )
    if "kedl_employee_id" in fields:
        db["kedl_files"].update_many(
            {"customer_id": cid, "status": {"$ne": "approved"}},
            {"$set": {"assigned_to": cust.get("kedl_employee_id"), "updated_at": now}},
        )
    role_field = {"site": "site_employee_id", "kedl": "kedl_employee_id", "service": "service_employee_id"}
    current_field = role_field.get(str(cust.get("assigned_role") or ""))
    if current_field and current_field in fields:
        db["customers"].update_one({"_id": cust["_id"]}, {"$set": {"assigned_to": cust.get(current_field)}})
    by = getattr(actor, "name", None) or "Admin"
    for field in fields:
        emp_id = cust.get(field)
        if emp_id and field in ("site_employee_id", "kedl_employee_id", "service_employee_id"):
            _notify("New project assigned to you",
                    f"{by} assigned you to {cust.get('name', 'a customer')}'s project.",
                    user_id=emp_id, target=cid)


def on_work_status(work: Dict[str, Any], actor: Any) -> None:
    """Site work completed/reopened → unlock the next task and sync the installation stage."""
    cid = str(work.get("customer_id") or "")
    wt = str(work.get("work_type") or "").lower()
    if not cid or wt not in SITE_SEQUENCE:
        return
    db = _db()
    done = work.get("status") == "completed"
    if done and wt != SITE_SEQUENCE[-1]:
        nxt = SITE_SEQUENCE[SITE_SEQUENCE.index(wt) + 1]
        db["work_assignments"].update_one(
            {"customer_id": cid, "work_type": nxt, "status": "pending"},
            {"$set": {"status": "assigned", "updated_at": _now()}},
        )
    works = {w.get("work_type"): w for w in db["work_assignments"].find({"customer_id": cid, "work_type": {"$in": SITE_SEQUENCE}})}
    all_done = all(works.get(t, {}).get("status") == "completed" for t in SITE_SEQUENCE)
    cust = db["customers"].find_one({"_id": cid}) or {}
    installed = is_done(cust, "INSTALLATION_COMPLETE")
    if all_done and not installed:
        mark_stage(cid, "INSTALLATION_COMPLETE", True, actor, cascade=False)
    elif not done and installed:
        # A task was reopened: the installation is no longer complete.
        mark_stage(cid, "INSTALLATION_COMPLETE", False, actor, cascade=False)
    advance(cid)


def on_kedl_file_status(kfile: Dict[str, Any], actor: Any) -> None:
    """Net-metering approval makes the system live (and reverting undoes it)."""
    cid = str(kfile.get("customer_id") or "")
    if not cid or kfile.get("file_type") != "net":
        return
    approved = kfile.get("status") == "approved"
    mark_stage(cid, "KEDL_PROCESS", approved, actor, cascade=False)
    mark_stage(cid, "SYSTEM_LIVE", approved, actor, cascade=False)
    _db()["customers"].update_one({"_id": cid}, {"$set": {"system_live_at": _now() if approved else None}})
    advance(cid)


def on_payment_verified(customer_id: str, actor: Any) -> None:
    """Payments no longer gate the timeline; keep derived fields fresh."""
    advance(customer_id)


def migrate_legacy_customers() -> int:
    """One-time upgrade of projects created under the old 10-stage flow.

    Old stage keys (sales / structure / electrical / civil) are dropped from the
    timeline; projects still waiting on sales are handed to Site-ops so their
    installation tasks exist. Idempotent: only touches unmigrated records.
    """
    db = _db()
    if db is None:
        return 0
    count = 0
    for cust in db["customers"].find({"workflow_version": {"$ne": 2}}, {"_id": 1}):
        try:
            advance(cust["_id"])
            db["customers"].update_one({"_id": cust["_id"]}, {"$set": {"workflow_version": 2}})
            count += 1
        except Exception as e:
            logger.warning("legacy_customer_migration_failed", customer_id=str(cust["_id"]), error=str(e))
    return count
