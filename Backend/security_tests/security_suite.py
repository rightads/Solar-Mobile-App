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
wir = mkuser("wiring", "9444444451", "wir@x.in")
civ = mkuser("civil", "9444444461", "civ@x.in")
sub = mkuser("subsidy", "9444444471", "sub@x.in")
acc = mkuser("account", "9444444481", "acc@x.in")
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
check("legacy customers migrated to the 8-stage workflow", migrate_legacy_customers() == 3)
check("migration is idempotent", migrate_legacy_customers() == 0)
db["notifications"].insert_one({"_id": "nB", "id": "nB", "user_id": clientB["_id"], "title": "private", "is_read": False, "read": False, "created_at": now.isoformat()})

TA, TB, TS1, TS2 = tok(clientA), tok(clientB), tok(s1), tok(s2)
TSITE, TKEDL, TSVC = tok(site), tok(kedl), tok(svc)
TWIR, TCIV, TSUB, TACC = tok(wir), tok(civ), tok(sub), tok(acc)
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

# Phone hijack via the sign-in OTP's email copy: /request-otp also emails the
# code to the (attacker's) verified inbox. That code must sign in but never
# mark the victim's phone verified, through verify-otp or verify-signup.
from app.core import ratelimit as _rl
from app.services.email_service import email_service as _es_v
_otp_mails = []
_orig_verify_mail = _es_v.__class__.send_verification_email
async def _fake_verify_mail(**kw):
    _otp_mails.append(kw)
    return True
_es_v.__class__.send_verification_email = classmethod(lambda cls, **kw: _fake_verify_mail(**kw))
_rl.reset("otp:cooldown:9888888888")
TestClient(app, client=("10.3.0.3", 1)).post("/api/v1/auth/request-otp", json={"phone": "9888888888"})
_es_v.__class__.send_verification_email = _orig_verify_mail
emailed_code = next((m["code"] for m in _otp_mails if m.get("to_email") == "hj@x.in"), None)
check("sign-in OTP copy reaches the verified inbox (still usable for login)", emailed_code is not None, _otp_mails)
r = TestClient(app, client=("10.3.0.4", 1)).post("/api/v1/auth/verify-signup", json={
    "email": "hj@x.in", "email_code": "000000", "phone": "9888888888", "phone_code": emailed_code or "000000"})
check("emailed OTP copy rejected as phone proof by verify-signup", r.status_code == 400, r.text)
check("verify-signup with emailed code left phone unverified", not db["users"].find_one({"_id": hj["_id"]}).get("is_phone_verified"))
_otp_mails.clear()
_es_v.__class__.send_verification_email = classmethod(lambda cls, **kw: _fake_verify_mail(**kw))
_rl.reset("otp:cooldown:9888888888")
TestClient(app, client=("10.3.0.5", 1)).post("/api/v1/auth/request-otp", json={"phone": "9888888888"})
_es_v.__class__.send_verification_email = _orig_verify_mail
emailed_code = _otp_mails[-1]["code"] if _otp_mails else None
r = TestClient(app, client=("10.3.0.6", 1)).post("/api/v1/auth/verify-otp", json={"phone": "9888888888", "otp": emailed_code or "000000"})
check("emailed OTP copy still signs the account holder in", r.status_code == 200, r.text)
check("emailed OTP copy does NOT mark the phone verified", not db["users"].find_one({"_id": hj["_id"]}).get("is_phone_verified"))
home = c.get("/api/v1/client/home", headers=H(r.json().get("access_token") if r.status_code == 200 else THJ)).json()
check("OTP-email hijack does NOT expose victim project", "victim house" not in json.dumps(home), json.dumps(home)[:200])
check("OTP-email hijack did not link victim record", db["customers"].find_one({"_id": "custV"}).get("user_id") in (None, ""))

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
STAGES8 = ["DOCUMENTS_COLLECTION", "DISCOM_NAME_CHANGE", "STRUCTURE_WORK", "WIRING_WORK", "CIVIL_WORK",
           "SUBSIDY_WORK", "DISCOM_NET_METERING", "ACCOUNT_BILL"]
check("timeline has the 8 department stages", [x["stage"] for x in tl.get("stages", [])] == STAGES8, tl)
check("project starts with the salesman collecting documents", ca.get("assigned_role") == "sales" and ca.get("stage") == "DOCUMENTS_COLLECTION", (ca.get("assigned_role"), ca.get("stage")))
check("no site work before its stage", db["work_assignments"].count_documents({"customer_id": "custA"}) == 0)
check("legacy project is exempt from the quotation gate", ca.get("quotation_waived") is True)

def stage_of(cid="custA"):
    d = db["customers"].find_one({"_id": cid})
    return d.get("stage"), d.get("assigned_role"), d.get("assigned_to")

# Sales assigns every department's employee on its own customer.
check("sales cannot assign on another sales' customer", c.patch("/api/v1/customers/custB", json={"structure_employee_id": site["_id"]}, headers=H(TS1)).status_code == 404)
check("sales cannot change the sales owner", c.patch("/api/v1/customers/custA", json={"sales_id": s2["_id"]}, headers=H(TS1)).status_code == 400)
check("assignee must be in the matching department", c.patch("/api/v1/customers/custA", json={"structure_employee_id": kedl["_id"]}, headers=H(TS1)).status_code == 400)
check("wiring slot rejects a civil employee", c.patch("/api/v1/customers/custA", json={"wiring_employee_id": civ["_id"]}, headers=H(TS1)).status_code == 400)
check("pending staff cannot be assigned", c.patch("/api/v1/customers/custA", json={"discom_employee_id": pending["_id"]}, headers=H(TS1)).status_code == 400)
r = c.patch("/api/v1/customers/custA", json={"discom_employee_id": kedl["_id"], "structure_employee_id": site["_id"],
            "wiring_employee_id": wir["_id"], "civil_employee_id": civ["_id"], "subsidy_employee_id": sub["_id"],
            "account_employee_id": acc["_id"]}, headers=H(TS1))
check("sales assigns all departments on own customer (legacy KEDL/site staff count as Discom/Structure)",
      r.status_code == 200 and r.json().get("discom_employee_name") == kedl["name"] and r.json().get("account_employee_id") == acc["_id"], r.text[:200])
check("assigned employees notified", db["notifications"].find_one({"user_id": wir["_id"], "target_id": "custA"}) is not None)
r = c.patch("/api/v1/customers/custB", json={"site_employee_id": site["_id"]}, headers=H(TS2))
check("old app field site_employee_id maps to Structure", r.status_code == 200 and r.json().get("structure_employee_id") == site["_id"], r.text[:200])

# 1 → 2: documents done hands off to Discom and opens the name-change files.
check("sales cannot toggle another department's stage", c.post("/api/v1/customers/custA/timeline", json={"stage": "STRUCTURE_WORK", "done": True}, headers=H(TS1)).status_code == 404)
r = c.post("/api/v1/customers/custA/timeline", json={"stage": "DOCUMENTS_COLLECTION", "done": True}, headers=H(TS1))
check("salesman completes documents collection", r.status_code == 200, r.text[:200])
check("documents → Discom hand-off", stage_of() == ("DISCOM_NAME_CHANGE", "discom", kedl["_id"]), stage_of())
kfiles = {f["file_type"]: f for f in db["kedl_files"].find({"customer_id": "custA"})}
check("name-change + load files opened (net metering not yet)", set(kfiles) == {"name_change", "load"} and kfiles["load"]["assigned_to"] == kedl["_id"])
check("sales cannot approve a discom file", c.post(f"/api/v1/kedl-files/{kfiles['name_change']['_id']}/status", json={"status": "approved"}, headers=H(TS1)).status_code == 403)
c.post(f"/api/v1/kedl-files/{kfiles['name_change']['_id']}/status", json={"status": "approved"}, headers=H(TKEDL))
check("name change alone does not finish the stage", stage_of()[0] == "DISCOM_NAME_CHANGE")
r = c.post(f"/api/v1/kedl-files/{kfiles['load']['_id']}/status", json={"status": "not_required"}, headers=H(TKEDL))
check("load marked not required → Structure hand-off", r.status_code == 200 and stage_of() == ("STRUCTURE_WORK", "structure", site["_id"]), stage_of())

# 3 → 5: each site trade completes its own stage and hands to the next trade.
works = {w["work_type"]: w for w in db["work_assignments"].find({"customer_id": "custA"})}
check("only the structure task exists, assigned to the structure employee", set(works) == {"structure"} and works["structure"]["assigned_to"] == site["_id"] and works["structure"]["status"] == "assigned")
_wl = c.get("/api/v1/work-assignments", headers=H(TWIR)).json()
_wl = _wl.get("items", []) if isinstance(_wl, dict) else _wl
check("wiring employee cannot see the structure task", all(w.get("id") != works["structure"]["_id"] for w in _wl))
check("wiring employee cannot open the structure task", c.get(f"/api/v1/work-assignments/{works['structure']['_id']}", headers=H(TWIR)).status_code == 404)
check("site cannot complete without photo proof", c.post(f"/api/v1/work-assignments/{works['structure']['_id']}/complete", headers=H(TSITE)).status_code == 400)
for wt, tk, nxt in (("structure", TSITE, ("WIRING_WORK", "wiring", wir["_id"])),
                    ("electrical", TWIR, ("CIVIL_WORK", "civil", civ["_id"])),
                    ("civil", TCIV, ("SUBSIDY_WORK", "subsidy", sub["_id"]))):
    w = db["work_assignments"].find_one({"customer_id": "custA", "work_type": wt})
    c.post(f"/api/v1/work-assignments/{w['_id']}/photos", files=[("files", ("p.png", png, "image/png"))], headers=H(tk))
    r = c.post(f"/api/v1/work-assignments/{w['_id']}/complete", headers=H(tk))
    check(f"{wt} completed by its own employee → {nxt[1]} hand-off", r.status_code == 200 and stage_of() == nxt, (r.text[:120], stage_of()))

# 6 → 8: subsidy, net metering, account.
check("subsidy employee sees the project in their list", any(x["id"] == "custA" for x in c.get("/api/v1/customers", headers=H(TSUB)).json()["items"]))
acc2 = mkuser("account", "9444444482", "acc2@x.in")
check("an unassigned account employee cannot see it", all(x["id"] != "custA" for x in c.get("/api/v1/customers", headers=H(tok(acc2))).json()["items"]))
check("account cannot complete the subsidy stage", c.post("/api/v1/customers/custA/timeline", json={"stage": "SUBSIDY_WORK", "done": True}, headers=H(TACC)).status_code == 404)
r = c.post("/api/v1/customers/custA/timeline", json={"stage": "SUBSIDY_WORK", "done": True, "remark": "PM Surya Ghar applied"}, headers=H(TSUB))
check("subsidy done → Discom net metering hand-off", r.status_code == 200 and stage_of() == ("DISCOM_NET_METERING", "discom", kedl["_id"]), stage_of())
check("stage remark saved on the timeline", next(x for x in r.json()["stages"] if x["stage"] == "SUBSIDY_WORK").get("remark") == "PM Surya Ghar applied")
net = db["kedl_files"].find_one({"customer_id": "custA", "file_type": "net"})
check("net-metering file opened at its stage", net is not None and net.get("assigned_to") == kedl["_id"])
r = c.post(f"/api/v1/kedl-files/{net['_id']}/status", json={"status": "approved"}, headers=H(TKEDL))
ca = db["customers"].find_one({"_id": "custA"})
check("net approval → system live + Account hand-off", r.status_code == 200 and ca.get("is_system_live") and stage_of() == ("ACCOUNT_BILL", "account", acc["_id"]), stage_of())
r = c.post("/api/v1/customers/custA/timeline", json={"stage": "ACCOUNT_BILL", "done": True}, headers=H(TACC))
ca = db["customers"].find_one({"_id": "custA"})
check("account / bill done completes the project", r.status_code == 200 and ca.get("is_completed") and ca.get("stage") == "COMPLETED" and ca.get("progress") == 100, (ca.get("stage"), ca.get("progress")))
r = c.post("/api/v1/customers/custA/timeline", json={"stage": "WIRING_WORK", "done": False}, headers=H(TADM))
w = db["work_assignments"].find_one({"customer_id": "custA", "work_type": "electrical"})
check("admin reopens wiring → back with Wiring and task reopened", r.status_code == 200 and stage_of() == ("WIRING_WORK", "wiring", wir["_id"]) and w["status"] == "in_progress", (stage_of(), w["status"]))
t = c.post("/api/v1/client/tickets", json={"type": "inverter", "title": "Inverter error", "description": "Shows E05 fault"}, headers=H(TA)).json()
check("client ticket goes to the admin queue (no hardcoded staff)", t.get("assigned_to") is None and "Vikram" not in json.dumps(t), json.dumps(t)[:200])

# ── Tickets reach the installation trades they are assigned to ─────────────
check("wiring staff see no unassigned tickets", all(x.get("id") != t.get("id") for x in c.get("/api/v1/tickets", headers=H(TWIR)).json()))
check("wiring staff cannot open an unassigned ticket", c.get(f"/api/v1/tickets/{t['id']}", headers=H(TWIR)).status_code == 404)
check("admin assigns a client ticket to a wiring employee", c.post(f"/api/v1/tickets/{t['id']}/assign", json={"assigned_to": wir["_id"]}, headers=H(TADM)).status_code == 200)
check("assigned wiring employee sees the ticket", any(x.get("id") == t["id"] for x in c.get("/api/v1/tickets", headers=H(TWIR)).json()))
check("other trades still cannot see it", all(x.get("id") != t["id"] for x in c.get("/api/v1/tickets", headers=H(TCIV)).json())
      and c.get(f"/api/v1/tickets/{t['id']}", headers=H(TCIV)).status_code == 404)
r = c.post(f"/api/v1/tickets/{t['id']}/status", json={"status": "in_progress"}, headers=H(TWIR))
check("assigned wiring employee works the ticket", r.status_code == 200, r.text[:200])
check("only an admin closes tickets", c.post(f"/api/v1/tickets/{t['id']}/status", json={"status": "closed"}, headers=H(TWIR)).status_code == 403)
check("subsidy staff have no ticket access", c.get("/api/v1/tickets", headers=H(TSUB)).status_code == 403)

# ── Any employee can create a lead ─────────────────────────────────────────
LEAD = {"name": "Neighbour Ji", "phone": "9876500001", "area": "Sector 12", "kw": 3}
r = c.post("/api/v1/leads", json={**LEAD, "status": "converted", "source": "x"}, headers=H(TWIR))
ld = r.json()
check("wiring employee creates a lead", r.status_code == 201, r.text[:200])
check("referred lead goes to the sales pool as new, marked with the referrer",
      ld.get("assigned_sales_id") is None and ld.get("status") == "new" and ld.get("referred_by_name") == wir["name"]
      and ld.get("source", "").startswith("Referral:"), ld)
check("admins notified of the referral", db["notifications"].find_one({"target_role": "admin", "target_id": ld.get("id")}) is not None)
check("every salesman sees the referred lead in the pool", any(x["id"] == ld["id"] for x in c.get("/api/v1/leads", headers=H(TS2)).json()["items"]))
check("duplicate referral of an open lead is refused", c.post("/api/v1/leads", json=LEAD, headers=H(TACC)).status_code == 400)
check("discom and subsidy staff can refer leads too",
      c.post("/api/v1/leads", json={**LEAD, "phone": "9876500002"}, headers=H(TKEDL)).status_code == 201
      and c.post("/api/v1/leads", json={**LEAD, "phone": "9876500003"}, headers=H(TSUB)).status_code == 201)
ref = c.get("/api/v1/leads/referred", headers=H(TWIR)).json()
check("referrer tracks only their own referrals (no phone numbers)", [x["id"] for x in ref] == [ld["id"]] and "phone" not in ref[0], ref)
check("non-sales staff still cannot browse the lead pool", c.get("/api/v1/leads", headers=H(TWIR)).status_code == 403)
check("non-sales staff cannot open or edit leads", c.get(f"/api/v1/leads/{ld['id']}", headers=H(TWIR)).status_code == 403
      and c.patch(f"/api/v1/leads/{ld['id']}", json={"status": "lost"}, headers=H(TWIR)).status_code == 403)
check("clients cannot create leads", c.post("/api/v1/leads", json={**LEAD, "phone": "9876500004"}, headers=H(TA)).status_code == 403)
r = c.post("/api/v1/leads", json={**LEAD, "phone": "9876500005"}, headers=H(TS1))
check("a salesman's own lead stays assigned to them", r.status_code == 201 and r.json().get("assigned_sales_id") == s1["_id"] and r.json().get("referred_by_id") is None)

# ── Quotations ──────────────────────────────────────────────────────────────
from app.services import workflow as _wf
clientQ = mkuser("client", "9300000001", "q@x.in", is_phone_verified=True)
db["customers"].insert_one({"_id": "custQ", "id": "custQ", "name": "Quote Cust", "phone": clientQ["phone"], "mobile": clientQ["phone"],
                            "address": "q house", "sales_id": s1["_id"], "final_price": 0, "documents": {}, "created_at": now})
_wf.on_customer_created("custQ")
TQ = tok(clientQ)
QUOTE = {"customer_id": "custQ", "capacity_kw": 5, "load_kw": 5, "project_cost": 250000, "discom_charges": 3000, "file_charges": 625,
         "items": {"solar_module": {"make": "Waaree", "capacity": "540 W", "quantity": 10, "technology": "Mono PERC"},
                   "solar_inverter": {"make": "Growatt", "capacity": "5 kW", "quantity": 1},
                   "ac_wire": {"make": "Polycab", "size": "4 sq mm", "quantity": 30},
                   "civil_work": {"size": "4 pedestals"}},
         "other_items": [{"title": "Monitoring", "details": "WiFi dongle"}], "remark": "Includes 5-year AMC"}
check("client cannot create quotations", c.post("/api/v1/quotations", json=QUOTE, headers=H(TQ)).status_code == 403)
check("other sales cannot quote this customer", c.post("/api/v1/quotations", json=QUOTE, headers=H(TS2)).status_code == 404)
check("site staff cannot quote", c.post("/api/v1/quotations", json=QUOTE, headers=H(TSITE)).status_code == 403)
check("unknown quotation item rejected", c.post("/api/v1/quotations", json={**QUOTE, "items": {"gold_panel": {}}}, headers=H(TS1)).status_code == 422)
check("remark is required", c.post("/api/v1/quotations", json={**QUOTE, "remark": "  "}, headers=H(TS1)).status_code == 422)
check("documents stage blocked until a quotation is approved", c.post("/api/v1/customers/custQ/timeline", json={"stage": "DOCUMENTS_COLLECTION", "done": True}, headers=H(TS1)).status_code == 400)
r = c.post("/api/v1/quotations", json=QUOTE, headers=H(TS1))
q1 = r.json()
check("salesman sends a quotation", r.status_code == 201 and q1.get("status") == "sent" and q1.get("version") == 1 and q1.get("total_amount") == 253625, r.text[:200])
check("client notified of the quotation", db["notifications"].find_one({"user_id": clientQ["_id"], "target_id": q1.get("id")}) is not None)
mine = c.get("/api/v1/quotations/mine", headers=H(TQ)).json()
check("client sees the quotation", [x["id"] for x in mine] == [q1["id"]])
check("another client cannot see it", all(x["id"] != q1["id"] for x in c.get("/api/v1/quotations/mine", headers=H(TB)).json()))
check("another client cannot approve it", c.post(f"/api/v1/quotations/{q1['id']}/approve", headers=H(TB)).status_code == 404)
check("staff cannot approve on the client's behalf", c.post(f"/api/v1/quotations/{q1['id']}/approve", headers=H(TADM)).status_code == 403)
check("site staff cannot read quotations (prices)", c.get("/api/v1/quotations", params={"customer_id": "custQ"}, headers=H(TSITE)).status_code == 403)
check("reject needs a remark", c.post(f"/api/v1/quotations/{q1['id']}/reject", json={"remark": ""}, headers=H(TQ)).status_code == 422)
r = c.post(f"/api/v1/quotations/{q1['id']}/reject", json={"remark": "Price too high, need Tata panels"}, headers=H(TQ))
check("client rejects with a remark", r.status_code == 200 and r.json().get("status") == "rejected" and r.json().get("client_remark") == "Price too high, need Tata panels")
check("salesman notified of the rejection", db["notifications"].find_one({"user_id": s1["_id"], "title": "Quotation rejected"}) is not None)
check("rejected quotation cannot then be approved", c.post(f"/api/v1/quotations/{q1['id']}/approve", headers=H(TQ)).status_code == 400)
r = c.post("/api/v1/quotations", json={**QUOTE, "project_cost": 240000, "revision_of": q1["id"]}, headers=H(TS1))
q2 = r.json()
check("salesman regenerates after rejection (version 2)", r.status_code == 201 and q2.get("version") == 2 and q2.get("revision_of") == q1["id"], r.text[:200])
q3 = c.post("/api/v1/quotations", json={**QUOTE, "project_cost": 235000}, headers=H(TADM)).json()
check("admin can also send a quotation; it supersedes the pending one",
      q3.get("version") == 3 and db["quotations"].find_one({"_id": q2["id"]})["status"] == "superseded")
check("client list hides superseded versions", [x["id"] for x in c.get("/api/v1/quotations/mine", headers=H(TQ)).json()] == [q3["id"], q1["id"]])
check("superseded quotation cannot be approved", c.post(f"/api/v1/quotations/{q2['id']}/approve", headers=H(TQ)).status_code == 400)
r = c.post(f"/api/v1/quotations/{q3['id']}/approve", headers=H(TQ))
cq = db["customers"].find_one({"_id": "custQ"})
check("client approves; quotation locked", r.status_code == 200 and r.json().get("status") == "approved" and r.json().get("locked") is True, r.text[:200])
check("approved values copied to the project", cq.get("approved_quotation_id") == q3["id"] and cq.get("final_price") == 23862500
      and cq.get("capacity_kw") == 5 and cq.get("panel_brand") == "Waaree" and cq.get("panel_count") == 10 and cq.get("panel_watt") == 540,
      {k: cq.get(k) for k in ("final_price", "capacity_kw", "panel_brand", "panel_count", "panel_watt")})
check("approved quotation cannot be approved/rejected again", c.post(f"/api/v1/quotations/{q3['id']}/approve", headers=H(TQ)).status_code == 400
      and c.post(f"/api/v1/quotations/{q3['id']}/reject", json={"remark": "changed my mind"}, headers=H(TQ)).status_code == 400)
check("no new quotation once approved (sales)", c.post("/api/v1/quotations", json=QUOTE, headers=H(TS1)).status_code == 400)
check("no new quotation once approved (admin)", c.post("/api/v1/quotations", json=QUOTE, headers=H(TADM)).status_code == 400)
check("quotations have no edit or delete route", c.patch(f"/api/v1/quotations/{q3['id']}", json={"project_cost": 1}, headers=H(TADM)).status_code == 405
      and c.delete(f"/api/v1/quotations/{q3['id']}", headers=H(TADM)).status_code == 405)
check("admin cannot change the approved price", c.patch("/api/v1/customers/custQ", json={"final_price": 100}, headers=H(TADM)).status_code == 400)
check("admin cannot change the approved specs", c.patch("/api/v1/customers/custQ", json={"capacity_kw": 9, "panel_brand": "X"}, headers=H(TADM)).status_code == 400)
check("unlocked fields stay editable", c.patch("/api/v1/customers/custQ", json={"address": "new q house"}, headers=H(TADM)).status_code == 200)
check("stored quotation unchanged", db["quotations"].find_one({"_id": q3["id"]})["project_cost"] == 235000)
r = c.post("/api/v1/customers/custQ/timeline", json={"stage": "DOCUMENTS_COLLECTION", "done": True}, headers=H(TS1))
check("after approval the documents stage can complete", r.status_code == 200 and stage_of("custQ")[1] == "discom", stage_of("custQ"))

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
r = TestClient(app, client=("10.8.1.1", 1)).post("/api/v1/auth/register", json={"name": "New Discom", "phone": "9012345671", "email": "nk@x.in", "password": "NewKedl1234", "role": "discom"})
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

# ── Forgot password: emailed link + code ────────────────────────────────────
from app.services.email_service import email_service as _es
_mails = []
async def _fake_reset_mail(cls_or_to=None, *a, **kw):
    _mails.append(kw)
    return True
_es.__class__.send_password_reset_email = classmethod(lambda cls, **kw: _fake_reset_mail(**kw))
fpu = mkuser("kedl", "9555555559", "fp@x.in", is_email_verified=False)
T_fp = tok(fpu)
fc = lambda n: TestClient(app, client=(f"10.9.{n}.1", 1))
r = fc(1).post("/api/v1/auth/forgot-password", json={"email": "nobody@x.in"})
r2 = fc(2).post("/api/v1/auth/forgot-password", json={"email": "FP@x.in"})
check("forgot-password gives the same answer for unknown and known emails", r.status_code == r2.status_code == 200 and r.json() == r2.json())
check("reset email sent only for the real account", len(_mails) == 1 and _mails[0]["to_email"] == "fp@x.in")
link = _mails[0]["link"]
reset_tok = link.split("#token=", 1)[1] if "#token=" in link else ""
check("reset link carries the token in the #fragment", link.startswith("https://") and len(reset_tok) >= 40)
check("reset token and code stored only as hashes", not db["password_resets"].find_one({"$or": [{"token_hash": reset_tok}, {"code_hash": _mails[0]["code"]}]}))
check("reset email resend is throttled", fc(3).post("/api/v1/auth/forgot-password", json={"email": "fp@x.in"}).status_code == 429)
check("reset rejects a forged token", fc(4).post("/api/v1/auth/reset-password", json={"token": "x" * 64, "new_password": "Reset1Pass"}).status_code == 400)
check("reset rejects a weak password without using the link", fc(5).post("/api/v1/auth/reset-password", json={"token": reset_tok, "new_password": "weakweak"}).status_code in (400, 422)
      and db["password_resets"].count_documents({"email": "fp@x.in", "consumed_at": None}) == 1)
r = fc(6).post("/api/v1/auth/reset-password", json={"token": reset_tok, "new_password": "Reset1Pass"})
check("reset link sets the new password", r.status_code == 200 and "access_token" not in r.json(), r.text[:200])
check("reset link works only once", fc(7).post("/api/v1/auth/reset-password", json={"token": reset_tok, "new_password": "Reset2Pass"}).status_code == 400)
check("reset signs out every existing session", c.get("/api/v1/auth/me", headers=H(T_fp)).status_code == 401)
check("old password rejected after reset", login("fp@x.in", ipaddr="10.9.8.1").status_code == 401)
check("new password accepted after reset", login("fp@x.in", "Reset1Pass", "10.9.8.2").status_code == 200)
check("reset marks the email verified", db["users"].find_one({"_id": fpu["_id"]}).get("is_email_verified") is True)
# 6-digit code path (desktop / link didn't open the app)
db["password_resets"].delete_many({})
from app.core import ratelimit as _rl
_rl.reset("forgot_pw:cooldown:fp@x.in")
fc(9).post("/api/v1/auth/forgot-password", json={"email": "fp@x.in"})
code_ = _mails[-1]["code"]
check("code reset rejects a wrong code", fc(10).post("/api/v1/auth/reset-password", json={"email": "fp@x.in", "code": "000000" if code_ != "000000" else "111111", "new_password": "Code1Reset"}).status_code == 400)
check("code cannot reset another account", fc(11).post("/api/v1/auth/reset-password", json={"email": "a@x.in", "code": code_, "new_password": "Code1Reset"}).status_code == 400)
r = fc(12).post("/api/v1/auth/reset-password", json={"email": "fp@x.in", "code": code_, "new_password": "Code1Reset"})
check("email + code resets the password", r.status_code == 200 and login("fp@x.in", "Code1Reset", "10.9.13.1").status_code == 200, r.text[:200])
db["password_resets"].delete_many({})
_rl.reset("forgot_pw:cooldown:fp@x.in")
fc(14).post("/api/v1/auth/forgot-password", json={"email": "fp@x.in"})
for i in range(5):
    fc(15 + i).post("/api/v1/auth/reset-password", json={"email": "fp@x.in", "code": f"99999{i}", "new_password": "Code2Reset"})
check("code is dead after 5 wrong guesses", fc(21).post("/api/v1/auth/reset-password", json={"email": "fp@x.in", "code": _mails[-1]["code"], "new_password": "Code2Reset"}).status_code in (400, 429))
gone = mkuser("client", "9555555558", "gone@x.in", deleted_at=now)
n_before = len(_mails)
_rl.reset("forgot_pw:cooldown:gone@x.in")
fc(22).post("/api/v1/auth/forgot-password", json={"email": "gone@x.in"})
check("no reset email for a deleted account", len(_mails) == n_before)
check("reset needs a token or email + code", fc(23).post("/api/v1/auth/reset-password", json={"new_password": "Reset1Pass"}).status_code == 400)

# ── Staff directory: the 7 departments ─────────────────────────────────────
legacy = mkuser("electrician", "9444444443", "el@x.in", trade="electrical")
wiring_list = c.get("/api/v1/teams/employees", params={"trade": "wiring"}, headers=H(TADM)).json()
ids_ = {e["id"] for e in wiring_list}
check("Wiring filter lists wiring and legacy electrician staff", wir["_id"] in ids_ and legacy["_id"] in ids_ and all(e.get("department") == "wiring" for e in wiring_list))
check("Discom filter includes legacy KEDL staff", kedl["_id"] in {e["id"] for e in c.get("/api/v1/teams/employees", params={"trade": "discom"}, headers=H(TADM)).json()})
check("Sales filter lists only sales", all(e.get("department") == "sales" for e in c.get("/api/v1/teams/employees", params={"trade": "sales"}, headers=H(TADM)).json()))
check("unknown department filter is empty", c.get("/api/v1/teams/employees", params={"trade": "plumbing"}, headers=H(TADM)).json() == [])
r = c.post("/api/v1/teams/employees", json={"name": "New Civil", "phone": "9100000011", "role": "civil", "password": "SitePass123"}, headers=H(TADM))
check("admin creates a Civil employee with a password", r.status_code == 201 and r.json().get("role") == "civil" and r.json().get("employee_no", "").startswith("EMP-CVL"), r.text[:200])
check("new employee can sign in with that password", login("9100000011", "SitePass123", "10.8.3.1").status_code == 200)
check("legacy role names are not created as-is", c.post("/api/v1/teams/employees", json={"name": "Legacy Guy", "phone": "9100000012", "role": "office_staff"}, headers=H(TADM)).json().get("role") == "sales")
check("service is no longer a department", c.post("/api/v1/teams/employees", json={"name": "Svc Guy", "phone": "9100000013", "role": "service"}, headers=H(TADM)).status_code == 400)
for i, dept in enumerate(("sales", "discom", "structure", "wiring", "civil", "subsidy", "account")):
    r = TestClient(app, client=(f"10.7.{i}.9", 1)).post("/api/v1/auth/register", json={"name": f"New {dept}", "phone": f"92000000{i:02d}",
        "email": f"new{dept}@x.in", "password": "NewStaff123", "role": dept})
    check(f"sign-up offers {dept} (pending approval)", r.status_code == 201 and db["users"].find_one({"email": f"new{dept}@x.in"})["approval_status"] == "pending", r.text[:150])
r = TestClient(app, client=("10.7.20.9", 1)).post("/api/v1/auth/register", json={"name": "Old Kedl", "phone": "9200000099",
    "email": "oldk@x.in", "password": "NewStaff123", "role": "service"})
check("sign-up no longer offers service", r.status_code == 400)

# ── Super Admin: administrator accounts ────────────────────────────────────
NEW_ADMIN = {"name": "Manish", "email": "manish@x.in", "phone": "9400000001", "password": "AdminPass123"}
check("weak admin password rejected", c.post("/api/v1/users/admins", json={**NEW_ADMIN, "password": "password"}, headers=H(TADM)).status_code in (400, 422))
r = c.post("/api/v1/users/admins", json=NEW_ADMIN, headers=H(TADM))
na = r.json()
check("super admin creates an admin account", r.status_code == 201 and na.get("role") == "admin" and not na.get("is_superadmin") and "password_hash" not in na, r.text[:200])
check("duplicate admin email rejected", c.post("/api/v1/users/admins", json={**NEW_ADMIN, "phone": "9400000002"}, headers=H(TADM)).status_code == 400)
r = login("manish@x.in", "AdminPass123", "10.6.0.1")
check("new admin signs in", r.status_code == 200 and r.json().get("user", {}).get("role") == "admin", r.text[:200])
TNA = r.json().get("access_token")
check("admin cannot create admins", c.post("/api/v1/users/admins", json={**NEW_ADMIN, "email": "x2@x.in", "phone": "9400000003"}, headers=H(TNA)).status_code == 403)
check("admin cannot list admins", c.get("/api/v1/users/admins", headers=H(TNA)).status_code == 403)
check("admin cannot reset another admin's password", c.post(f"/api/v1/users/admins/{admin_doc['_id']}/password", json={"new_password": "Hijack1234"}, headers=H(TNA)).status_code == 403)
check("sales cannot create admins", c.post("/api/v1/users/admins", json=NEW_ADMIN, headers=H(TS1)).status_code == 403)
check("super admin lists admins", {a["email"] for a in c.get("/api/v1/users/admins", headers=H(TADM)).json()} >= {"boss@solarpro.in", "manish@x.in"})
check("password reset only targets admin accounts", c.post(f"/api/v1/users/admins/{s1['_id']}/password", json={"new_password": "NewPass1234"}, headers=H(TADM)).status_code == 404)
r = c.post(f"/api/v1/users/admins/{na['id']}/password", json={"new_password": "Fresh1Admin"}, headers=H(TADM))
check("super admin sets an admin's password", r.status_code == 200, r.text[:200])
check("admin's old sessions are signed out", c.get("/api/v1/auth/me", headers=H(TNA)).status_code == 401)
check("old admin password rejected", login("manish@x.in", "AdminPass123", "10.6.0.2").status_code == 401)
check("new admin password works", login("manish@x.in", "Fresh1Admin", "10.6.0.3").status_code == 200)
_rl.reset("forgot_pw:cooldown:manish@x.in")
n_before = len(_mails)
fc(40).post("/api/v1/auth/forgot-password", json={"email": "manish@x.in"})
check("admins can use forgot-password", len(_mails) == n_before + 1 and _mails[-1]["to_email"] == "manish@x.in")
check("super admin deactivates an admin", c.patch(f"/api/v1/users/{na['id']}", json={"is_active": False}, headers=H(TADM)).status_code == 200
      and login("manish@x.in", "Fresh1Admin", "10.6.0.4").status_code in (401, 403))

# ── Customers without a sales owner are admin-only ──────────────────────────
db["customers"].insert_one({"_id": "custU", "id": "custU", "name": "Unowned", "phone": "9876500001", "mobile": "9876500001",
                            "address": "unowned house", "sales_id": None, "documents": {}, "created_at": now})
listed = c.get("/api/v1/customers?page_size=100", headers=H(TS1)).json()
check("sales list excludes customers with no sales owner", "custU" not in json.dumps(listed), json.dumps(listed)[:200])
check("sales cannot read an unowned customer", c.get("/api/v1/customers/custU", headers=H(TS1)).status_code == 404)
check("sales cannot edit an unowned customer", c.patch("/api/v1/customers/custU", json={"notes": "x"}, headers=H(TS1)).status_code == 404)
check("sales cannot read an unowned customer's KYC", c.get("/api/v1/customers/custU/documents", headers=H(TS1)).status_code == 404)
check("admin still sees the unowned customer", c.get("/api/v1/customers/custU", headers=H(TADM)).status_code == 200)

# ── Payment status changes are compare-and-set (double-click race) ──────────
import app.api.v1.payments as _P
db["payments"].insert_one({"_id": "payRace", "id": "payRace", "customer_id": "custA", "amount": 100,
                           "status": "pending", "created_at": now})
_stale = dict(db["payments"].find_one({"_id": "payRace"}))
_orig_payment = _P._payment
_P._payment = lambda pid: dict(_stale)  # both requests read the row before either wrote
r1 = c.post("/api/v1/payments/payRace/verify", headers=H(TADM))
r2 = c.post("/api/v1/payments/payRace/verify", headers=H(TADM))
r3 = c.post("/api/v1/payments/payRace/reject", json={"reason": "dup"}, headers=H(TADM))
_P._payment = _orig_payment
check("first verify of a payment succeeds", r1.status_code == 200, r1.text)
check("racing second verify is refused", r2.status_code == 400, r2.text)
check("racing reject after verify is refused", r3.status_code == 400 and db["payments"].find_one({"_id": "payRace"})["status"] == "verified", r3.text)

# ── Misc hardening ──────────────────────────────────────────────────────────
h = c.get("/api/v1/health").headers
check("security headers present", h.get("x-frame-options") == "DENY" and h.get("x-content-type-options") == "nosniff")
check("no fake payments seeded for new client", c.get("/api/v1/client/payments", headers=H(TB)).json() == [])
check("no fake teams", c.get("/api/v1/teams", headers=H(TADM)).json() == [])

client.__exit__(None, None, None)
failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
sys.exit(1 if failed else 0)
