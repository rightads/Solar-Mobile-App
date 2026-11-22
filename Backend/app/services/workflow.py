"""8-stage project lifecycle and the automatic hand-off between departments.

Single source of truth: ``customer.stage_status[STAGE] = {done, at, by, by_id}``.
Every event (stage toggle, KYC upload, site work completion, discom file
approval, customer creation, employee assignment) goes through
:func:`mark_stage` / :func:`advance`, which re-derive ``customer.stage`` /
``progress`` and perform hand-offs:

  Sales (1: documents) → Discom (2: name change & other changes)
  → Structure (3) → Wiring (4) → Civil (5) → Subsidy (6)
  → Discom (7: net metering) → Account / Bill (8)

The current stage is the first one not Done; the project is handed to that
stage's department and its assigned employee (``customer.<dept>_employee_id``).
Stage 1 can only be completed once the client has approved a quotation.
"""
from datetime import datetime, timezone
import uuid
from typing import Any, Dict, Iterable, List, Optional
import structlog
from app.core import access
from app.core.constants import STAGE_FLOW

logger = structlog.get_logger()

WORKFLOW_VERSION = 3

STAGES: List[str] = [s.value for s, _, _, _ in STAGE_FLOW]
TITLES: Dict[str, str] = {s.value: t for s, t, _, _ in STAGE_FLOW}
STAGE_DEPARTMENT: Dict[str, str] = {s.value: d for s, _, d, _ in STAGE_FLOW}
STAGE_OWNER_FIELD: Dict[str, str] = {s.value: f for s, _, _, f in STAGE_FLOW}
LAST_STAGE = STAGES[-1]

NOTES = {
    "DOCUMENTS_COLLECTION": "E-bill, Aadhaar, PAN, cancelled cheque and registry collected by the salesman.",
    "DISCOM_NAME_CHANGE": "Name change, load enhancement and other changes with the electricity board.",
    "STRUCTURE_WORK": "Mounting structure installed on the roof.",
    "WIRING_WORK": "AC / DC wiring, earthing and protection connected.",
    "CIVIL_WORK": "Civil work (foundations, pedestals, trenches) finished.",
    "SUBSIDY_WORK": "Government subsidy application filed and tracked.",
    "DISCOM_NET_METERING": "Net meter installed and system synced with the grid.",
    "ACCOUNT_BILL": "Final account settled and bill issued.",
}

# Site work rows (work_assignments.work_type) and the stage each one completes.
# Wiring is stored as "electrical" (the site app's existing work type).
SITE_SEQUENCE = ["structure", "electrical", "civil"]
WORK_TYPE_STAGE = {"structure": "STRUCTURE_WORK", "electrical": "WIRING_WORK", "civil": "CIVIL_WORK"}
STAGE_WORK_TYPE = {v: k for k, v in WORK_TYPE_STAGE.items()}

# Discom files (kedl_files.file_type) and the stage they belong to.
DISCOM_FILES = {"DISCOM_NAME_CHANGE": ("name_change", "load"), "DISCOM_NET_METERING": ("net",)}
FILE_DONE = {"approved", "not_required"}

# Which roles may toggle which stages (admins may toggle any stage).
_DEPARTMENT_ROLES = {
    "sales": access.SALES_ROLES, "discom": access.KEDL_ROLES,
    "structure": access.SITE_ROLES, "wiring": access.SITE_ROLES, "civil": access.SITE_ROLES,
    "subsidy": access.SUBSIDY_ROLES, "account": access.ACCOUNT_ROLES,
}
STAGE_OWNERS = {stage: _DEPARTMENT_ROLES[dept] for stage, dept in STAGE_DEPARTMENT.items()}

# Customer fields holding an assigned employee:
#   field -> (department, name field, employee-number field)
ASSIGNMENT_FIELDS = {
    "sales_id": ("sales", "sales_name", None),
    "discom_employee_id": ("discom", "discom_employee_name", "discom_employee_no"),
    "structure_employee_id": ("structure", "structure_employee_name", "structure_employee_no"),
    "wiring_employee_id": ("wiring", "wiring_employee_name", "wiring_employee_no"),
    "civil_employee_id": ("civil", "civil_employee_name", "civil_employee_no"),
    "subsidy_employee_id": ("subsidy", "subsidy_employee_name", "subsidy_employee_no"),
    "account_employee_id": ("account", "account_employee_name", "account_employee_no"),
}
DEPARTMENT_ASSIGNMENT_FIELD = {dept: field for field, (dept, _, _) in ASSIGNMENT_FIELDS.items()}


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


def quotation_approved(cust: Dict[str, Any]) -> bool:
    """Projects from before quotations existed are exempt (``quotation_waived``)."""
    return bool(cust.get("approved_quotation_id") or cust.get("quotation_waived"))


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
        dept = STAGE_DEPARTMENT[key]
        field = STAGE_OWNER_FIELD[key]
        stages.append({
            "stage": key,
            "title": TITLES[key],
            "department": dept,
            "department_label": access.DEPARTMENT_LABELS.get(dept, dept.title()),
            "assigned_to": cust.get(field),
            "assigned_name": cust.get(ASSIGNMENT_FIELDS[field][1]) if field in ASSIGNMENT_FIELDS else None,
            "status": status,
            "done": status == "done",
            "date": _iso(entry.get("at")) if entry.get("done") else None,
            "by": entry.get("by") if entry.get("done") else None,
            "remark": entry.get("remark"),
            "note": NOTES.get(key, ""),
        })
    return {
        "customer_id": str(cust.get("_id")),
        "stage": cust.get("stage"),
        "assigned_to": cust.get("assigned_to"),
        "assigned_role": cust.get("assigned_role"),
        "quotation_approved": quotation_approved(cust),
        "completed": done_count,
        "total": len(STAGES),
        "percentage": round(done_count * 100 / len(STAGES)),
        "stages": stages,
    }


def can_toggle_stage(user: Any, cust: Dict[str, Any], stage: str) -> bool:
    if stage not in STAGES:
        return False
    if access.is_admin(user):
        return True
    role = access.role_of(user)
    if role not in STAGE_OWNERS.get(stage, set()):
        return False
    owner = str(cust.get(STAGE_OWNER_FIELD[stage]) or "")
    return owner in ("", access.user_id(user))


def stage_block_reason(cust: Dict[str, Any], stage: str, done: bool) -> Optional[str]:
    """Why a stage may not be marked Done right now (None when allowed)."""
    if done and stage == STAGES[0] and not quotation_approved(cust):
        return "The client must approve a quotation before documents collection can be completed."
    return None


def _notify(title: str, body: str, *, user_id: Optional[str] = None, role: Optional[str] = None, target: Optional[str] = None) -> None:
    try:
        from app.db.mongo import mongo_create_notification
        mongo_create_notification({"title": title, "body": body, "type": "workflow",
                                   "user_id": user_id, "target_role": None if user_id else role, "target_id": target})
    except Exception as e:  # notifications must never break the workflow
        logger.warning("workflow_notify_failed", error=str(e))


def mark_stage(customer_id: str, stage: str, done: bool, actor: Any = None, *,
               cascade: bool = True, remark: Optional[str] = None) -> None:
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
    if remark:
        entry["remark"] = remark
    db["customers"].update_one({"_id": customer_id}, {"$set": {f"stage_status.{stage}": entry, "updated_at": now}})
    if cascade:
        advance(customer_id)


def current_stage(cust: Dict[str, Any]) -> Optional[str]:
    """First stage not Done, or None when the whole project is complete."""
    return next((s for s in STAGES if not is_done(cust, s)), None)


def advance(customer_id: str) -> None:
    db = _db()
    cust = db["customers"].find_one({"_id": customer_id}) if db is not None else None
    if not cust:
        return
    timeline = build_timeline(cust)
    current = current_stage(cust)
    updates: Dict[str, Any] = {
        "stage": current or "COMPLETED",
        "progress": timeline["percentage"],
        "workflow_version": WORKFLOW_VERSION,
        "is_system_live": is_done(cust, "DISCOM_NET_METERING"),
        "is_completed": current is None,
    }
    cid = str(cust["_id"])
    name = cust.get("name", "Customer")

    # ── Hand-off to the department that owns the current stage ─────────────
    role = STAGE_DEPARTMENT[current] if current else None
    emp_id = cust.get(STAGE_OWNER_FIELD[current]) if current else None
    if cust.get("assigned_role") != role or cust.get("assigned_stage") != current:
        updates["assigned_role"] = role
        updates["assigned_stage"] = current
        updates["assigned_to"] = emp_id
        if current:
            label = access.DEPARTMENT_LABELS.get(role, role)
            _notify(
                f"{name}: now with {label}",
                f"{name}'s project moved to {TITLES[current]}.",
                user_id=emp_id, role="admin" if not emp_id else None, target=cid,
            )
            _start_stage_work(db, cust, current)
        else:
            _notify(f"{name}: project complete", f"All stages of {name}'s project are done.", role="admin", target=cid)
    else:
        updates["assigned_to"] = emp_id
    db["customers"].update_one({"_id": cust["_id"]}, {"$set": updates})


def _start_stage_work(db, cust: Dict[str, Any], stage: str) -> None:
    """Create the work items a department needs when a stage becomes current."""
    if stage in STAGE_WORK_TYPE:
        _ensure_site_work(db, cust, STAGE_WORK_TYPE[stage])
    elif stage in DISCOM_FILES:
        _ensure_discom_files(db, cust, DISCOM_FILES[stage])


# ── Site work (structure / wiring / civil) ──────────────────────────────────

_WORK_RANK = {"completed": 4, "in_progress": 3, "active": 3, "assigned": 2, "pending": 1}

# Mongo filter for site work rows that are real (not cancelled / merged duplicates).
LIVE_WORK = {"status": {"$ne": "cancelled"}, "duplicate_of": {"$exists": False}}


def _work_rank(w: Dict[str, Any]) -> tuple:
    return (_WORK_RANK.get(str(w.get("status") or ""), 0), len(w.get("photos") or []))


def site_work_by_type(rows: Iterable[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    """One row per site trade: the furthest-along live row (earliest wins ties).

    A project can carry several rows for the same trade (manual re-assignment,
    legacy data); picking an arbitrary one hides completed work.
    """
    best: Dict[str, Dict[str, Any]] = {}
    for w in rows:
        wt = str(w.get("work_type") or "").lower()
        if wt not in SITE_SEQUENCE or w.get("status") == "cancelled" or w.get("duplicate_of"):
            continue
        if wt not in best or _work_rank(w) > _work_rank(best[wt]):
            best[wt] = w
    return best


def _site_works(db, cid: str) -> Dict[str, Dict[str, Any]]:
    rows = db["work_assignments"].find({"customer_id": cid, "work_type": {"$in": SITE_SEQUENCE}}).sort("created_at", 1)
    return site_work_by_type(rows)


def _work_employee(cust: Dict[str, Any], work_type: str) -> tuple:
    field = DEPARTMENT_ASSIGNMENT_FIELD[STAGE_DEPARTMENT[WORK_TYPE_STAGE[work_type]]]
    return cust.get(field), cust.get(ASSIGNMENT_FIELDS[field][1])


def _ensure_site_work(db, cust: Dict[str, Any], work_type: str) -> None:
    """Create (or re-open for assignment) the site task for one trade."""
    cid = str(cust["_id"])
    now = _now()
    emp_id, emp_name = _work_employee(cust, work_type)
    aid = str(uuid.uuid4())
    # Upsert so concurrent hand-offs can't create the same task twice.
    db["work_assignments"].update_one({"customer_id": cid, "work_type": work_type, **LIVE_WORK}, {"$setOnInsert": {
        "_id": aid, "id": aid, "customer_id": cid, "work_type": work_type, "customer_name": cust.get("name", ""),
        "location": cust.get("address", ""), "team_name": "",
        "assigned_to": emp_id, "assigned_employee_id": emp_id,
        "assigned_employee_name": emp_name, "assigned_staff": emp_name,
        "status": "assigned",
        "start_date": now.strftime("%Y-%m-%d"), "end_date": now.strftime("%Y-%m-%d"),
        "notes": "", "photos": [], "created_at": now, "updated_at": now,
    }}, upsert=True)
    # A task created earlier as "pending" becomes active now that its stage is current.
    db["work_assignments"].update_many(
        {"customer_id": cid, "work_type": work_type, "status": "pending"},
        {"$set": {"status": "assigned", "updated_at": now}},
    )


def _ensure_discom_files(db, cust: Dict[str, Any], file_types: Iterable[str]) -> None:
    cid = str(cust["_id"])
    now = _now()
    for ft in file_types:
        if db["kedl_files"].find_one({"customer_id": cid, "file_type": ft}):
            continue
        fid = str(uuid.uuid4())
        db["kedl_files"].insert_one({
            "_id": fid, "id": fid, "customer_id": cid, "customer_name": cust.get("name", ""),
            "location": cust.get("address", ""), "file_type": ft, "status": "not_started",
            "demand_amount": 0, "assigned_to": cust.get("discom_employee_id") or cust.get("kedl_employee_id"),
            "documents": [], "status_log": [], "created_at": now, "updated_at": now,
        })


# ── Event hooks ─────────────────────────────────────────────────────────────

def on_customer_created(customer_id: str) -> None:
    """A new project starts with the salesman collecting documents."""
    db = _db()
    if db is not None:
        db["customers"].update_one({"_id": customer_id}, {"$set": {"workflow_version": WORKFLOW_VERSION}})
    advance(customer_id)


def on_assignment_changed(customer_id: str, fields: Iterable[str], actor: Any = None) -> None:
    """Push a newly assigned employee onto that department's open work items."""
    db = _db()
    cust = db["customers"].find_one({"_id": customer_id}) if db is not None else None
    if not cust:
        return
    cid = str(cust["_id"])
    now = _now()
    fields = set(fields)
    for wt in SITE_SEQUENCE:
        field = DEPARTMENT_ASSIGNMENT_FIELD[STAGE_DEPARTMENT[WORK_TYPE_STAGE[wt]]]
        if field in fields:
            emp_id, emp_name = cust.get(field), cust.get(ASSIGNMENT_FIELDS[field][1])
            db["work_assignments"].update_many(
                {"customer_id": cid, "work_type": wt, "status": {"$nin": ["completed", "cancelled"]}},
                {"$set": {"assigned_to": emp_id, "assigned_employee_id": emp_id,
                          "assigned_employee_name": emp_name, "assigned_staff": emp_name, "updated_at": now}},
            )
    if "discom_employee_id" in fields:
        db["kedl_files"].update_many(
            {"customer_id": cid, "status": {"$nin": list(FILE_DONE)}},
            {"$set": {"assigned_to": cust.get("discom_employee_id"), "updated_at": now}},
        )
    stage = cust.get("assigned_stage") or current_stage(cust)
    if stage and STAGE_OWNER_FIELD.get(stage) in fields:
        db["customers"].update_one({"_id": cust["_id"]}, {"$set": {"assigned_to": cust.get(STAGE_OWNER_FIELD[stage])}})
    by = getattr(actor, "name", None) or "Admin"
    for field in fields:
        emp_id = cust.get(field)
        if emp_id and field in ASSIGNMENT_FIELDS and field != "sales_id":
            _notify("New project assigned to you",
                    f"{by} assigned you to {cust.get('name', 'a customer')}'s project.",
                    user_id=emp_id, target=cid)


def on_documents_changed(customer_id: str, actor: Any) -> None:
    """All 5 KYC documents uploaded (and quotation approved) completes stage 1."""
    db = _db()
    cust = db["customers"].find_one({"_id": customer_id}) if db is not None else None
    if not cust:
        return
    complete = bool(cust.get("documents_verified"))
    stage = STAGES[0]
    if complete and not is_done(cust, stage) and quotation_approved(cust):
        mark_stage(customer_id, stage, True, actor)
    elif not complete and is_done(cust, stage):
        mark_stage(customer_id, stage, False, actor)


def on_quotation_approved(customer_id: str) -> None:
    """Approval may unblock stage 1 if the documents are already in."""
    on_documents_changed(customer_id, None)
    advance(customer_id)


def on_work_status(work: Dict[str, Any], actor: Any) -> None:
    """Site work completed / reopened → that trade's stage Done / Incomplete."""
    cid = str(work.get("customer_id") or "")
    wt = str(work.get("work_type") or "").lower()
    if not cid or wt not in SITE_SEQUENCE:
        return
    db = _db()
    stage = WORK_TYPE_STAGE[wt]
    done = _site_works(db, cid).get(wt, {}).get("status") == "completed"
    cust = db["customers"].find_one({"_id": cid}) or {}
    if done != is_done(cust, stage):
        mark_stage(cid, stage, done, actor, cascade=False)
    advance(cid)


def sync_work_from_stage(customer_id: str, stage: str, done: bool) -> None:
    """A site stage toggled on the timeline: keep its work row in step."""
    wt = STAGE_WORK_TYPE.get(stage)
    if not wt:
        return
    db = _db()
    now = _now()
    if done:
        db["work_assignments"].update_many(
            {"customer_id": customer_id, "work_type": wt, **LIVE_WORK, "status": {"$ne": "completed"}},
            {"$set": {"status": "completed", "completed_at": now, "updated_at": now}},
        )
    else:
        db["work_assignments"].update_many(
            {"customer_id": customer_id, "work_type": wt, "status": "completed"},
            {"$set": {"status": "in_progress", "completed_at": None, "updated_at": now}},
        )


def on_kedl_file_status(kfile: Dict[str, Any], actor: Any) -> None:
    """Discom files approved (or not required) complete their stage; reverting undoes it."""
    cid = str(kfile.get("customer_id") or "")
    ft = kfile.get("file_type")
    stage = next((s for s, types in DISCOM_FILES.items() if ft in types), None)
    if not cid or not stage:
        return
    db = _db()
    files = {f.get("file_type"): f for f in db["kedl_files"].find({"customer_id": cid})}
    done = all(str((files.get(t) or {}).get("status")) in FILE_DONE for t in DISCOM_FILES[stage])
    cust = db["customers"].find_one({"_id": cid}) or {}
    if done != is_done(cust, stage):
        mark_stage(cid, stage, done, actor, cascade=False)
    if stage == "DISCOM_NET_METERING":
        db["customers"].update_one({"_id": cid}, {"$set": {"system_live_at": _now() if done else None}})
    advance(cid)


def on_payment_verified(customer_id: str, actor: Any) -> None:
    """Payments do not gate the timeline; keep derived fields fresh."""
    advance(customer_id)


def dedupe_site_work() -> Dict[str, int]:
    """Collapse duplicate site-work rows and re-sync site stages.

    For each customer + trade with several live rows, the furthest-along row is
    kept; the rest are marked ``cancelled`` with ``duplicate_of`` (not deleted),
    and their photos are moved onto the kept row. Then each completed trade gets
    its stage marked Done. Idempotent.
    """
    from collections import defaultdict
    db = _db()
    if db is None:
        return {"duplicates": 0, "installed": 0}
    now = _now()
    groups: Dict[tuple, List[Dict[str, Any]]] = defaultdict(list)
    query = {"work_type": {"$in": SITE_SEQUENCE}, **LIVE_WORK}
    for w in db["work_assignments"].find(query).sort("created_at", 1):
        cid = str(w.get("customer_id") or "")
        if cid:
            groups[(cid, w["work_type"])].append(w)

    duplicates = 0
    for (cid, wt), rows in groups.items():
        if len(rows) < 2:
            continue
        keep = site_work_by_type(rows)[wt]
        dups = [r for r in rows if r["_id"] != keep["_id"]]
        seen = {p.get("id") for p in keep.get("photos") or []}
        moved = []
        for r in dups:
            for p in r.get("photos") or []:
                if p.get("id") not in seen:
                    seen.add(p.get("id"))
                    moved.append({**p, "work_assignment_id": str(keep["_id"])})
        keep_update: Dict[str, Any] = {"$set": {"updated_at": now}}
        if moved:
            # $addToSet: safe if several gunicorn workers run this at startup.
            keep_update["$addToSet"] = {"photos": {"$each": moved}}
        if not keep.get("assigned_to"):
            owner = next((r for r in dups if r.get("assigned_to")), None)
            if owner:
                for f in ("assigned_to", "assigned_employee_id", "assigned_employee_name",
                          "assigned_employee_no", "assigned_staff"):
                    if owner.get(f):
                        keep_update["$set"][f] = owner[f]
        db["work_assignments"].update_one({"_id": keep["_id"]}, keep_update)
        db["work_assignments"].update_many(
            {"_id": {"$in": [r["_id"] for r in dups]}},
            {"$set": {"status": "cancelled", "duplicate_of": str(keep["_id"]), "updated_at": now}},
        )
        duplicates += len(dups)
        logger.info("site_work_deduped", customer_id=cid, work_type=wt, kept=str(keep["_id"]), removed=len(dups))

    from app.db.mongo import is_self_registered_project
    installed = 0
    for cid in {cid for cid, _ in groups}:
        cust = db["customers"].find_one({"_id": cid})
        if not cust or is_self_registered_project(cust):
            continue  # sign-up placeholders have no workflow until sales takes them on
        works = _site_works(db, cid)
        changed = False
        for wt in SITE_SEQUENCE:
            stage = WORK_TYPE_STAGE[wt]
            if works.get(wt, {}).get("status") == "completed" and not is_done(cust, stage):
                mark_stage(cid, stage, True, None, cascade=False)
                changed = True
        if changed:
            advance(cid)
            installed += 1
    return {"duplicates": duplicates, "installed": installed}


# ── Migration from the 4-stage flow (workflow_version 2) ───────────────────

_LEGACY_FIELD_MAP = {
    "kedl_employee_id": ["discom_employee_id"],
    "site_employee_id": ["structure_employee_id", "wiring_employee_id", "civil_employee_id"],
}


def _legacy_done(cust: Dict[str, Any], stage: str) -> bool:
    return bool(_status_map(cust).get(stage, {}).get("done"))


def migrate_legacy_customers() -> int:
    """One-time upgrade of projects created before the 8-stage flow.

    * Their old site / KEDL employees carry over to the new department fields.
    * Progress carries over: completed site trades complete Structure / Wiring /
      Civil, an approved net-metering file completes both discom stages, and a
      handed-over project is fully done.
    * The old flow began after sales, so documents collection counts as done,
      and they never had quotations, so the quotation gate is waived for them.
    Idempotent: only touches records below WORKFLOW_VERSION.
    """
    db = _db()
    if db is None:
        return 0
    from app.db.mongo import is_self_registered_project
    count = 0
    query = {"$or": [{"workflow_version": {"$lt": WORKFLOW_VERSION}}, {"workflow_version": {"$exists": False}}]}
    for cust in db["customers"].find(query):
        cid = str(cust["_id"])
        try:
            sets: Dict[str, Any] = {}
            for old, new_fields in _LEGACY_FIELD_MAP.items():
                if cust.get(old):
                    old_name = cust.get(old.replace("_id", "_name"))
                    for nf in new_fields:
                        if not cust.get(nf):
                            sets[nf] = cust[old]
                            sets[ASSIGNMENT_FIELDS[nf][1]] = old_name
            if is_self_registered_project(cust):
                sets["workflow_version"] = WORKFLOW_VERSION
                db["customers"].update_one({"_id": cust["_id"]}, {"$set": sets})
                continue  # sign-up placeholder: no workflow until sales takes it on
            sets["quotation_waived"] = True
            now = _now()
            # The old flow began after sales, so these projects are past documents.
            done = {"DOCUMENTS_COLLECTION"}
            works = _site_works(db, cid)
            for wt in SITE_SEQUENCE:
                if works.get(wt, {}).get("status") == "completed" or _legacy_done(cust, "INSTALLATION_COMPLETE"):
                    done.add(WORK_TYPE_STAGE[wt])
            files = {f.get("file_type"): f for f in db["kedl_files"].find({"customer_id": cid})}
            if all(str((files.get(t) or {}).get("status")) in FILE_DONE for t in ("name_change", "load")) \
                    or _legacy_done(cust, "SYSTEM_LIVE"):
                done.add("DISCOM_NAME_CHANGE")
            if str((files.get("net") or {}).get("status")) in FILE_DONE or _legacy_done(cust, "SYSTEM_LIVE"):
                done |= {"DISCOM_NAME_CHANGE", "DISCOM_NET_METERING"}
            if _legacy_done(cust, "HANDED_OVER"):
                done |= set(STAGES)
            for stage in done:
                if not is_done(cust, stage):
                    sets[f"stage_status.{stage}"] = {"done": True, "at": now, "by": "Migration", "by_id": None}
            sets["assigned_stage"] = None  # force a fresh hand-off below
            db["customers"].update_one({"_id": cust["_id"]}, {"$set": sets})
            advance(cid)
            count += 1
        except Exception as e:
            logger.warning("legacy_customer_migration_failed", customer_id=cid, error=str(e))
    return count
