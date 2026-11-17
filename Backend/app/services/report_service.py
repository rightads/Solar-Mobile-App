"""Operations reports and Excel exports, computed from MongoDB.

Collections read: leads, customers, payments, work_assignments, kedl_files
(demands are embedded), tickets, inventory_items, users. Sign-up placeholders
(clients awaiting a survey) are not projects, so they are left out of sales
and billing figures.
"""
import io
from collections import Counter, defaultdict
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List

from app.core import access
from app.core.config import settings
from app.core.exceptions import BadRequestException
from app.db.mongo import get_mongo_db, is_self_registered_project
from app.schemas.report import (
    DashboardReportResponse,
    KedlReportResponse,
    PaymentsReportResponse,
    SalesRepPerformance,
    SalesReportResponse,
    TeamWorkMetrics,
    WorkReportResponse,
)

ACTIVE_WORK = ("assigned", "pending", "in_progress", "active")
OPEN_TICKETS = ("open", "assigned", "in_progress", "reopened")


def _db():
    db = get_mongo_db()
    if db is None:
        raise BadRequestException("Reports are temporarily unavailable. Please try again.")
    return db


def _aware(dt: Any) -> Any:
    if isinstance(dt, datetime) and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _projects(db) -> List[Dict[str, Any]]:
    return [c for c in db["customers"].find() if not is_self_registered_project(c)]


def _live_work(db) -> Iterable[Dict[str, Any]]:
    return db["work_assignments"].find({"status": {"$ne": "cancelled"}, "duplicate_of": {"$exists": False}})


def _paise(v: Any) -> int:
    try:
        return int(v or 0)
    except (TypeError, ValueError):
        return 0


class ReportService:
    @staticmethod
    def get_dashboard_report() -> DashboardReportResponse:
        db = _db()
        leads_by_status = Counter(str(lead.get("status") or "new") for lead in db["leads"].find({}, {"status": 1}))
        customers = list(db["customers"].find())
        customers_by_stage = Counter(
            "REGISTRATION_SUBMITTED" if is_self_registered_project(c) else str(c.get("stage") or "UNKNOWN")
            for c in customers
        )
        now = datetime.now(timezone.utc)
        month_start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
        sales_this_month = sum(
            _paise(c.get("final_price")) for c in customers
            if not is_self_registered_project(c)
            and isinstance(_aware(c.get("created_at")), datetime) and _aware(c["created_at"]) >= month_start
        )
        open_demands = sum(
            1 for f in db["kedl_files"].find({}, {"demands": 1})
            for d in f.get("demands") or [] if d.get("status") == "open"
        )
        low_stock = sum(
            1 for i in db["inventory_items"].find({"is_deleted": {"$ne": True}, "is_active": True})
            if _paise(i.get("stock_qty")) <= _paise(i.get("min_stock"))
        )
        return DashboardReportResponse(
            total_leads=sum(leads_by_status.values()),
            leads_by_status=dict(leads_by_status),
            total_customers=sum(customers_by_stage.values()),
            customers_by_stage=dict(customers_by_stage),
            sales_this_month_paise=sales_this_month,
            pending_payment_verifications_count=db["payments"].count_documents({"status": {"$in": ["pending", "sales_approved"]}}),
            active_works_count=sum(1 for w in _live_work(db) if w.get("status") in ACTIVE_WORK),
            open_kedl_demands_count=open_demands,
            open_service_tickets_count=db["tickets"].count_documents({"status": {"$in": list(OPEN_TICKETS)}}),
            low_stock_items_count=low_stock,
        )

    @staticmethod
    def get_sales_report() -> SalesReportResponse:
        db = _db()
        reps = [u for u in db["users"].find({"role": {"$in": sorted(access.SALES_ROLES)}})
                if not u.get("deleted_at")]
        leads = Counter(str(lead.get("assigned_sales_id") or "") for lead in db["leads"].find({}, {"assigned_sales_id": 1}))
        won: Dict[str, List[int]] = defaultdict(list)
        for c in _projects(db):
            won[str(c.get("sales_id") or "")].append(_paise(c.get("final_price")))
        rows = [
            SalesRepPerformance(
                sales_rep_id=str(r["_id"]), sales_rep_name=r.get("name") or "Sales",
                total_leads=leads.get(str(r["_id"]), 0),
                converted_customers=len(won.get(str(r["_id"]), [])),
                total_sales_paise=sum(won.get(str(r["_id"]), [])),
            )
            for r in reps
        ]
        rows.sort(key=lambda r: r.total_sales_paise, reverse=True)
        return SalesReportResponse(sales_reps=rows, total_sales_paise=sum(sum(v) for v in won.values()))

    @staticmethod
    def get_payments_report() -> PaymentsReportResponse:
        db = _db()
        billed = sum(_paise(c.get("final_price")) for c in _projects(db))
        collected = 0
        pending = 0
        by_mode: Counter = Counter()
        for p in db["payments"].find():
            amount = _paise(p.get("amount"))
            if p.get("status") == "verified":
                collected += amount
                by_mode[str(p.get("mode") or "OTHER").lower()] += amount
            elif p.get("status") in ("pending", "sales_approved"):
                pending += amount
        return PaymentsReportResponse(
            total_billed_paise=billed,
            total_collected_paise=collected,
            pending_verification_paise=pending,
            pending_advance_paise=max(0, int(billed * 0.2) - collected),
            pending_final_paise=max(0, billed - collected),
            payments_by_mode=dict(by_mode),
        )

    @staticmethod
    def get_work_report() -> WorkReportResponse:
        db = _db()
        groups: Dict[str, Dict[str, Any]] = {}
        for w in _live_work(db):
            key = str(w.get("assigned_to") or "")
            g = groups.setdefault(key, {
                "name": w.get("assigned_employee_name") or w.get("assigned_staff") or ("Unassigned" if not key else "Site employee"),
                "types": set(), "completed": 0, "in_progress": 0, "pending": 0,
            })
            g["types"].add(str(w.get("work_type") or "site"))
            status = w.get("status")
            if status == "completed":
                g["completed"] += 1
            elif status in ("in_progress", "active"):
                g["in_progress"] += 1
            elif status in ("assigned", "pending"):
                g["pending"] += 1
        teams = [
            TeamWorkMetrics(team_id=k or "unassigned", team_name=g["name"], team_type=", ".join(sorted(g["types"])),
                            completed_works=g["completed"], in_progress_works=g["in_progress"], pending_works=g["pending"])
            for k, g in groups.items()
        ]
        teams.sort(key=lambda t: (t.team_id == "unassigned", t.team_name.lower()))
        return WorkReportResponse(
            teams=teams,
            total_completed=sum(t.completed_works for t in teams),
            total_active=sum(t.in_progress_works + t.pending_works for t in teams),
        )

    @staticmethod
    def get_kedl_report() -> KedlReportResponse:
        db = _db()
        files = list(db["kedl_files"].find())
        open_amounts = [_paise(d.get("amount")) for f in files for d in f.get("demands") or [] if d.get("status") == "open"]
        paid = sum(_paise(d.get("amount")) for f in files for d in f.get("demands") or [] if d.get("status") == "paid")
        return KedlReportResponse(
            files_by_status=dict(Counter(str(f.get("status") or "not_started") for f in files)),
            open_demands_count=len(open_amounts),
            open_demands_total_paise=sum(open_amounts),
            paid_demands_total_paise=paid,
        )

    # ------------------ EXCEL EXPORTS ------------------
    @staticmethod
    def _workbook(title: str, headers: List[str], rows: Iterable[List[Any]]) -> io.BytesIO:
        import openpyxl
        from openpyxl.styles import Font, PatternFill

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = title
        ws.append(headers)
        color = settings.REPORT_HEADER_COLOR
        for col in range(1, len(headers) + 1):
            cell = ws.cell(row=1, column=col)
            cell.fill = PatternFill(start_color=color, end_color=color, fill_type="solid")
            cell.font = Font(color="FFFFFF", bold=True)
        for row in rows:
            # Spreadsheet formula injection guard: text starting with = + - @ is quoted.
            ws.append([("'" + v) if isinstance(v, str) and v[:1] in ("=", "+", "-", "@") else v for v in row])
        for col in ws.columns:
            width = max(len(str(c.value or "")) for c in col)
            ws.column_dimensions[col[0].column_letter].width = min(max(12, width + 2), 50)
        ws.freeze_panes = "A2"
        out = io.BytesIO()
        wb.save(out)
        out.seek(0)
        return out

    @staticmethod
    def _date(v: Any) -> str:
        v = _aware(v)
        if isinstance(v, datetime):
            return v.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M")
        return str(v or "")[:16].replace("T", " ")

    @staticmethod
    def export_customers_excel() -> io.BytesIO:
        db = _db()
        customers = sorted(_projects(db), key=lambda c: str(c.get("created_at") or ""), reverse=True)
        return ReportService._workbook("Customers", [
            "Customer ID", "Name", "Phone", "Address", "Capacity (kW)", "Phase", "Panel Brand", "Inverter Brand",
            "Current Stage", "Final Price (INR)", "Paid (INR)", "Sales Rep", "Created",
        ], ([
            str(c["_id"]), c.get("name") or "", c.get("phone") or "", c.get("address") or "",
            float(c.get("capacity_kw") or 0), c.get("phase") or "", c.get("panel_brand") or "",
            c.get("inverter_brand") or "", c.get("stage") or "", _paise(c.get("final_price")) / 100.0,
            _paise(c.get("paid_amount")) / 100.0, c.get("sales_name") or "", ReportService._date(c.get("created_at")),
        ] for c in customers))

    @staticmethod
    def export_payments_excel() -> io.BytesIO:
        db = _db()
        payments = sorted(db["payments"].find(), key=lambda p: str(p.get("created_at") or ""), reverse=True)
        return ReportService._workbook("Payments Ledger", [
            "Payment ID", "Customer", "Phone", "Amount (INR)", "Mode", "Status", "Reference No", "Paid On",
            "Approved By (Sales)", "Verified By", "Remarks",
        ], ([
            str(p["_id"]), p.get("customer_name") or "", p.get("client_phone") or "", _paise(p.get("amount")) / 100.0,
            str(p.get("mode") or "").upper(), p.get("status") or "", p.get("reference_no") or "",
            ReportService._date(p.get("paid_on")), p.get("sales_approved_by_name") or "",
            p.get("verified_by_name") or "", p.get("remarks") or "",
        ] for p in payments))

    @staticmethod
    def export_inventory_excel() -> io.BytesIO:
        db = _db()
        items = sorted(db["inventory_items"].find({"is_deleted": {"$ne": True}}), key=lambda i: str(i.get("name") or "").lower())
        in_stock = Counter(s["item_id"] for s in db["serial_items"].find({"status": "in_stock"}, {"item_id": 1}))
        return ReportService._workbook("Inventory", [
            "Item ID", "Name", "Category", "Brand", "Model", "Unit", "Serial Tracked", "In Stock", "Min Stock",
            "Status", "Serials In Stock",
        ], ([
            str(i["_id"]), i.get("name") or "", i.get("category") or "", i.get("brand") or "", i.get("model") or "",
            i.get("unit") or "", "Yes" if i.get("has_serial") else "No", _paise(i.get("stock_qty")),
            _paise(i.get("min_stock")),
            "LOW" if _paise(i.get("stock_qty")) <= _paise(i.get("min_stock")) else "OK",
            in_stock.get(str(i["_id"]), 0) if i.get("has_serial") else "",
        ] for i in items))
