"""End-to-end inventory suite: the real FastAPI app on mongomock.

Covers access control, serial-number rules, stock never going negative,
rollback of partially issued serials, warranty tracking, serial lookup by the
service team and the stock effect of serial status changes.
"""
import os
import sys
import tempfile
import uuid
from datetime import datetime, timezone

BACKEND = sys.argv[1]
os.chdir(BACKEND)
sys.path.insert(0, BACKEND)
os.environ.update({
    "ENV": "test", "DEBUG": "false", "JWT_SECRET": "t" * 48, "MONGODB_URI": "",
    "SUPER_ADMIN_EMAIL": "boss@solarpro.in", "SUPER_ADMIN_PHONE": "9000000001",
    "SUPER_ADMIN_PASSWORD": "BossPass123", "UPLOAD_DIR": tempfile.mkdtemp(), "CORS_ORIGINS": "[]",
})
import mongomock  # noqa: E402
import app.db.mongo as M  # noqa: E402
M._client = mongomock.MongoClient(tz_aware=True)
from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402
from app.core.security import hash_password  # noqa: E402

results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond)))
    print(("PASS " if cond else "FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))


client = TestClient(app, client=("10.0.0.1", 5000))
client.__enter__()
db = M.get_mongo_db()
now = datetime.now(timezone.utc)
API = "/api/v1"


def mkuser(role, phone, email, **kw):
    uid = str(uuid.uuid4())
    db["users"].insert_one({
        "_id": uid, "id": uid, "name": f"{role}-{phone[-3:]}", "phone": phone, "email": email, "role": role,
        "password_hash": hash_password("GoodPass123"), "is_active": True, "approval_status": "approved",
        "is_email_verified": True, "is_phone_verified": True, "token_version": 0, "created_at": now, **kw})
    return uid


n_ip = [0]


def tok(ident, pw="GoodPass123"):
    n_ip[0] += 1
    r = TestClient(app, client=(f"10.7.{n_ip[0]}.1", 1)).post(f"{API}/auth/login", json={"identifier": ident, "password": pw})
    assert r.status_code == 200, (ident, r.text)
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


mkuser("client", "9111111111", "cl@x.in")
mkuser("sales", "9333333331", "s1@x.in")
mkuser("site", "9444444441", "site@x.in", trade="structure")
mkuser("service", "9666666661", "svc@x.in")
db["customers"].insert_one({"_id": "custA", "id": "custA", "name": "Asha Rooftop", "phone": "9876543210",
                            "address": "12 Sun Street", "sales_id": None, "created_at": now})
ADM, CL, SALES, SITE, SVC = tok("boss@solarpro.in", "BossPass123"), tok("cl@x.in"), tok("s1@x.in"), tok("site@x.in"), tok("svc@x.in")
c = client

# ── Access control ──────────────────────────────────────────────────────────
check("client cannot read inventory", c.get(f"{API}/inventory/items", headers=CL).status_code == 403)
check("client cannot look up serials", c.get(f"{API}/serials/ANY", headers=CL).status_code == 403)
check("sales cannot create items", c.post(f"{API}/inventory/items", json={"category": "cable", "name": "X"}, headers=SALES).status_code == 403)
check("unauthenticated rejected", c.get(f"{API}/inventory/items").status_code == 401)

# ── Catalogue ───────────────────────────────────────────────────────────────
r = c.post(f"{API}/inventory/items", json={"category": "panel", "name": "Mono Panel 550W", "brand": "Waaree",
                                            "has_serial": True, "min_stock": 2}, headers=ADM)
check("admin creates serialised item", r.status_code == 201 and r.json()["stock_qty"] == 0, r.text)
PANEL = r.json()["id"]
CABLE = c.post(f"{API}/inventory/items", json={"category": "cable", "name": "DC Cable 4mm", "unit": "meter", "min_stock": 50},
               headers=ADM).json()["id"]
check("unknown fields rejected", c.post(f"{API}/inventory/items", json={"category": "cable", "name": "Y", "stock_qty": 999},
                                        headers=ADM).status_code == 422)
SUP = c.post(f"{API}/suppliers", json={"name": "Sun Distributors", "phone": "9000011111"}, headers=ADM).json()["id"]
check("supplier listed", any(s["id"] == SUP for s in c.get(f"{API}/suppliers", headers=ADM).json()))

# ── Stock in ────────────────────────────────────────────────────────────────
r = c.post(f"{API}/inventory/stock-in", json={"item_id": PANEL, "qty": 3, "supplier_id": SUP, "warranty_months": 300,
                                               "serial_numbers": [" wp-001 ", "WP-002", "wp-003"]}, headers=ADM)
check("stock-in with serials", r.status_code == 201 and r.json()["supplier_name"] == "Sun Distributors", r.text)
check("serials stored upper-cased", sorted(s["serial_no"] for s in db["serial_items"].find()) == ["WP-001", "WP-002", "WP-003"])
check("stock count follows delivery", c.get(f"{API}/inventory/items/{PANEL}", headers=ADM).json()["stock_qty"] == 3)
r = c.post(f"{API}/inventory/stock-in", json={"item_id": PANEL, "qty": 1, "serial_numbers": ["WP-002"]}, headers=ADM)
check("duplicate serial rejected", r.status_code == 409, r.text)
r = c.post(f"{API}/inventory/stock-in", json={"item_id": PANEL, "qty": 2, "serial_numbers": ["WP-009"]}, headers=ADM)
check("serial count must match qty", r.status_code == 422, r.text)
check("rejected deliveries did not change stock", c.get(f"{API}/inventory/items/{PANEL}", headers=ADM).json()["stock_qty"] == 3)
c.post(f"{API}/inventory/stock-in", json={"item_id": CABLE, "qty": 100, "invoice_no": "INV-1"}, headers=ADM)

# ── Stock out ───────────────────────────────────────────────────────────────
r = c.post(f"{API}/inventory/stock-out", json={"item_id": PANEL, "qty": 2, "customer_id": "custA",
                                                "serial_numbers": ["wp-001", "WP-002"]}, headers=SITE)
check("site technician issues serials to a project", r.status_code == 201 and r.json()["customer_name"] == "Asha Rooftop", r.text)
s1 = db["serial_items"].find_one({"serial_no": "WP-001"})
check("issued serial installed with warranty", s1["status"] == "installed" and s1["customer_id"] == "custA" and s1["warranty_until"])
r = c.post(f"{API}/inventory/stock-out", json={"item_id": PANEL, "qty": 2, "customer_id": "custA",
                                                "serial_numbers": ["WP-003", "WP-404"]}, headers=ADM)
check("issue with a bad serial rejected", r.status_code == 422, r.text)
check("partially claimed serial rolled back", db["serial_items"].find_one({"serial_no": "WP-003"})["status"] == "in_stock")
check("panel stock after issue", c.get(f"{API}/inventory/items/{PANEL}", headers=ADM).json()["stock_qty"] == 1)
r = c.post(f"{API}/inventory/stock-out", json={"item_id": CABLE, "qty": 101, "customer_id": "custA"}, headers=ADM)
check("cannot issue more than in stock", r.status_code == 422, r.text)
r = c.post(f"{API}/inventory/stock-out", json={"item_id": CABLE, "qty": 60, "customer_id": "custA"}, headers=ADM)
check("issue non-serial stock", r.status_code == 201)
check("unknown customer rejected", c.post(f"{API}/inventory/stock-out", json={"item_id": CABLE, "qty": 1, "customer_id": "nope"},
                                          headers=ADM).status_code == 404)
check("sales cannot issue stock", c.post(f"{API}/inventory/stock-out", json={"item_id": CABLE, "qty": 1, "customer_id": "custA"},
                                         headers=SALES).status_code == 403)

# ── Adjust / low stock ──────────────────────────────────────────────────────
check("serial items cannot be count-adjusted", c.post(f"{API}/inventory/adjust", json={"item_id": PANEL, "new_qty": 9, "note": "recount"},
                                                      headers=ADM).status_code == 400)
r = c.post(f"{API}/inventory/adjust", json={"item_id": CABLE, "new_qty": 45, "note": "physical recount"}, headers=ADM)
check("adjust records the delta (40 -> 45)", r.status_code == 200 and r.json()["qty"] == 5, r.text)
low = {i["id"]: i for i in c.get(f"{API}/inventory/low-stock", headers=ADM).json()}
check("low-stock lists both items", PANEL in low and CABLE in low and low[CABLE]["shortage"] == 5, low)
check("low_stock filter on list", {i["id"] for i in c.get(f"{API}/inventory/items?low_stock=true", headers=ADM).json()} == {PANEL, CABLE})
check("search by brand", [i["id"] for i in c.get(f"{API}/inventory/items?search=waaree", headers=ADM).json()] == [PANEL])

# ── Lookups ─────────────────────────────────────────────────────────────────
r = c.get(f"{API}/serials/wp-001", headers=SVC)
d = r.json()
check("service looks up serial (any case)", r.status_code == 200 and d["customer_name"] == "Asha Rooftop"
      and d["customer_address"] == "12 Sun Street" and d["is_under_warranty"] is True and d["brand"] == "Waaree", r.text)
check("unknown serial is 404", c.get(f"{API}/serials/NOPE", headers=SVC).status_code == 404)
mats = c.get(f"{API}/customers/custA/materials", headers=ADM).json()["materials"]
by = {m["item_id"]: m for m in mats}
check("project materials", by[PANEL]["total_qty"] == 2 and len(by[PANEL]["serials"]) == 2 and by[CABLE]["total_qty"] == 60, mats)
check("serials tab lists units", len(c.get(f"{API}/inventory/serials", headers=ADM).json()) == 3)
check("serials filter by status", [s["serial_no"] for s in c.get(f"{API}/inventory/serials?status=in_stock", headers=ADM).json()] == ["WP-003"])

# ── Serial status changes keep stock right ──────────────────────────────────
sid3 = db["serial_items"].find_one({"serial_no": "WP-003"})["_id"]
sid1 = db["serial_items"].find_one({"serial_no": "WP-001"})["_id"]
qty = lambda: c.get(f"{API}/inventory/items/{PANEL}", headers=ADM).json()["stock_qty"]  # noqa: E731
r = c.patch(f"{API}/serials/{sid3}/status", json={"status": "defective", "note": "cracked glass"}, headers=SVC)
check("in-stock unit marked defective leaves stock", r.status_code == 200 and qty() == 0, r.text)
c.patch(f"{API}/serials/{sid3}/status", json={"status": "in_stock", "note": "replaced by supplier"}, headers=ADM)
check("defective unit back in stock", qty() == 1)
check("cannot mark installed directly", c.patch(f"{API}/serials/{sid3}/status", json={"status": "installed"}, headers=ADM).status_code == 400)
c.patch(f"{API}/serials/{sid1}/status", json={"status": "returned", "note": "warranty claim"}, headers=SVC)
check("installed unit returned does not touch stock", qty() == 1)
c.patch(f"{API}/serials/{sid1}/status", json={"status": "in_stock", "note": "refurbished"}, headers=ADM)
s1 = db["serial_items"].find_one({"_id": sid1})
check("returned unit restocked and detached from project", qty() == 2 and s1["customer_id"] is None)
check("sales cannot change serial status", c.patch(f"{API}/serials/{sid1}/status", json={"status": "defective"},
                                                   headers=SALES).status_code == 403)

# ── Ledger / deletion ───────────────────────────────────────────────────────
moves = c.get(f"{API}/inventory/movements", headers=ADM).json()
check("ledger records every movement with names", len(moves) >= 8 and all(m["item_name"] and m["mover_name"] for m in moves))
check("item with stock cannot be deleted", c.delete(f"{API}/inventory/items/{CABLE}", headers=ADM).status_code == 400)
c.post(f"{API}/inventory/adjust", json={"item_id": CABLE, "new_qty": 0, "note": "written off"}, headers=ADM)
check("empty item deleted", c.delete(f"{API}/inventory/items/{CABLE}", headers=ADM).status_code == 204
      and c.get(f"{API}/inventory/items/{CABLE}", headers=ADM).status_code == 404)

# ── Reports (MongoDB) ───────────────────────────────────────────────────────
s1_id = db["users"].find_one({"email": "s1@x.in"})["_id"]
db["customers"].update_one({"_id": "custA"}, {"$set": {"sales_id": s1_id, "final_price": 30000000, "stage": "INSTALLATION_COMPLETE"}})
db["customers"].insert_one({"_id": "ph1", "id": "ph1", "user_id": "u-x", "self_registered": True, "phone": "9000000099",
                            "final_price": 0, "stage": "REGISTRATION_SUBMITTED", "created_at": now})
db["leads"].insert_many([{"_id": "L1", "status": "new", "assigned_sales_id": s1_id},
                         {"_id": "L2", "status": "converted", "assigned_sales_id": s1_id}])
db["payments"].insert_many([
    {"_id": "p1", "customer_id": "custA", "customer_name": "Asha Rooftop", "amount": 6000000, "mode": "UPI", "status": "verified", "created_at": now},
    {"_id": "p2", "customer_id": "custA", "customer_name": "=HYPERLINK(\"x\")", "amount": 1000000, "mode": "CASH", "status": "sales_approved", "created_at": now},
])
db["kedl_files"].insert_one({"_id": "k1", "customer_id": "custA", "status": "demand_raised",
                             "demands": [{"id": "d1", "amount": 250000, "status": "open"}, {"id": "d2", "amount": 100000, "status": "paid"}]})
db["work_assignments"].insert_many([
    {"_id": "w1", "customer_id": "custA", "work_type": "structure", "status": "completed", "assigned_to": "e1", "assigned_employee_name": "Sid"},
    {"_id": "w2", "customer_id": "custA", "work_type": "electrical", "status": "in_progress", "assigned_to": "e1", "assigned_employee_name": "Sid"},
    {"_id": "w3", "customer_id": "custA", "work_type": "civil", "status": "cancelled", "duplicate_of": "w9"},
])
check("reports are admin-only", c.get(f"{API}/reports/dashboard", headers=SALES).status_code == 403
      and c.get(f"{API}/reports/export/payments", headers=CL).status_code == 403)
dash = c.get(f"{API}/reports/dashboard", headers=ADM).json()
check("dashboard KPIs", dash["total_leads"] == 2 and dash["pending_payment_verifications_count"] == 1
      and dash["open_kedl_demands_count"] == 1 and dash["active_works_count"] == 1
      and dash["customers_by_stage"].get("REGISTRATION_SUBMITTED") == 1 and dash["low_stock_items_count"] >= 1, dash)
sales = c.get(f"{API}/reports/sales", headers=ADM).json()
rep = next(r for r in sales["sales_reps"] if r["sales_rep_id"] == s1_id)
check("sales report per rep (placeholder excluded)", rep["total_leads"] == 2 and rep["converted_customers"] == 1
      and rep["total_sales_paise"] == 30000000 and sales["total_sales_paise"] == 30000000, sales)
pay = c.get(f"{API}/reports/payments", headers=ADM).json()
check("payments report", pay["total_billed_paise"] == 30000000 and pay["total_collected_paise"] == 6000000
      and pay["pending_verification_paise"] == 1000000 and pay["payments_by_mode"] == {"upi": 6000000}, pay)
work = c.get(f"{API}/reports/work", headers=ADM).json()
check("work report skips cancelled duplicates", work["total_completed"] == 1 and work["total_active"] == 1, work)
kr = c.get(f"{API}/reports/kedl", headers=tok("site@x.in")).status_code
kedl = c.get(f"{API}/reports/kedl", headers=ADM).json()
check("kedl report", kr == 403 and kedl["open_demands_total_paise"] == 250000 and kedl["paid_demands_total_paise"] == 100000, kedl)
import io as _io  # noqa: E402
import openpyxl  # noqa: E402
for name in ("customers", "payments", "inventory"):
    r = c.get(f"{API}/reports/export/{name}", headers=ADM)
    ok = r.status_code == 200 and "spreadsheetml" in r.headers.get("content-type", "")
    rows = list(openpyxl.load_workbook(_io.BytesIO(r.content)).active.values) if ok else []
    check(f"excel export: {name}", ok and len(rows) >= 2, r.status_code)
    if name == "payments":
        cells = [v for row in rows for v in row if isinstance(v, str)]
        check("excel formula injection neutralised", "'=HYPERLINK(\"x\")" in cells and not any(v.startswith("=") for v in cells))

# ── Lead conversion keeps the full equipment scope; site sees it without prices ──
S1 = SALES
lead = c.post(f"{API}/leads", json={"name": "Ravi Kumar", "phone": "9812345670", "area": "Sector 9"}, headers=S1).json()
r = c.post(f"{API}/leads/{lead['id']}/convert", json={
    "address": "Plot 4, Sector 9", "latitude": 28.4595, "longitude": 77.0266, "final_price": 25000000, "capacity_kw": 5.4,
    "phase": "single", "panel_brand": "Waaree", "panel_watt": 540, "panel_count": 10, "inverter_brand": "Growatt",
    "structure_type": "GI", "bom": {"inverter_count": 1, "inverter_capacity_kw": 5, "structure_height": " 6 ft ",
                                    "ac_wire_brand": "Polycab", "ac_wire_size": "4 sq.mm", "civil_work": "", "solar_meter_count": 1},
}, headers=S1)
check("lead converts with equipment details", r.status_code == 200, r.text[:300])
cust = db["customers"].find_one({"lead_id": lead["id"]})
check("equipment details stored (trimmed, blanks dropped)", cust["bom"] == {"inverter_count": 1, "inverter_capacity_kw": 5.0,
      "structure_height": "6 ft", "ac_wire_brand": "Polycab", "ac_wire_size": "4 sq.mm", "solar_meter_count": 1}, cust.get("bom"))
check("site GPS stored", cust["latitude"] == 28.4595 and cust["location_gps"] == "28.459500,77.026600", cust.get("location_gps"))
check("unknown equipment field rejected", c.post(f"{API}/leads/{lead['id']}/convert", json={"bom": {"price": 1}},
                                                  headers=S1).status_code == 422)
site_id = db["users"].find_one({"email": "site@x.in"})["_id"]
# Site tasks open when their stage becomes current; open the wiring task directly.
from app.services import workflow as _wf  # noqa: E402
check("no site task before its stage", db["work_assignments"].count_documents({"customer_id": cust["_id"]}) == 0)
_wf._ensure_site_work(db, cust, "electrical")
job = db["work_assignments"].find_one({"customer_id": cust["_id"], "work_type": "electrical"})
db["work_assignments"].update_one({"_id": job["_id"]}, {"$set": {"assigned_to": site_id}})
r = c.get(f"{API}/work-assignments/{job['_id']}/scope", headers=SITE)
sc = r.json()
check("site scope has real equipment", r.status_code == 200 and sc["bom"]["ac_wire_brand"] == "Polycab"
      and sc["inverter_brand"] == "Growatt" and sc["customer_name"] == "Ravi Kumar", r.text[:300])
check("site scope never exposes money", not any(k in sc for k in ("final_price", "paid_amount", "payment_plan", "loan_details", "documents")))
other = db["work_assignments"].find_one({"customer_id": "custA"}) or {"_id": "w1"}
check("site cannot read scope of unrelated job", c.get(f"{API}/work-assignments/w1/scope", headers=SITE).status_code == 404)
r = c.patch(f"{API}/customers/{cust['_id']}", json={"bom": {"dc_wire_brand": "Finolex"}}, headers=S1)
check("sales updates equipment details", r.status_code == 200 and db["customers"].find_one({"_id": cust["_id"]})["bom"] == {"dc_wire_brand": "Finolex"}, r.text[:200])

# ── Payment plan & loan live on the server ───────────────────────────────────
cid = cust["_id"]
check("no plan yet", c.get(f"{API}/customers/{cid}/payment-plan", headers=S1).json() is None)
plan = {"isLocked": True, "milestones": [{"id": "m1", "title": "Advance", "isPercentage": True, "percentage": 30, "dueCondition": "Booking"},
                                         {"id": "m2", "title": "Balance", "isPercentage": True, "percentage": 70}]}
r = c.put(f"{API}/customers/{cid}/payment-plan", json=plan, headers=S1)
check("sales saves payment plan", r.status_code == 200 and r.json()["milestones"][1]["percentage"] == 70, r.text[:200])
check("admin sees the same plan", c.get(f"{API}/customers/{cid}/payment-plan", headers=ADM).json()["isLocked"] is True)
bad = {"milestones": [{"id": "a", "title": "A", "percentage": 80}, {"id": "b", "title": "B", "percentage": 40}]}
check("plan over 100% rejected", c.put(f"{API}/customers/{cid}/payment-plan", json=bad, headers=S1).status_code == 400)
loan = {"hasLoan": True, "bankName": "SBI", "loanAmountPaise": 15000000,
        "installments": [{"id": "i1", "amountPaise": 15000000, "expectedDate": "2026-12-15T00:00:00Z"}]}
r = c.put(f"{API}/customers/{cid}/loan", json=loan, headers=S1)
check("sales saves loan", r.status_code == 200 and c.get(f"{API}/customers/{cid}/loan", headers=ADM).json()["bankName"] == "SBI", r.text[:200])
mkuser("sales", "9333333339", "s9@x.in")
S9 = tok("s9@x.in")
check("other salesperson cannot edit plan", c.put(f"{API}/customers/{cid}/payment-plan", json=plan, headers=S9).status_code == 404)
check("client cannot read loan", c.get(f"{API}/customers/{cid}/loan", headers=CL).status_code == 403)

# ── Requests exactly as the app sends them ──────────────────────────────────
svc_id = db["users"].find_one({"email": "svc@x.in"})["_id"]
db["tickets"].insert_one({"_id": "tk1", "id": "tk1", "ticket_no": "TCK-1", "customer_id": "custA", "title": "Wiring",
                          "status": "in_progress", "assigned_to": svc_id, "created_at": now})
r = c.post(f"{API}/tickets/tk1/status", json={"status": "resolved", "resolution_note": "Replaced MC4 connector"}, headers=SVC)
check("ticket resolves with the note the app sends", r.status_code == 200
      and db["tickets"].find_one({"_id": "tk1"})["status"] == "resolved", r.text[:200])
db["tickets"].update_one({"_id": "tk1"}, {"$set": {"status": "in_progress"}})
check("resolving without a note is still refused", c.post(f"{API}/tickets/tk1/status", json={"status": "resolved"},
                                                          headers=SVC).status_code == 400)
vendor_body = {"name": "Meena Devi", "phone": "9811122233", "mobile": "9811122233", "email": "Meena@X.in",
               "address": "12 MG Road, Jaipur", "location_gps": "26.912400,75.787300", "kw": 5.0, "final_price": 25000000,
               "total_amount": 25000000, "milestones": [], "documents": {}, "sales_id": None, "sales_name": None}
r = c.post(f"{API}/customers", json=vendor_body, headers=ADM)
meena = db["customers"].find_one({"phone": "9811122233"}) or {}
check("vendor Add Customer form succeeds", r.status_code == 201, r.text[:300])
check("vendor customer keeps size, GPS and email", meena.get("capacity_kw") == 5.0 and meena.get("latitude") == 26.9124
      and meena.get("location_gps") == "26.912400,75.787300" and meena.get("email") == "meena@x.in", meena)
check("customer form still validates phone", c.post(f"{API}/customers", json={**vendor_body, "mobile": "12345"},
                                                    headers=ADM).status_code == 422)

client.__exit__(None, None, None)
failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
sys.exit(1 if failed else 0)
