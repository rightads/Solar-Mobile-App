import sys, os
from datetime import datetime, timezone, timedelta
sys.path.insert(0, os.path.abspath("."))

from app.db.mongo import get_mongo_db, mongo_create_user, _format_mongo_doc
from app.core.security import hash_password, normalize_phone

db = get_mongo_db()
if db is None:
    print("Error: MongoDB connection failed")
    sys.exit(1)

users_col = db["users"]
customers_col = db["customers"]
kedl_col = db["kedl_files"]
assignments_col = db["work_assignments"]
tickets_col = db["tickets"]
leads_col = db["leads"]
payments_col = db["payments"]

now = datetime.now(timezone.utc)
client_pwd_hash = hash_password(os.getenv("DEFAULT_CLIENT_PASSWORD", ""))

# ── 1. Create/Sync Customer Users with Hashed Passwords ────────────────────────
customers_data = [
    {
        "id": "f31eca21-759d-428a-8367-40310494460a",
        "name": "Aryan Singh Jadaun",
        "phone": "9837039028",
        "email": "aryansinghjadaun@gmail.com",
        "address": "Plot 42, Sunrise Enclave, Sector 14, Jaipur, Rajasthan",
        "stage": "STRUCTURE_WORK",
        "kw": 5.5,
        "final_price": 25000000,
        "panel_brand": "Tata Power Solar 550W Mono PERC",
        "panel_watt": 550,
        "panel_count": 10,
        "inverter_brand": "Growatt 6kW Hybrid Inverter",
        "structure_type": "High-Rise Heavy Duty Galvanized Structure",
    },
    {
        "id": "cust_101",
        "name": "Sunil Verma",
        "phone": "9829011223",
        "email": "sunil.verma@gmail.com",
        "address": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "stage": "KEDL_PROCESS",
        "kw": 6.0,
        "final_price": 28000000,
        "panel_brand": "Waaree 540W Mono PERC",
        "panel_watt": 540,
        "panel_count": 11,
        "inverter_brand": "Growatt 6kW On-Grid Inverter",
        "structure_type": "Standard Rooftop GI Structure",
    },
    {
        "id": "cust_103",
        "name": "Pooja Agarwal",
        "phone": "9414055555",
        "email": "pooja.agarwal@gmail.com",
        "address": "15 Civil Lines, Ajmer, Rajasthan",
        "stage": "HANDED_OVER",
        "kw": 4.5,
        "final_price": 22000000,
        "panel_brand": "Adani Solar 450W Mono",
        "panel_watt": 450,
        "panel_count": 10,
        "inverter_brand": "Luminous 5kW Grid-Tie Inverter",
        "structure_type": "Elevated Super Structure",
    },
    {
        "id": "cust_104",
        "name": "Ramesh Gupta",
        "phone": "9828012345",
        "email": "ramesh.gupta@gmail.com",
        "address": "B-102, Vaishali Nagar, Jaipur, Rajasthan",
        "stage": "SALE_CONFIRMED",
        "kw": 3.3,
        "final_price": 18000000,
        "panel_brand": "Tata Power Solar 550W",
        "panel_watt": 550,
        "panel_count": 6,
        "inverter_brand": "Growatt 3.3kW Inverter",
        "structure_type": "Tin-Shed Mount Flush",
    },
]

for c in customers_data:
    user_doc = {
        "_id": c["id"],
        "id": c["id"],
        "name": c["name"],
        "phone": normalize_phone(c["phone"]),
        "email": c["email"].lower(),
        "role": "client",
        "password_hash": client_pwd_hash,
        "is_active": True,
        "is_email_verified": True,
        "approval_status": "approved",
        "updated_at": now,
    }
    user_doc_set = {k: v for k, v in user_doc.items() if k != "_id"}
    users_col.update_one(
        {"$or": [{"_id": c["id"]}, {"phone": normalize_phone(c["phone"])}, {"email": c["email"].lower()}]},
        {"$set": user_doc_set, "$setOnInsert": {"_id": c["id"], "created_at": now, "last_login_at": None}},
        upsert=True
    )

    cust_doc = {
        "_id": c["id"],
        "id": c["id"],
        "user_id": c["id"],
        "name": c["name"],
        "phone": normalize_phone(c["phone"]),
        "mobile": normalize_phone(c["phone"]),
        "email": c["email"].lower(),
        "address": c["address"],
        "capacity_kw": float(c["kw"]),
        "kw": float(c["kw"]),
        "final_price": int(c["final_price"]),
        "total_amount": int(c["final_price"]),
        "phase": "single",
        "panel_brand": c["panel_brand"],
        "panel_watt": int(c["panel_watt"]),
        "panel_count": int(c["panel_count"]),
        "inverter_brand": c["inverter_brand"],
        "structure_type": c["structure_type"],
        "stage": c["stage"],
        "sales_id": "emp-sls-042",
        "sales_name": "Rajesh Sharma",
        "assigned_sales_name": "Rajesh Sharma",
        "assigned_sales_phone": "+91 98290 12345",
        "assigned_sales_emp_no": "EMP-SLS-042",
        "created_at": now,
        "updated_at": now,
    }
    cust_doc_set = {k: v for k, v in cust_doc.items() if k != "_id"}
    customers_col.update_one(
        {"$or": [{"_id": c["id"]}, {"phone": normalize_phone(c["phone"])}]},
        {"$set": cust_doc_set, "$setOnInsert": {"_id": c["id"]}},
        upsert=True
    )
    print(f"Customer User created/synced: {c['name']} | Phone: {c['phone']} | Email: {c['email']} | Stage: {c['stage']}")

# ── 2. Seed KEDL Tracking Files for Sunil Verma ──────────────────────────────
kedl_files_data = [
    {
        "_id": "kedl_file_101_name",
        "id": "kedl_file_101_name",
        "customer_id": "cust_101",
        "customer_name": "Sunil Verma",
        "customer_phone": "9829011223",
        "location": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "file_type": "name_change",
        "status": "approved",
        "application_no": "NC-JPR-2026-8812",
        "assigned_to": "emp-kedl-007",
        "assigned_employee_name": "Amit Patel",
        "assigned_employee_emp_no": "EMP-KEDL-007",
        "remarks": "Name change updated in Discom ledger to Sunil Verma.",
        "submitted_on": (now - timedelta(days=15)).strftime("%Y-%m-%d"),
        "approved_on": (now - timedelta(days=5)).strftime("%Y-%m-%d"),
        "demands": [],
        "created_at": now - timedelta(days=15),
        "updated_at": now - timedelta(days=5),
    },
    {
        "_id": "kedl_file_101_load",
        "id": "kedl_file_101_load",
        "customer_id": "cust_101",
        "customer_name": "Sunil Verma",
        "customer_phone": "9829011223",
        "location": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "file_type": "load",
        "status": "demand_paid",
        "application_no": "LI-JPR-2026-9043",
        "demand_amount": 4500,
        "demand_notice_ref": "DEM-LI-9043",
        "demand_paid_date": (now - timedelta(days=1)).strftime("%Y-%m-%d"),
        "assigned_to": "emp-kedl-007",
        "assigned_employee_name": "Amit Patel",
        "assigned_employee_emp_no": "EMP-KEDL-007",
        "remarks": "Load enhancement from 3kW to 6kW paid and verified.",
        "submitted_on": (now - timedelta(days=10)).strftime("%Y-%m-%d"),
        "demands": [
            {
                "id": "demand_101_1",
                "description": "Load extension processing fee and security deposit",
                "amount_paise": 450000,
                "amount": 4500,
                "status": "paid",
                "due_date": (now - timedelta(days=2)).isoformat(),
                "paid_on": (now - timedelta(days=1)).isoformat(),
            }
        ],
        "created_at": now - timedelta(days=10),
        "updated_at": now - timedelta(days=1),
    },
    {
        "_id": "kedl_file_101_net",
        "id": "kedl_file_101_net",
        "customer_id": "cust_101",
        "customer_name": "Sunil Verma",
        "customer_phone": "9829011223",
        "location": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "file_type": "net",
        "status": "demand_raised",
        "application_no": "NET-JPR-2026-1120",
        "demand_amount": 2500,
        "demand_notice_ref": "DEM-NET-1120",
        "assigned_to": "emp-kedl-007",
        "assigned_employee_name": "Amit Patel",
        "assigned_employee_emp_no": "EMP-KEDL-007",
        "remarks": "Bi-directional net meter sync application in review. Demand raised.",
        "submitted_on": (now - timedelta(days=6)).strftime("%Y-%m-%d"),
        "demands": [
            {
                "id": "demand_101_2",
                "description": "Bi-directional net meter testing and inspection fee",
                "amount_paise": 250000,
                "amount": 2500,
                "status": "open",
                "due_date": (now + timedelta(days=5)).isoformat(),
            }
        ],
        "created_at": now - timedelta(days=6),
        "updated_at": now,
    },
]

for kf in kedl_files_data:
    kedl_col.update_one({"_id": kf["_id"]}, {"$set": kf}, upsert=True)
print(f"KEDL tracking files seeded: {len(kedl_files_data)}")

# ── 3. Seed Work Assignments for Site Labour Team ────────────────────────────
work_assignments_data = [
    {
        "_id": "job_struct_001",
        "id": "job_struct_001",
        "customer_id": "f31eca21-759d-428a-8367-40310494460a",
        "customer_name": "Aryan Singh Jadaun",
        "customer_phone": "9837039028",
        "location": "Plot 42, Sunrise Enclave, Sector 14, Jaipur, Rajasthan",
        "work_type": "structure",
        "team_name": "Structure & Mounting Team 1",
        "lead_name": "Sunil Kumar",
        "lead_phone": "9829098765",
        "start_date": now.strftime("%Y-%m-%d"),
        "end_date": (now + timedelta(days=2)).strftime("%Y-%m-%d"),
        "status": "in_progress",
        "notes": "High-rise galvanized mounting installation. Column grouting in progress.",
        "created_at": now,
        "updated_at": now,
    },
    {
        "_id": "job_elec_002",
        "id": "job_elec_002",
        "customer_id": "cust_101",
        "customer_name": "Sunil Verma",
        "customer_phone": "9829011223",
        "location": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "work_type": "electrical",
        "team_name": "Service & Maintenance Team A",
        "lead_name": "Vikram Singh",
        "lead_phone": "9829054321",
        "start_date": (now - timedelta(days=5)).strftime("%Y-%m-%d"),
        "end_date": (now - timedelta(days=3)).strftime("%Y-%m-%d"),
        "status": "completed",
        "notes": "DC cabling, combiner box, and dual copper earthing rods completed.",
        "created_at": now - timedelta(days=5),
        "updated_at": now - timedelta(days=3),
    },
]

for wa in work_assignments_data:
    assignments_col.update_one({"_id": wa["_id"]}, {"$set": wa}, upsert=True)
print(f"Work assignments seeded: {len(work_assignments_data)}")

# ── 4. Seed Service Tickets for Technical Support ────────────────────────────
tickets_data = [
    {
        "_id": "tck_1001",
        "id": "tck_1001",
        "ticket_no": "TCK-2026-1001",
        "customer_id": "cust_101",
        "customer_name": "Sunil Verma",
        "customer_phone": "9829011223",
        "customer_address": "Plot 42, Malviya Nagar, Jaipur, Rajasthan",
        "type": "inverter",
        "title": "Inverter blinking red with error code",
        "description": "Growatt inverter display shows blinking warning LED and stopped exporting power.",
        "error_code": "E-029: Grid Overvoltage",
        "status": "in_progress",
        "priority": "urgent",
        "assigned_to": "emp-srv-104",
        "assigned_staff": "Vikram Singh",
        "assigned_staff_emp_no": "EMP-SRV-104",
        "images": ["inverter_error_display.jpg"],
        "comments": [
            {
                "id": "cmt_01",
                "author_name": "Sunil Verma",
                "author_role": "client",
                "message": "Please send a service technician urgently, solar export halted.",
                "created_at": (now - timedelta(hours=3)).isoformat(),
            },
            {
                "id": "cmt_02",
                "author_name": "Vikram Singh",
                "author_role": "technician",
                "message": "Technician dispatched to inspect AC voltage tapping and grid tolerance.",
                "created_at": (now - timedelta(hours=1)).isoformat(),
            }
        ],
        "created_at": now - timedelta(hours=4),
        "updated_at": now - timedelta(hours=1),
    },
    {
        "_id": "tck_1002",
        "id": "tck_1002",
        "ticket_no": "TCK-2026-1002",
        "customer_id": "cust_103",
        "customer_name": "Pooja Agarwal",
        "customer_phone": "9414055555",
        "customer_address": "15 Civil Lines, Ajmer, Rajasthan",
        "type": "structure",
        "title": "Mounting Bracket Vibration on West Roof Panel",
        "description": "The aluminum mounting bracket makes a light rattling noise during high wind gusts.",
        "status": "open",
        "priority": "normal",
        "assigned_to": "emp-srv-104",
        "assigned_staff": "Vikram Singh",
        "assigned_staff_emp_no": "EMP-SRV-104",
        "images": ["bracket_clamp.jpg"],
        "comments": [],
        "created_at": now - timedelta(days=1),
        "updated_at": now - timedelta(days=1),
    },
]

for t in tickets_data:
    tickets_col.update_one({"_id": t["_id"]}, {"$set": t}, upsert=True)
print(f"Service tickets seeded: {len(tickets_data)}")

# ── 5. Seed Leads for Sales Representative Rajesh Sharma ─────────────────────
leads_data = [
    {
        "_id": "lead_001",
        "id": "lead_001",
        "name": "Kailash Sharma",
        "phone": "9829123456",
        "area": "Mansarovar, Jaipur",
        "address": "120/45, Sector 12, Mansarovar, Jaipur",
        "kw": 5.0,
        "status": "new",
        "source": "Direct Referral",
        "assigned_sales_id": "emp-sls-042",
        "sales_id": "emp-sls-042",
        "assigned_sales_name": "Rajesh Sharma",
        "created_at": now - timedelta(days=2),
        "updated_at": now - timedelta(days=2),
    },
    {
        "_id": "lead_002",
        "id": "lead_002",
        "name": "Deepak Meena",
        "phone": "9829234567",
        "area": "Vaishali Nagar, Jaipur",
        "address": "Plot 18, Amrapali Circle, Vaishali Nagar, Jaipur",
        "kw": 4.0,
        "status": "in_progress",
        "source": "Website Form",
        "assigned_sales_id": "emp-sls-042",
        "sales_id": "emp-sls-042",
        "assigned_sales_name": "Rajesh Sharma",
        "created_at": now - timedelta(days=4),
        "updated_at": now - timedelta(days=1),
    },
    {
        "_id": "lead_003",
        "id": "lead_003",
        "name": "Sunita Choudhary",
        "phone": "9829345678",
        "area": "Vidhyadhar Nagar, Jaipur",
        "address": "Sector 3, Vidhyadhar Nagar, Jaipur",
        "kw": 3.0,
        "status": "quoted",
        "source": "Solar Campaign Expo",
        "assigned_sales_id": "emp-sls-042",
        "sales_id": "emp-sls-042",
        "assigned_sales_name": "Rajesh Sharma",
        "created_at": now - timedelta(days=7),
        "updated_at": now - timedelta(days=2),
    },
]

for l in leads_data:
    leads_col.update_one({"_id": l["_id"]}, {"$set": l}, upsert=True)
print(f"Sales leads seeded: {len(leads_data)}")

print("\n=== COMPLETE DATABASE STATUS ===")
print("Total Users:", users_col.count_documents({}))
print("Total Customers:", customers_col.count_documents({}))
print("Total Leads:", leads_col.count_documents({}))
print("Total KEDL Files:", kedl_col.count_documents({}))
print("Total Work Assignments:", assignments_col.count_documents({}))
print("Total Service Tickets:", tickets_col.count_documents({}))
print("Total Payments:", payments_col.count_documents({}))
