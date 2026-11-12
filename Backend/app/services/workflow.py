"""10-stage project lifecycle and the automatic 4-employee hand-off.

Single source of truth: ``customer.stage_status[STAGE] = {done, at, by, by_id}``.
Every event (stage toggle, site work completion, KEDL approval, payment
verification, lead conversion) goes through :func:`mark_stage`, which then
re-derives ``customer.stage`` / ``progress`` and performs hand-offs:

  Sales (1-3) → Site (4-7) → KEDL (8-9) → Service / Handover (10)
"""
from datetime import datetime, timezone
import uuid
from typing import Any, Dict, List, Optional
import structlog
from app.core import access
from app.core.constants import STAGE_ORDER

logger = structlog.get_logger()

STAGES: List[str] = [s.value for s, _ in STAGE_ORDER]
TITLES: Dict[str, str] = {s.value: t for s, t in STAGE_ORDER}

NOTES = {
    "SALE_CONFIRMED": "Sales agreement signed.",
    "DOCUMENTS_RECEIVED": "E-bill, Aadhaar, PAN, cancelled cheque and registry collected.",
    "ADVANCE_VERIFIED": "Advance payment approved by sales and verified by admin.",
    "STRUCTURE_WORK": "Mounting structure installation.",
    "ELECTRICAL_WORK": "DC/AC cabling, inverter and earthing.",
    "CIVIL_WORK": "Grouting and rooftop water-proofing.",
    "INSTALLATION_COMPLETE": "Panels and inverter installed and tested.",
    "KEDL_PROCESS": "Name change, load enhancement and net-metering files with the discom.",
    "SYSTEM_LIVE": "Net meter installed and system synced with the grid.",
    "HANDED_OVER": "Project handed over with warranty documents.",
}

WORK_STAGE = {"structure": "STRUCTURE_WORK", "electrical": "ELECTRICAL_WORK", "civil": "CIVIL_WORK"}
SITE_SEQUENCE = ["structure", "electrical", "civil"]

# Which roles own which stages (admins may toggle any stage).
STAGE_OWNERS = {
    "SALE_CONFIRMED": access.SALES_ROLES, "DOCUMENTS_RECEIVED": access.SALES_ROLES,
    "ADVANCE_VERIFIED": set(),  # set only by admin payment verification
    "STRUCTURE_WORK": access.SITE_ROLES, "ELECTRICAL_WORK": access.SITE_ROLES,
    "CIVIL_WORK": access.SITE_ROLES, "INSTALLATION_COMPLETE": access.SITE_ROLES,
    "KEDL_PROCESS": access.KEDL_ROLES, "SYSTEM_LIVE": access.KEDL_ROLES,
    "HANDED_OVER": access.SERVICE_ROLES,
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
    uid = access.user_id(user)
    owner_field = {
        "SALE_CONFIRMED": "sales_id", "DOCUMENTS_RECEIVED": "sales_id",
        "STRUCTURE_WORK": "site_employee_id", "ELECTRICAL_WORK": "site_employee_id",
        "CIVIL_WORK": "site_employee_id", "INSTALLATION_COMPLETE": "site_employee_id",
        "KEDL_PROCESS": "kedl_employee_id", "SYSTEM_LIVE": "kedl_employee_id",
        "HANDED_OVER": "service_employee_id",
    }.get(stage)
    return owner_field is not None and str(cust.get(owner_field) or "") in ("", uid)


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
    sales_done = all(is_done(cust, s) for s in ("SALE_CONFIRMED", "DOCUMENTS_RECEIVED", "ADVANCE_VERIFIED"))
    site_done = is_done(cust, "INSTALLATION_COMPLETE")
    kedl_done = is_done(cust, "SYSTEM_LIVE")

    if kedl_done:
        handoff = ("service", cust.get("service_employee_id"))
    elif site_done:
        handoff = ("kedl", cust.get("kedl_employee_id"))
    elif sales_done:
        handoff = ("site", cust.get("site_employee_id"))
    else:
        handoff = ("sales", cust.get("sales_id"))
    role, emp_id = handoff
    if cust.get("assigned_role") != role:
        updates["assigned_role"] = role
        updates["assigned_to"] = emp_id
        _notify(
            f"{name}: now with {role.upper() if role == 'kedl' else role.capitalize()}",
            f"{name}'s project moved to the {role} stage.",
            user_id=emp_id, role="admin" if not emp_id else None, target=cid,
        )
        if role == "site":
            _activate_site_work(db, cust)
        elif role == "kedl":
            _init_kedl_files(db, cust)
    db["customers"].update_one({"_id": cust["_id"]}, {"$set": updates})


def _activate_site_work(db, cust: Dict[str, Any]) -> None:
    """Create the structure → electrical → civil work items once sales hands off."""
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

def on_work_status(work: Dict[str, Any], actor: Any) -> None:
    """Site work completed/reopened → sync stages and unlock the next trade."""
    cid = str(work.get("customer_id") or "")
    wt = str(work.get("work_type") or "").lower()
    stage = WORK_STAGE.get(wt)
    if not cid or not stage:
        return
    done = work.get("status") == "completed"
    mark_stage(cid, stage, done, actor, cascade=False)
    db = _db()
    if wt == "civil":
        mark_stage(cid, "INSTALLATION_COMPLETE", done, actor, cascade=False)
    if done and wt in SITE_SEQUENCE[:-1]:
        nxt = SITE_SEQUENCE[SITE_SEQUENCE.index(wt) + 1]
        db["work_assignments"].update_one(
            {"customer_id": cid, "work_type": nxt, "status": "pending"},
            {"$set": {"status": "assigned", "updated_at": _now()}},
        )
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
    mark_stage(customer_id, "ADVANCE_VERIFIED", True, actor)
