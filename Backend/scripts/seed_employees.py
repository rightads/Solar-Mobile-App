import sys, os
sys.path.insert(0, os.path.abspath("."))
from app.db.mongo import mongo_create_employee, get_mongo_db

_seed_pw = os.getenv("DEFAULT_SEED_PASSWORD", "")
if len(_seed_pw) < 8:
    raise SystemExit("DEFAULT_SEED_PASSWORD must be set to a strong password (8+ chars) before seeding.")
default_seed_password = _seed_pw

employees = [
    {
        "id": "emp-sls-042",
        "name": "Rajesh Sharma",
        "phone": "9829012345",
        "email": "rajesh.sharma@solarpro.in",
        "employee_no": "EMP-SLS-042",
        "role": "sales",
        "trade": "sales",
        "team": "Sales Team North",
        "password": default_seed_password,
    },
    {
        "id": "emp-srv-104",
        "name": "Vikram Singh",
        "phone": "9829054321",
        "email": "vikram.singh@solarpro.in",
        "employee_no": "EMP-SRV-104",
        "role": "technician",
        "trade": "service",
        "team": "Service & Maintenance Team A",
        "password": default_seed_password,
    },
    {
        "id": "emp-kedl-007",
        "name": "Amit Patel",
        "phone": "9829076543",
        "email": "amit.patel@solarpro.in",
        "employee_no": "EMP-KEDL-007",
        "role": "kedl",
        "trade": "kedl",
        "team": "KEDL Liaison Team",
        "password": default_seed_password,
    },
    {
        "id": "emp-site-015",
        "name": "Sunil Kumar",
        "phone": "9829098765",
        "email": "sunil.kumar@solarpro.in",
        "employee_no": "EMP-SITE-015",
        "role": "labour",
        "trade": "structure",
        "team": "Structure & Mounting Team 1",
        "password": default_seed_password,
    },
]

for emp in employees:
    try:
        created = mongo_create_employee({**emp, "password": default_seed_password})
    except ValueError as e:
        print(f"Skipped {emp.get('name')}: {e}")
        continue
    print(f"Created/Synced employee: {created['name']} ({created.get('employee_no')}) | Role: {created['role']} | Email: {created.get('email')} | Phone: {created['phone']}")

db = get_mongo_db()
print("Total DB users count:", db["users"].count_documents({}))

