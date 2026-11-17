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

client.__exit__(None, None, None)
failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
sys.exit(1 if failed else 0)
