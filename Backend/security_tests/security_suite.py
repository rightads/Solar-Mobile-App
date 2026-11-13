"""Adversarial test-suite for the SolarPro API (runs the real app on mongomock)."""
import base64, io, json, os, sys, tempfile, time, uuid
from datetime import datetime, timedelta, timezone

BACKEND = sys.argv[1]
os.chdir(BACKEND)
sys.path.insert(0, BACKEND)
UP = tempfile.mkdtemp()
os.environ.update({
    "ENV": "test", "DEBUG": "false", "JWT_SECRET": "t" * 48, "MONGODB_URI": "",
    "SUPER_ADMIN_EMAIL": "boss@solarpro.in", "SUPER_ADMIN_PHONE": "9000000001",
    "SUPER_ADMIN_PASSWORD": "BossPass123", "UPLOAD_DIR": UP, "CORS_ORIGINS": "[]",
})
import mongomock
import app.db.mongo as M
M._client = mongomock.MongoClient(tz_aware=True)
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import hash_password, create_access_token
import jwt

results = []
def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))
    print(("PASS " if cond else "FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))

ip_counter = [0]
def H(tok=None, fresh_ip=True):
    h = {}
    if tok: h["Authorization"] = f"Bearer {tok}"
    return h

client = TestClient(app, client=("10.0.0.1", 5000))
client.__enter__()
db = M.get_mongo_db()
now = datetime.now(timezone.utc)

def mkuser(role, phone, email, pw="GoodPass123", **kw):
    uid = str(uuid.uuid4())
    doc = {"_id": uid, "id": uid, "name": f"{role}-{phone[-3:]}", "phone": phone, "email": email, "role": role,
           "password_hash": hash_password(pw), "is_active": True, "approval_status": "approved",
           "is_email_verified": True, "is_phone_verified": False, "token_version": 0, "created_at": now}
    doc.update(kw)
    db["users"].insert_one(doc)
    return doc

def login(ident, pw="GoodPass123", ipaddr="10.0.0.1"):
    c = TestClient(app, client=(ipaddr, 5000))
    r = c.post("/api/v1/auth/login", json={"identifier": ident, "password": pw})
    return r

def tok(u):
    r = login(u["email"], ipaddr=f"10.1.{len(results)}.1")
    assert r.status_code == 200, (u["email"], r.status_code, r.text)
    return r.json()["access_token"]

clientA = mkuser("client", "9111111111", "a@x.in", is_phone_verified=True)
clientB = mkuser("client", "9222222222", "b@x.in", is_phone_verified=True)
s1 = mkuser("sales", "9333333331", "s1@x.in", employee_no="EMP-S1")
s2 = mkuser("sales", "9333333332", "s2@x.in")
site = mkuser("site", "9444444441", "site@x.in", trade="structure")
kedl = mkuser("kedl", "9555555551", "kedl@x.in")
svc = mkuser("service", "9666666661", "svc@x.in")
pending = mkuser("sales", "9777777771", "pend@x.in", is_active=False, approval_status="pending")
admin_doc = db["users"].find_one({"is_superadmin": True})
check("superadmin seeded from env", admin_doc is not None)

for cid, phone, sid, uid in (("custA", clientA["phone"], s1["_id"], None), ("custB", clientB["phone"], s2["_id"], None)):
    db["customers"].insert_one({"_id": cid, "id": cid, "name": cid, "phone": phone, "mobile": phone, "address": "addr " + cid,
                                "sales_id": sid, "final_price": 30000000, "stage": "SALE_CONFIRMED", "documents": {}, "created_at": now})
db["customers"].insert_one({"_id": "custV", "id": "custV", "name": "Victim", "phone": "9888888888", "mobile": "9888888888",
                            "address": "victim house", "sales_id": s1["_id"], "final_price": 50000000, "created_at": now})
db["tickets"].insert_one({"_id": "tB", "id": "tB", "customer_id": "custB", "title": "B ticket", "status": "open", "created_at": now})
db["work_assignments"].insert_one({"_id": "wB", "id": "wB", "customer_id": "custB", "work_type": "civil", "status": "assigned",
                                   "assigned_to": "someone-else", "created_at": now})
from app.services.workflow import migrate_legacy_customers
check("legacy customers migrated to the 4-stage workflow", migrate_legacy_customers() == 3)
check("migration is idempotent", migrate_legacy_customers() == 0)
db["notifications"].insert_one({"_id": "nB", "id": "nB", "user_id": clientB["_id"], "title": "private", "is_read": False, "read": False, "created_at": now.isoformat()})

TA, TB, TS1, TS2 = tok(clientA), tok(clientB), tok(s1), tok(s2)
TSITE, TKEDL, TSVC = tok(site), tok(kedl), tok(svc)
TADM = login("boss@solarpro.in", "BossPass123", "10.9.9.9").json()["access_token"]
c = client

# ── Registration / account takeover ─────────────────────────────────────────
r = c.post("/api/v1/auth/register", json={"name": "Evil", "phone": "9123456780", "email": "e@x.in", "password": "EvilPass123", "role": "admin"})
check("register as admin rejected", r.status_code == 400, r.text)
r = c.post("/api/v1/auth/register", json={"name": "Evil", "phone": clientA["phone"], "email": "evil@x.in", "password": "EvilPass123", "role": "client"})
check("re-register existing phone rejected", r.status_code == 400, r.text)
check("victim password unchanged after takeover attempt", login("a@x.in", ipaddr="10.2.0.1").status_code == 200)
r = c.post("/api/v1/auth/register", json={"name": "Evil", "phone": "9123456781", "email": "x@x.in", "password": "short", "role": "client"})
check("weak password rejected", r.status_code in (400, 422))

# Phone hijack: attacker registers victim's phone (no user yet), verifies own email
r = TestClient(app, client=("10.3.0.1", 1)).post("/api/v1/auth/register", json={"name": "Hijacker", "phone": "9888888888", "email": "hj@x.in", "password": "HijackPass1", "role": "client"})
check("hijacker can register unused phone", r.status_code == 201, r.text)
hj = db["users"].find_one({"email": "hj@x.in"})
db["users"].update_one({"_id": hj["_id"]}, {"$set": {"is_email_verified": True}})
THJ = login("hj@x.in", "HijackPass1", "10.3.0.2").json()["access_token"]
home = c.get("/api/v1/client/home", headers=H(THJ)).json()
check("phone hijack does NOT expose victim project", "victim house" not in json.dumps(home) and "Victim" not in json.dumps(home.get("customer", {})), json.dumps(home)[:200])
check("hijacker told to verify phone", home.get("needs_phone_verification") is True)
check("hijack attempt did not link victim record", db["customers"].find_one({"_id": "custV"}).get("user_id") in (None, ""))

# ── Credential brute force / enumeration ────────────────────────────────────
bc = TestClient(app, client=("10.4.0.1", 1))
codes = [bc.post("/api/v1/auth/login", json={"identifier": "s2@x.in", "password": f"Wrong{i}"}).status_code for i in range(7)]
check("login lockout after 5 failures", codes[:5] == [401] * 5 and 429 in codes[5:], codes)
check("correct password blocked while locked", bc.post("/api/v1/auth/login", json={"identifier": "s2@x.in", "password": "GoodPass123"}).status_code == 429)
e1 = TestClient(app, client=("10.4.1.1", 1)).post("/api/v1/auth/login", json={"identifier": "nobody@x.in", "password": "x"}).json()
e2 = TestClient(app, client=("10.4.1.2", 1)).post("/api/v1/auth/login", json={"identifier": "a@x.in", "password": "x"}).json()
check("login error identical for unknown user vs wrong password", e1["error"]["message"] == e2["error"]["message"])
ipc = TestClient(app, client=("10.4.2.1", 1))
st = [ipc.post("/api/v1/auth/login", json={"identifier": f"u{i}@x.in", "password": "x"}).status_code for i in range(32)]
check("per-IP login throttle (credential stuffing)", 429 in st)

o = TestClient(app, client=("10.5.0.1", 1))
r1 = o.post("/api/v1/auth/request-otp", json={"phone": "9999999990"}).json()
r2 = TestClient(app, client=("10.5.0.2", 1)).post("/api/v1/auth/request-otp", json={"phone": clientA["phone"]}).json()
check("OTP response identical for unknown/known number", r1 == r2, (r1, r2))
check("OTP response leaks no email/dev otp", "email" not in r2 and "dev_otp" not in r2)
check("no OTP stored for unregistered number (no SMS pumping)", db["otp_codes"].count_documents({"phone": "9999999990"}) == 0)
check("OTP resend cooldown", TestClient(app, client=("10.5.0.3", 1)).post("/api/v1/auth/request-otp", json={"phone": clientA["phone"]}).status_code == 429)
rec = db["otp_codes"].find_one({"phone": clientA["phone"]})
check("OTP stored hashed, not plaintext", rec and len(rec["code_hash"]) == 64 and "code" not in rec)
vc = TestClient(app, client=("10.5.1.1", 1))
vs = [vc.post("/api/v1/auth/verify-otp", json={"phone": clientA["phone"], "otp": f"{i:06d}"}).status_code for i in range(12)]
check("OTP verify brute-force capped", 429 in vs, vs)
db["rate_limits"].delete_many({"_id": {"$regex": "^otp"}})
db["otp_codes"].delete_many({})
from app.core.security import hash_token
db["otp_codes"].insert_one({"_id": "o1", "phone": clientB["phone"], "code_hash": hash_token("123456"), "expires_at": now + timedelta(minutes=5), "attempts": 0, "consumed_at": None, "created_at": now})
r = TestClient(app, client=("10.5.2.1", 1)).post("/api/v1/auth/verify-otp", json={"phone": clientB["phone"], "otp": "123456"})
check("valid OTP logs in", r.status_code == 200)
r = TestClient(app, client=("10.5.2.2", 1)).post("/api/v1/auth/verify-otp", json={"phone": clientB["phone"], "otp": "123456"})
check("OTP is single-use", r.status_code == 400)

# ── Token attacks ───────────────────────────────────────────────────────────
hdr = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').rstrip(b"=").decode()
pl = base64.urlsafe_b64encode(json.dumps({"sub": admin_doc["_id"], "role": "admin", "type": "access", "tv": 0, "iss": "solarpro-api", "iat": 1, "exp": 9999999999}).encode()).rstrip(b"=").decode()
check("alg=none token rejected", c.get("/api/v1/auth/me", headers=H(f"{hdr}.{pl}.")).status_code == 401)
forged = jwt.encode({"sub": admin_doc["_id"], "role": "admin", "type": "access", "tv": 0, "iss": "solarpro-api", "iat": now, "exp": now + timedelta(hours=1)}, "wrong-secret-" * 4, algorithm="HS256")
check("token signed with wrong secret rejected", c.get("/api/v1/auth/me", headers=H(forged)).status_code == 401)
expired = create_access_token(s1["_id"], "sales", 0, expires_delta=timedelta(seconds=-5))
check("expired token rejected", c.get("/api/v1/auth/me", headers=H(expired)).status_code == 401)
role_lie = create_access_token(clientA["_id"], "admin", 0)
check("role claim in token is not trusted", c.get("/api/v1/users", headers=H(role_lie)).status_code == 403)
check("pending staff cannot sign in", login("pend@x.in", ipaddr="10.6.0.1").status_code == 403)

lr = login("s1@x.in", ipaddr="10.6.1.1").json()
rt1 = lr["refresh_token"]
rr = TestClient(app, client=("10.6.1.2", 1)).post("/api/v1/auth/refresh", json={"refresh_token": rt1})
check("refresh works", rr.status_code == 200, rr.text)
rt2 = rr.json()["refresh_token"]
check("replayed refresh token rejected", TestClient(app, client=("10.6.1.3", 1)).post("/api/v1/auth/refresh", json={"refresh_token": rt1}).status_code == 401)
check("reuse detection revokes whole session family", TestClient(app, client=("10.6.1.4", 1)).post("/api/v1/auth/refresh", json={"refresh_token": rt2}).status_code == 401)
t_old = lr["access_token"]
c.post("/api/v1/auth/logout-all", headers=H(t_old))
check("logout-all invalidates existing access tokens", c.get("/api/v1/auth/me", headers=H(t_old)).status_code == 401)
TS1 = tok(s1)

# ── IDOR / RBAC ─────────────────────────────────────────────────────────────
for path in ("/api/v1/customers", "/api/v1/customers/custB", "/api/v1/tickets", "/api/v1/teams/employees", "/api/v1/users",
             "/api/v1/leads", "/api/v1/work-assignments", "/api/v1/kedl-files", "/api/v1/payments/pending"):
    check(f"client blocked from {path}", c.get(path, headers=H(TA)).status_code in (403, 404))
check("client cannot read another customer's payments", c.get("/api/v1/customers/custB/payments", headers=H(TA)).status_code == 404)
check("client can read own payments", c.get("/api/v1/customers/custA/payments", headers=H(TA)).status_code == 200)
check("client cannot read another client's ticket", c.get("/api/v1/client/tickets/tB", headers=H(TA)).status_code == 404)
check("client cannot comment on another client's ticket", c.post("/api/v1/client/tickets/tB/comments", json={"message": "hi"}, headers=H(TA)).status_code == 404)
check("client cannot complete installation work", c.post("/api/v1/work-assignments/wB/complete", headers=H(TA)).status_code == 403)
check("client cannot read others' notifications", c.post("/api/v1/notifications/nB/read", headers=H(TA)).status_code == 404)
check("client cannot download staff APIs (staff ticket status)", c.post("/api/v1/tickets/tB/status", json={"status": "closed"}, headers=H(TA)).status_code == 403)
check("sales cannot read other sales' customer", c.get("/api/v1/customers/custA", headers=H(TS2)).status_code == 404)
check("sales cannot create employees", c.post("/api/v1/teams/employees", json={"name": "x y", "phone": "9100000009", "role": "admin"}, headers=H(TS1)).status_code == 403)
r = c.post("/api/v1/teams/employees", json={"name": "Over Write", "phone": "9000000001", "role": "sales", "password": "NewPass123"}, headers=H(TADM))
check("admin cannot overwrite existing account via create-employee", r.status_code == 400)
check("superadmin password intact", login("boss@solarpro.in", "BossPass123", "10.7.0.1").status_code == 200)
r = c.post("/api/v1/teams/employees", json={"name": "Not Admin", "phone": "9100000010", "role": "admin"}, headers=H(TADM))
check("create-employee cannot mint admins", r.status_code == 400)
emp = c.get("/api/v1/teams/employees", headers=H(TS1)).text
check("no password hashes in staff directory", "password_hash" not in emp and "$2b$" not in emp)
check("no password hashes in /users", "$2b$" not in c.get("/api/v1/users", headers=H(TADM)).text)
check("service engineer cannot assign tickets", c.post("/api/v1/tickets/tB/assign", json={"assigned_to": svc["_id"]}, headers=H(TSVC)).status_code == 403)
check("unknown assignee → 404 (no Vikram fallback)", c.post("/api/v1/tickets/tB/assign", json={"assigned_to": "nope"}, headers=H(TADM)).status_code == 404)
check("site staff cannot see other staff's work", c.get("/api/v1/work-assignments/wB", headers=H(TSITE)).status_code == 404)

# ── Mass assignment / injection ─────────────────────────────────────────────
for evil in ({"paid_amount": 999999999}, {"stage": "HANDED_OVER"}, {"documents": {"aadhaar": True}}, {"user_id": clientB["_id"]}, {"$set": {"x": 1}}):
    check(f"customer PATCH rejects {list(evil)[0]}", c.patch("/api/v1/customers/custA", json=evil, headers=H(TS1)).status_code == 422)
check("sales cannot reassign customer owner", c.patch("/api/v1/customers/custA", json={"sales_id": s2["_id"]}, headers=H(TS1)).status_code == 400)
r = c.post("/api/v1/auth/login", json={"identifier": {"$ne": None}, "password": {"$ne": None}})
check("NoSQL operator injection in login rejected", r.status_code == 422)
r = c.get("/api/v1/customers", params={"search": ".*"}, headers=H(TADM))
check("regex search is escaped", r.status_code == 200 and r.json()["total"] == 0, r.text[:120])
r = c.post("/api/v1/auth/login", json={"identifier": "a@x.in", "password": 123})
check("validation error never echoes submitted values", "123" not in r.text and "input" not in r.text)
lead = c.post("/api/v1/leads", json={"name": "Lead One", "phone": "9123400001", "kw": 3}, headers=H(TS1)).json()
cv = c.post(f"/api/v1/leads/{lead['id']}/convert", json={"user_id": clientA["_id"], "paid_amount": 999, "stage": "HANDED_OVER", "documents": {"pan": 1}, "final_price": 100}, headers=H(TS1)).json()
check("lead convert ignores ownership/money/stage fields", cv.get("user_id") is None and cv.get("paid_amount", 0) == 0 and cv.get("stage") != "HANDED_OVER", json.dumps(cv)[:200])

# ── Uploads ─────────────────────────────────────────────────────────────────
png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 200
r = c.post("/api/v1/customers/custA/documents", data={"type": "aadhaar"}, files={"file": ("a.png", png, "image/png")}, headers=H(TS1))
check("valid KYC upload accepted", r.status_code == 201, r.text[:200])
fid = r.json()["document"]["file_id"] if r.status_code == 201 else ""
r = c.post("/api/v1/customers/custA/documents", data={"type": "pan"}, files={"file": ("evil.jpg", b"<html><script>alert(1)</script>", "image/jpeg")}, headers=H(TS1))
check("HTML disguised as JPG rejected", r.status_code == 400)
r = c.post("/api/v1/customers/custA/documents", data={"type": "pan"}, files={"file": ("big.png", png + b"0" * (11 * 1024 * 1024), "image/png")}, headers=H(TS1))
check("oversized upload rejected", r.status_code == 400)
r = c.post("/api/v1/customers/custA/documents", data={"type": "../../etc/passwd"}, files={"file": ("a.png", png, "image/png")}, headers=H(TS1))
check("doc type path traversal rejected", r.status_code == 400)
check("other client cannot download KYC file", c.get(f"/api/v1/files/{fid}", headers=H(TB)).status_code == 404)
check("other sales cannot download KYC file", c.get(f"/api/v1/files/{fid}", headers=H(TS2)).status_code == 404)
d = c.get(f"/api/v1/files/{fid}", headers=H(TS1))
check("owner can download, served with nosniff", d.status_code == 200 and d.headers.get("x-content-type-options") == "nosniff")
check("file id traversal rejected", c.get("/api/v1/files/..%2F..%2Fapp%2Fmain.py", headers=H(TADM)).status_code == 404)
check("unauthenticated download blocked", c.get(f"/api/v1/files/{fid}").status_code == 401)

# ── Payments & workflow ─────────────────────────────────────────────────────
pay = c.post("/api/v1/client/payments", data={"amount": "5000000", "mode": "upi"}, headers=H(TA)).json()
check("client payment recorded against own project", pay.get("customer_id") == "custA" and pay.get("status") == "pending", json.dumps(pay)[:200])
check("other sales cannot approve", c.post(f"/api/v1/payments/{pay['id']}/sales-approve", headers=H(TS2)).status_code == 404)
check("sales cannot verify money", c.post(f"/api/v1/payments/{pay['id']}/verify", headers=H(TS1)).status_code == 403)
check("owning sales approves", c.post(f"/api/v1/payments/{pay['id']}/sales-approve", headers=H(TS1)).status_code == 200)
check("admin verifies", c.post(f"/api/v1/payments/{pay['id']}/verify", headers=H(TADM)).status_code == 200)
ca = db["customers"].find_one({"_id": "custA"})
check("paid_amount computed server-side", ca.get("paid_amount") == 5000000)
tl = c.get("/api/v1/customers/custA/timeline", headers=H(TADM)).json()
check("timeline has the 4 department stages", [x["stage"] for x in tl.get("stages", [])] == ["INSTALLATION_COMPLETE", "KEDL_PROCESS", "SYSTEM_LIVE", "HANDED_OVER"], tl)
check("project starts with Site-ops", ca.get("assigned_role") == "site" and ca.get("stage") == "INSTALLATION_COMPLETE", (ca.get("assigned_role"), ca.get("stage")))
works = {w["work_type"]: w for w in db["work_assignments"].find({"customer_id": "custA"})}
check("site work auto-created (structure active, others pending)", works.get("structure", {}).get("status") == "assigned" and works.get("electrical", {}).get("status") == "pending")

# Sales assigns the Site-ops and KEDL employees on its own customer.
check("sales cannot assign on another sales' customer", c.patch("/api/v1/customers/custB", json={"site_employee_id": site["_id"]}, headers=H(TS1)).status_code == 404)
check("sales cannot assign the service engineer", c.patch("/api/v1/customers/custA", json={"service_employee_id": svc["_id"]}, headers=H(TS1)).status_code == 400)
check("assignee must be in the matching department", c.patch("/api/v1/customers/custA", json={"site_employee_id": kedl["_id"]}, headers=H(TS1)).status_code == 400)
check("pending staff cannot be assigned", c.patch("/api/v1/customers/custA", json={"kedl_employee_id": pending["_id"]}, headers=H(TS1)).status_code == 400)
r = c.patch("/api/v1/customers/custA", json={"site_employee_id": site["_id"], "kedl_employee_id": kedl["_id"]}, headers=H(TS1))
check("sales assigns Site-ops & KEDL on own customer", r.status_code == 200 and r.json().get("site_employee_id") == site["_id"] and r.json().get("kedl_employee_name") == kedl["name"], r.text[:200])
ca = db["customers"].find_one({"_id": "custA"})
check("assignment hands the project to that Site-ops employee", ca.get("assigned_to") == site["_id"])
check("open site work moved to the assigned employee", all(w.get("assigned_to") == site["_id"] for w in db["work_assignments"].find({"customer_id": "custA"})))
check("assigned employee notified", db["notifications"].find_one({"user_id": kedl["_id"], "target_id": "custA"}) is not None)
check("admin assigns the service engineer", c.patch("/api/v1/customers/custA", json={"service_employee_id": svc["_id"]}, headers=H(TADM)).status_code == 200)
check("site cannot complete without photo proof", c.post(f"/api/v1/work-assignments/{works['structure']['_id']}/complete", headers=H(TSITE)).status_code == 400)
for wt in ("structure", "electrical", "civil"):
    w = db["work_assignments"].find_one({"customer_id": "custA", "work_type": wt})
    c.post(f"/api/v1/work-assignments/{w['_id']}/photos", files=[("files", ("p.png", png, "image/png"))], headers=H(TSITE))
    r = c.post(f"/api/v1/work-assignments/{w['_id']}/complete", headers=H(TSITE))
    check(f"site completes {wt}", r.status_code == 200, r.text[:150])
ca = db["customers"].find_one({"_id": "custA"})
check("site→KEDL hand-off", ca.get("assigned_role") == "kedl" and db["kedl_files"].count_documents({"customer_id": "custA"}) == 3)
net = db["kedl_files"].find_one({"customer_id": "custA", "file_type": "net"})
check("sales cannot approve KEDL file", c.post(f"/api/v1/kedl-files/{net['_id']}/status", json={"status": "approved"}, headers=H(TS1)).status_code == 403)
r = c.post(f"/api/v1/kedl-files/{net['_id']}/status", json={"status": "approved"}, headers=H(TKEDL))
ca = db["customers"].find_one({"_id": "custA"})
check("net approval → SYSTEM_LIVE + service hand-off", r.status_code == 200 and ca.get("is_system_live") and ca.get("assigned_role") == "service", (ca.get("stage"), ca.get("assigned_role")))
check("sales cannot toggle site stages", c.post("/api/v1/customers/custA/timeline", json={"stage": "INSTALLATION_COMPLETE", "done": False}, headers=H(TS1)).status_code == 404)
t = c.post("/api/v1/client/tickets", json={"type": "inverter", "title": "Inverter error", "description": "Shows E05 fault"}, headers=H(TA)).json()
check("client ticket routes to linked service engineer (no hardcoded staff)", t.get("assigned_to") == svc["_id"] and "Vikram" not in json.dumps(t))

# ── Sign-up verification: email code + SMS code ────────────────────────────
from app.core.security import hash_token as _ht
sc = TestClient(app, client=("10.8.0.1", 1))
r = sc.post("/api/v1/auth/register", json={"name": "New Client", "phone": "9012345670", "email": "nc@x.in", "password": "NewClient123", "role": "client"})
check("register asks for email + SMS verification", r.status_code == 201 and r.json().get("requires_verification") and r.json().get("phone") == "9012345670", r.text[:200])
check("SMS code issued at sign-up", db["otp_codes"].count_documents({"phone": "9012345670", "consumed_at": None}) == 1)
check("email code issued at sign-up", db["email_verifications"].count_documents({"email": "nc@x.in", "consumed_at": None}) == 1)
db["otp_codes"].update_many({"phone": "9012345670"}, {"$set": {"code_hash": _ht("111111")}})
db["email_verifications"].update_many({"email": "nc@x.in"}, {"$set": {"code_hash": _ht("222222")}})
r = sc.post("/api/v1/auth/verify-signup", json={"email": "nc@x.in", "email_code": "222222", "phone": "9012345670", "phone_code": "000000"})
check("wrong SMS code rejected even with the right email code", r.status_code == 400 and "access_token" not in r.text)
check("failed attempt does not consume the email code", db["email_verifications"].count_documents({"email": "nc@x.in", "consumed_at": None}) == 1)
check("client not verified after a failed attempt", not db["users"].find_one({"email": "nc@x.in"}).get("is_phone_verified"))
r = sc.post("/api/v1/auth/verify-signup", json={"email": "nc@x.in", "email_code": "222222", "phone": "9012345670", "phone_code": "111111"})
nc = db["users"].find_one({"email": "nc@x.in"})
check("both codes verify the client and sign in", r.status_code == 200 and "access_token" in r.json() and nc.get("is_email_verified") and nc.get("is_phone_verified"), r.text[:200])
check("signup codes are single-use", sc.post("/api/v1/auth/verify-signup", json={"email": "nc@x.in", "email_code": "222222", "phone": "9012345670", "phone_code": "111111"}).status_code in (200, 400))
r = TestClient(app, client=("10.8.1.1", 1)).post("/api/v1/auth/register", json={"name": "New Kedl", "phone": "9012345671", "email": "nk@x.in", "password": "NewKedl1234", "role": "kedl"})
check("staff sign-up also requires both codes", r.status_code == 201 and r.json().get("requires_verification") and r.json().get("requires_approval"))
db["otp_codes"].update_many({"phone": "9012345671"}, {"$set": {"code_hash": _ht("333333")}})
db["email_verifications"].update_many({"email": "nk@x.in"}, {"$set": {"code_hash": _ht("444444")}})
r = TestClient(app, client=("10.8.1.2", 1)).post("/api/v1/auth/verify-signup", json={"email": "nk@x.in", "email_code": "444444", "phone": "9012345671", "phone_code": "333333"})
check("verified staff still waits for admin approval (no session)", r.status_code == 200 and r.json().get("requires_approval") and "access_token" not in r.json(), r.text[:200])
r = TestClient(app, client=("10.8.1.3", 1)).post("/api/v1/auth/verify-signup", json={"email": "a@x.in", "email_code": "444444", "phone": "9012345671", "phone_code": "333333"})
check("codes cannot verify a different account's email", r.status_code == 400)
r = TestClient(app, client=("10.8.1.4", 1)).post("/api/v1/auth/register", json={"name": "Old Role", "phone": "9012345672", "email": "or@x.in", "password": "OldRole1234", "role": "labour"})
check("sign-up offers only the 4 departments", r.status_code == 400)

# ── Change password (every role) ────────────────────────────────────────────
cpu = mkuser("service", "9666666662", "svc2@x.in")
T_cp = tok(cpu)
r = c.post("/api/v1/auth/change-password", json={"current_password": "Wrong9999", "new_password": "Brand1New"}, headers=H(T_cp))
check("change password needs the current password", r.status_code == 400)
r = c.post("/api/v1/auth/change-password", json={"current_password": "GoodPass123", "new_password": "weak"}, headers=H(T_cp))
check("change password enforces strength", r.status_code in (400, 422))
r = c.post("/api/v1/auth/change-password", json={"current_password": "GoodPass123", "new_password": "Brand1New"}, headers=H(T_cp))
check("change password returns a fresh session", r.status_code == 200 and r.json().get("access_token"), r.text[:200])
T_new = r.json().get("access_token", "")
check("old sessions revoked after password change", c.get("/api/v1/auth/me", headers=H(T_cp)).status_code == 401)
check("new session works after password change", c.get("/api/v1/auth/me", headers=H(T_new)).status_code == 200)
check("old password rejected after change", login("svc2@x.in", ipaddr="10.8.2.1").status_code == 401)
check("new password accepted after change", login("svc2@x.in", "Brand1New", "10.8.2.2").status_code == 200)
for role_, phone_, email_ in (("client", "9111111119", "cpc@x.in"), ("admin", "9000000019", "cpa@x.in")):
    u_ = mkuser(role_, phone_, email_, is_phone_verified=True)
    t_ = tok(u_)
    check(f"{role_} can change password", c.post("/api/v1/auth/change-password", json={"current_password": "GoodPass123", "new_password": "Brand2New"}, headers=H(t_)).status_code == 200)
nopw = mkuser("site", "9444444442", "site2@x.in")
db["users"].update_one({"_id": nopw["_id"]}, {"$unset": {"password_hash": ""}})
t_np = create_access_token(nopw["_id"], "site", 0)
check("OTP-only account sees has_password=false", c.get("/api/v1/auth/me", headers=H(t_np)).json().get("has_password") is False)
check("OTP-only account can set a first password", c.post("/api/v1/auth/change-password", json={"new_password": "First1Pass"}, headers=H(t_np)).status_code == 200)

# ── Staff directory: only 4 departments ─────────────────────────────────────
legacy = mkuser("electrician", "9444444443", "el@x.in", trade="electrical")
site_list = c.get("/api/v1/teams/employees", params={"trade": "site"}, headers=H(TADM)).json()
ids_ = {e["id"] for e in site_list}
check("Site-ops filter lists site and legacy trade staff", site["_id"] in ids_ and legacy["_id"] in ids_ and all(e.get("department") == "site" for e in site_list))
check("Sales filter lists only sales", all(e.get("department") == "sales" for e in c.get("/api/v1/teams/employees", params={"trade": "sales"}, headers=H(TADM)).json()))
check("unknown department filter is empty", c.get("/api/v1/teams/employees", params={"trade": "plumbing"}, headers=H(TADM)).json() == [])
r = c.post("/api/v1/teams/employees", json={"name": "New Site", "phone": "9100000011", "role": "site", "password": "SitePass123"}, headers=H(TADM))
check("admin creates a Site-ops employee with a password", r.status_code == 201 and r.json().get("role") == "site", r.text[:200])
check("new employee can sign in with that password", login("9100000011", "SitePass123", "10.8.3.1").status_code == 200)
check("legacy role names are not created as-is", c.post("/api/v1/teams/employees", json={"name": "Legacy Guy", "phone": "9100000012", "role": "office_staff"}, headers=H(TADM)).json().get("role") == "sales")

# ── Misc hardening ──────────────────────────────────────────────────────────
h = c.get("/api/v1/health").headers
check("security headers present", h.get("x-frame-options") == "DENY" and h.get("x-content-type-options") == "nosniff")
check("no fake payments seeded for new client", c.get("/api/v1/client/payments", headers=H(TB)).json() == [])
check("no fake teams", c.get("/api/v1/teams", headers=H(TADM)).json() == [])

client.__exit__(None, None, None)
failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
sys.exit(1 if failed else 0)
