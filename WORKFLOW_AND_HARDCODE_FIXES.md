# SolarPro — Application Workflow & Hardcode Fixes Specification

**Date:** November 12, 2026  
**Project:** SolarPro (FastAPI + MongoDB Backend & Flutter Mobile/Web App)  
**Scope:** End-to-End Business Workflow Fixes, 10-Stage Lifecycle Synchronization, 4-Employee Automatic Handoff, Hardcoded Data Removal, and Broken Endpoint Repairs *(Security issues are documented separately in `SECURITY_AUDIT_REPORT.md`)*.

---

## 1. Target Application Workflow (How the App Must Work)

1. **Client Onboarding & Portal:**
   - The **Client** signs up in the application (`role = "client"`), completes verification, and lands on the **Client Dashboard**.
   - From the Client Dashboard, the Client can view their **10-Stage Project Timeline**, see their **Assigned Employee / Project Officer**, **Submit Milestone Payments**, or **Raise a Service Ticket**.
   - Initially, no employee is assigned (`Pending Assignment`) until the **Admin** assigns an employee/team.

2. **4 Employee Roles & Sequential Automatic Handoff:**
   - There are **4 types of Employees** (`Salesman`, `Site Operations`, `KEDL Liaison`, `Service Engineer`).
   - All 4 employee roles participate in the customer's lifecycle.
   - **Automatic Workflow Shift:** Whenever one employee finishes all of their assigned tasks and marks their stages **Done**, the backend must **automatically shift the active workflow to the next employee** in the sequence and update the customer's current stage and responsible officer:
     1. **Employee 1 — Salesman (`sales`):** Handles Lead Conversion, KYC Document Collection (`5/5 docs`), and Booking Advance approval (`Stages 1–3`). Once Stages 1–3 are Done → **Workflow shifts to Site Operations Employee**.
     2. **Employee 2 — Site Operations (`site` — Structure, Electrical, Civil):** Executes physical installation (`Stages 4–7`). Once Structure, Electrical, Civil, and Installation stages are marked Done → **Workflow shifts to KEDL Employee**.
     3. **Employee 3 — KEDL Discom (`kedl`):** Handles Name Change, Load Enhancement, and Net Metering files & demand notices (`Stages 8–9`). Once Net Metering is approved → **Customer stage advances to `SYSTEM_LIVE` and shifts to Handover / Service Employee**.
     4. **Employee 4 — Service & Maintenance (`service`):** Handles final handover (`Stage 10: HANDED_OVER`) and post-installation **Service Tickets** assigned by the Admin.

3. **10-Stage Done / Incomplete Control:**
   - The assigned Employee (for their respective stages) and the Admin must be able to mark stages **Done** or **Incomplete (Pending)**, and those updates must sync in **real time** to both the **Client Dashboard** and the **Admin / Employee Customer Detail Screen**.

4. **Admin Full Visibility & Staff Approval:**
   - The **Admin** can view all live progress across every client, stage, payment, KEDL file, ticket, and employee task list.
   - New employee sign-ups remain in `pending` state until the **Admin** approves or rejects them based on their requested role.

---

## 2. Summary of Workflow & Hardcode Issues to Fix

| ID | Category | Issue Summary | Primary Files Affected |
| :--- | :--- | :--- | :--- |
| **WF-01** | Workflow Handoff | **No automatic workflow shift** between the 4 employee types (`Sales` → `Site` → `KEDL` → `Service`) when stages/tasks are completed. | `Backend/app/db/mongo.py`, `Backend/app/api/v1/kedl.py` |
| **WF-02** | 10-Stage Sync | **`CustomerDetailScreen` 10-stage timeline is hardcoded** (first 5 stages `true`, last 5 `false`) and has no UI control for Employees/Admin to toggle stages **Done / Incomplete**. | `SolarPro/lib/features/customers/presentation/screens/customer_detail_screen.dart` |
| **WF-03** | Stage 8–9 Bug | **Approving KEDL Net Metering file does not advance customer stage** to `SYSTEM_LIVE` or update the 10-stage timeline in MongoDB. | `Backend/app/api/v1/kedl.py`, `Backend/app/db/mongo.py` |
| **HC-01** | Hardcoded Staff | **Client tickets are hardcoded to `"Vikram Singh" (EMP-SRV-104)`** and `"Jaipur, Rajasthan"` instead of entering an unassigned Admin queue. | `Backend/app/api/v1/client.py`, `Backend/app/api/v1/tickets.py` |
| **HC-02** | Hardcoded Payments | **2 fake payments (`pay-001`, `pay-002`) and `"Rajesh Sharma" (EMP-SLS-042)`** are auto-inserted into live MongoDB whenever a new client opens the Payments tab. | `Backend/app/db/mongo.py`, `Backend/app/api/v1/payments.py` |
| **HC-03** | Hardcoded UI Data | **Hardcoded customer name (`Aryan Jadaun`), fake milestone dates (`2026-10-10`), default specs (`Waaree`/`Growatt`/`₹2.5L`), and 6 fake labour teams.** | `client_dashboard_screen.dart`, `customer_detail_screen.dart`, `Backend/app/db/mongo.py` |
| **HC-04** | Fake File Uploads | **Uploads are simulated or discarded:** Site photos & KEDL docs generate fake filenames without a file picker; Customer KYC docs only toggle a boolean; backend discards uploaded file bytes. | `site_job_detail_screen.dart`, `kedl_file_detail_screen.dart`, `customer_detail_screen.dart`, `customers.py`, `client.py` |
| **DB-01** | Broken Endpoints | **10+ endpoints crash with `500 Internal Server Error`** because `get_db()` yields `None` and those routes lack MongoDB implementations (including Admin Payment Verify/Reject & KEDL Demands). | `Backend/app/db/session.py`, `payments.py`, `kedl.py`, `client.py`, `leads.py`, `inventory.py`, `reports.py` |

---

## 3. Detailed Breakdown & Step-by-Step Fix Instructions

---

### [WF-01] Implement Automatic 4-Employee Sequential Handoff

#### What is Wrong Now:
Currently, all 4 employee portals (`salesman`, `site`, `kedl`, `service`) operate as disconnected islands in `Backend/app/db/mongo.py`:
1. When a Salesman converts a lead (`mongo_convert_lead`, lines `784–811`) or verifies documents and advance payment, nothing triggers the Site Operations stage.
2. When a Site Employee completes `structure`, `electrical`, or `civil` work (`mongo_update_work_assignment`, lines `1213–1250`), it marks that single milestone as `"done"`, but does not advance the customer's main `stage` field or hand off to the next assigned employee.
3. When all Site installation works are completed, the KEDL files (`name_change`, `load`, `net`) are not automatically initialized or assigned to the KEDL employee.

#### How to Fix:
1. **Store the 4 Assigned Employees on the Customer Document (`customers` collection):**
   - Allow Admin (when setting up/reviewing a client) to assign or pre-link the 4 role leads on the customer record:
     - `sales_id` / `sales_name` (Salesman)
     - `site_employee_id` / `site_employee_name` (or per-trade `structure_emp_id`, `electrical_emp_id`, `civil_emp_id`)
     - `kedl_employee_id` / `kedl_employee_name` (KEDL Liaison)
     - `service_employee_id` / `service_employee_name` (Service Engineer)
2. **Add a Stage Progression & Handoff Helper in `Backend/app/db/mongo.py` (e.g., `mongo_evaluate_and_advance_workflow(customer_id)`):**
   - **Sales → Site Handoff:** When Stages 1 (`SALE_CONFIRMED`), 2 (`DOCUMENTS_RECEIVED`), and 3 (`ADVANCE_VERIFIED`) are marked `done`, automatically:
     - Update `customer.stage = "STRUCTURE_WORK"`.
     - Update `customer.assigned_to` to the assigned **Site Employee**.
     - Auto-create/activate the `structure` work assignment in `db["work_assignments"]` and send an in-app notification (`mongo_create_notification`) to the Site Employee.
   - **Site Sequential Handoff (`Structure` → `Electrical` → `Civil` → `Installation Complete`):**
     - When `structure` work assignment is marked `completed` (or `incomplete`), sync Stage 4 (`STRUCTURE_WORK`), set `customer.stage = "ELECTRICAL_WORK"`, and activate the `electrical` assignment.
     - When `electrical` is completed, sync Stage 5 (`ELECTRICAL_WORK`), set `customer.stage = "CIVIL_WORK"`, and activate `civil`.
     - When `civil` is completed, sync Stage 6 (`CIVIL_WORK`) and Stage 7 (`INSTALLATION_COMPLETE`).
   - **Site → KEDL Handoff:** Once Stage 7 (`INSTALLATION_COMPLETE`) is `done`:
     - Update `customer.stage = "KEDL_PROCESS"` and set `customer.assigned_to` to the **KEDL Employee**.
     - Automatically initialize the 3 KEDL files (`name_change`, `load`, `net`) in `db["kedl_files"]` if not already created, assigned to `kedl_employee_id`, and notify the KEDL Employee.
   - **KEDL → Service/Handover Handoff:** Once the KEDL `net` file is marked `approved`:
     - Mark Stage 8 (`KEDL_PROCESS`) and Stage 9 (`SYSTEM_LIVE`) as `done`.
     - Update `customer.stage = "SYSTEM_LIVE"` and shift `customer.assigned_to` to the **Service Employee** (or Admin) for final handover (`Stage 10: HANDED_OVER`).

---

### [WF-02] Make the 10-Stage Timeline Dynamic & Toggleable (Done / Incomplete)

#### What is Wrong Now:
1. **Hardcoded Timeline in `CustomerDetailScreen`:**
   - In `SolarPro/lib/features/customers/presentation/screens/customer_detail_screen.dart` (lines `22–33`), the `_stages` list is hardcoded:
     ```dart
     final List<_StageInfo> _stages = [
       _StageInfo('Sale Confirmed', true, AppColors.success, Icons.handshake_rounded),
       _StageInfo('Docs Received', true, AppColors.success, Icons.folder_rounded),
       _StageInfo('Advance Verified', true, AppColors.success, Icons.verified_rounded),
       _StageInfo('Structure Work', true, AppColors.success, Icons.foundation_rounded),
       _StageInfo('Electrical Work', true, AppColors.success, Icons.electrical_services_rounded),
       _StageInfo('Civil Work', false, AppColors.warning, Icons.construction_rounded),
       _StageInfo('Installation Done', false, AppColors.grey600, Icons.solar_power_rounded),
       _StageInfo('KEDL Process', false, AppColors.grey600, Icons.description_rounded),
       _StageInfo('Net Meter Installed', false, AppColors.grey600, Icons.bolt_rounded),
       _StageInfo('Handed Over', false, AppColors.grey600, Icons.celebration_rounded),
     ];
     ```
   - In `_loadFromBackend()` (lines `79–173`), `_stages` is **never updated** from the backend response! Every customer always shows the exact same 5 completed and 5 pending stages on the Admin/Sales screen.
2. **No Done / Incomplete Toggle for Employees or Admin:**
   - `_TimelineTab` (lines `685–761`) is read-only.
   - On `SiteJobDetailScreen` (`SolarPro/lib/features/employee/site_work/presentation/screens/site_job_detail_screen.dart`, lines `667–693`), once a job is marked `completed`, the bottom bar locks to a static `'Job Completed & Verified'` banner with no option to revert/mark it `Incomplete` (`in_progress` / `pending`).

#### How to Fix:
1. **Backend (`Backend/app/db/mongo.py` & `Backend/app/api/v1/customers.py`):**
   - Include the computed 10-stage `timeline` array inside `mongo_get_customer_by_id(customer_id)` (reusing the same 10-stage logic from `mongo_get_client_home`, lines `1430–1558`).
   - Add or update `PATCH /api/v1/customers/{customer_id}/stage` (or `POST /api/v1/customers/{customer_id}/milestones`) so that the Admin or the currently assigned Employee for that stage can set any of the 10 stage keys (`SALE_CONFIRMED` through `HANDED_OVER`) to `"done"` or `"incomplete"` (`"upcoming"` / `"in_progress"`).
   - When a stage is toggled, call `mongo_evaluate_and_advance_workflow(customer_id)` so `customer.stage`, `progress`, and the active employee assignment stay in sync.
2. **Flutter (`customer_detail_screen.dart` & `site_job_detail_screen.dart`):**
   - Replace the hardcoded `_stages` list in `customer_detail_screen.dart` with the live `timeline` array returned by the backend.
   - Add a **Done / Incomplete** toggle button (or switch) on each stage row in `_TimelineTab` (restricted to Admin or the employee responsible for that stage) that calls the backend and refreshes the timeline.
   - In `site_job_detail_screen.dart`, allow the assigned Site Employee (or Admin) to toggle a completed assignment back to `In Progress (Incomplete)` if rework is needed, updating the customer milestone accordingly.

---

### [WF-03] Fix KEDL Net Metering Approval Not Updating Customer Stage

#### What is Wrong Now:
- In `SolarPro/lib/features/employee/kedl/presentation/screens/kedl_file_detail_screen.dart` (lines `100–102`), the confirmation dialog states:
  > *"Approving the Net Metering file will automatically advance the customer project stage to SYSTEM LIVE."*
- However, in `Backend/app/api/v1/kedl.py` (`PATCH /api/v1/kedl-files/{file_id}`, lines `139–168`), the MongoDB handler only updates `db["kedl_files"]` and **never updates** the customer document in `db["customers"]`.
- Furthermore, in `Backend/app/db/mongo.py` (lines `1535–1538`), `SYSTEM_LIVE` checks `customer.get("system_live_certified_by") or customer.get("is_system_live")`, which is never set anywhere in the codebase.

#### How to Fix:
- In `Backend/app/api/v1/kedl.py` (`update_kedl_file`), when `payload.get("status") == "approved"`:
  1. Set `approved_at = datetime.now(timezone.utc)` on the `kedl_files` document.
  2. Look up the associated `customer_id` from the KEDL file.
  3. If `file_type == "net"`, automatically update the customer in `db["customers"]`:
     - Mark `KEDL_PROCESS` and `SYSTEM_LIVE` milestones as `"done"`.
     - Set `"stage": "SYSTEM_LIVE"`, `"is_system_live": True`, and `"system_live_at": now.isoformat()`.
  4. If a KEDL file is reverted from `approved` to another status, revert those stage flags accordingly.

---

### [HC-01] Remove Hardcoded `"Vikram Singh" (EMP-SRV-104)` from Service Tickets

#### What is Wrong Now:
1. **`Backend/app/api/v1/client.py` (lines `172–187`):**
   - When a client raises a service ticket (`POST /api/v1/client/tickets`), the backend hardcodes the assigned employee and fallback city:
     ```python
     "customer_address": cust.get("address", "Jaipur, Rajasthan") if cust else "Jaipur, Rajasthan",
     ...
     "assigned_to": "emp-srv-104",
     "assigned_staff": "Vikram Singh",
     "assigned_staff_emp_no": "EMP-SRV-104",
     ```
2. **`Backend/app/api/v1/tickets.py` (lines `102–105`):**
   - In `POST /api/v1/tickets/{ticket_id}/assign`, if the staff ID isn't found in `db["users"]`, it silently falls back to `"Vikram Singh"` / `"EMP-SRV-104"` instead of returning a `404 Not Found` error.

#### How to Fix:
1. In `Backend/app/api/v1/client.py`:
   - Set `"assigned_to": None`, `"assigned_staff": None`, `"assigned_staff_emp_no": None`, and `"status": "open"` when a client creates a ticket (unless the customer already has a dedicated `service_employee_id` assigned by Admin).
   - Use `cust.get("address", "")` instead of hardcoding `"Jaipur, Rajasthan"`.
   - Create an in-app notification for `target_role="admin"` so the Admin sees the new ticket and can assign a Service Employee.
2. In `Backend/app/api/v1/tickets.py`:
   - If `staff` is not found in `db["users"]`, raise `HTTPException(status_code=404, detail="Employee not found")` instead of falling back to `"Vikram Singh"` and set ticket `"status": "assigned"` when assigned.

---

### [HC-02] Remove Fake Auto-Seeded Payments & Hardcoded `"Rajesh Sharma" (EMP-SLS-042)`

#### What is Wrong Now:
1. **Fake Payments Auto-Inserted for Every Client (`Backend/app/db/mongo.py`, lines `1655–1711`):**
   - In `mongo_get_client_payments(user_id_or_phone)`, if a client has no payments (`if not items:`), the function **inserts two fake payments** (`pay-001` for `₹25,000` and `pay-002` for `₹50,000`) into `db["payments"]`!
   - Worse, because `_id` is hardcoded to `"pay-001"` and `"pay-002"`, the first client triggers an insert, and any second client with 0 payments triggers a `DuplicateKeyError` crash on `_id: "pay-001"`!
2. **Hardcoded Sales Approver (`Backend/app/db/mongo.py`, lines `553–584` & `Backend/app/api/v1/payments.py`, line `137`):**
   - `mongo_sales_approve_payment` defaults to:
     ```python
     def mongo_sales_approve_payment(
         payment_id: str,
         approver_email: str = "rajesh.sharma@solarpro.in",
         approver_name: Optional[str] = None,
         approver_emp_no: Optional[str] = None,
     )
     ```
     and falls back to `"Rajesh Sharma"` and `"EMP-SLS-042"`.
   - In `Backend/app/api/v1/payments.py` (line `137`), the endpoint calls `mongo_sales_approve_payment(str(payment_id))` without passing `current_user.email`, `current_user.name`, or `current_user.employee_no`.

#### How to Fix:
1. In `Backend/app/db/mongo.py` (`mongo_get_client_payments`, lines `1655–1711`):
   - **Delete the entire `if not items:` block** that seeds `pay-001` and `pay-002`. If a client has no payments yet, return `[]`.
2. In `Backend/app/api/v1/payments.py` (line `137`) and `Backend/app/db/mongo.py` (`mongo_sales_approve_payment`, lines `553–584`):
   - Pass the actual logged-in user's details from `sales_approve_payment`:
     ```python
     res = mongo_sales_approve_payment(
         str(payment_id),
         approver_email=getattr(current_user, "email", ""),
         approver_name=getattr(current_user, "name", "Sales Staff"),
         approver_emp_no=getattr(current_user, "employee_no", ""),
     )
     ```
   - Remove the `"rajesh.sharma@solarpro.in"`, `"Rajesh Sharma"`, and `"EMP-SLS-042"` fallbacks.

---

### [HC-03] Remove Hardcoded Names, Specs, Dates & Teams Across Frontend & Backend

#### What is Wrong Now:
1. **Hardcoded Client Fallback Name (`SolarPro/lib/features/client/presentation/screens/client_dashboard_screen.dart`, line `42`):**
   - `_userName = prefs.getString('user_name') ?? 'Aryan Jadaun';`
   - Also in `Backend/app/db/mongo.py` (lines `75–77`), phone `9837039028` has a hardcoded comment/rule reserving it for `Aryan Singh Jadaun`.
2. **Hardcoded Customer Default Equipment & Price (`Backend/app/db/mongo.py`, lines `446, 456–466`):**
   - `mongo_create_customer` sets `final_price = 250000`, `kw = 5.0`, `panel_brand = "Waaree"`, `panel_watt = 540`, `panel_count = 10`, `inverter_brand = "Growatt"`, `structure_type = "Rooftop GI"` whenever those fields are omitted.
3. **Hardcoded Milestone Dates (`SolarPro/lib/features/customers/presentation/screens/customer_detail_screen.dart`, lines `121–146`):**
   - When `parsedMilestones.isEmpty`, the Flutter screen invents two local milestones with hardcoded verified date `'2026-10-10'`.
4. **Hardcoded Default Labour Teams (`Backend/app/db/mongo.py`, lines `1149–1160`):**
   - `mongo_get_teams` returns 6 hardcoded fake teams (`Sunil Kumar`, `Ramesh Singh`, `Mohit Sharma`, `Vikram Wireman`, `Deepak Mistry`, `Suresh Foundation`) if the `teams` collection is empty.

#### How to Fix:
1. In `client_dashboard_screen.dart` (line `42`), read the client's name from `_homeData?['customer']?['name']` or `AppConstants.kUserName`, falling back to `'Client'` instead of `'Aryan Jadaun'`.
2. In `mongo_create_customer` (`Backend/app/db/mongo.py`), only store specs provided in `customer_data` (defaulting unconfigured numbers to `0` and strings to `""` until the Salesman/Admin configures the quote).
3. In `customer_detail_screen.dart` (lines `121–146`), do not fabricate `'2026-10-10'` verification dates; display the actual milestones from the backend or an empty state prompting to add/configure milestones.
4. In `mongo_get_teams` (`Backend/app/db/mongo.py`), return the real documents from `db["teams"]` (or seed initial teams once in `init_mongo()` if desired, rather than returning fake non-existent IDs `"t1".."t6"` that aren't in the database).

---

### [HC-04] Fix Simulated File Uploads & Discarded File Bytes

#### What is Wrong Now:
1. **Site Work Photo Upload (`SolarPro/lib/features/employee/site_work/presentation/screens/site_job_detail_screen.dart`, lines `280–293`):**
   - When a Site Employee taps **"Upload Site Photo Proof"**, instead of opening the camera or photo gallery (`image_picker`), the bottom sheet just has a `+ / -` number counter (`1 to 10`) and generates fake filename strings:
     ```dart
     final paths = List.generate(
       photoCount,
       (i) => 'site_proof_${_job.workType.toBackendString()}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
     );
     ```
2. **KEDL Document Upload (`SolarPro/lib/features/employee/kedl/presentation/screens/kedl_file_detail_screen.dart`, lines `259–265`):**
   - Tapping **"Attach File"** never opens a file picker; it invents a dummy string:
     ```dart
     final fileName = 'kedl_${_file.fileType.toBackendString()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
     ```
3. **Customer 5 KYC Documents (`SolarPro/lib/features/customers/presentation/screens/customer_detail_screen.dart`, lines `181–225`):**
   - Tapping **"Upload"** next to E-Bill, Aadhaar, PAN, Cancelled Cheque, or Registry simply flips a boolean `uploaded = !doc.uploaded` via `PATCH /api/v1/customers/{id}` without selecting or uploading any file.
4. **Backend Discards Uploaded Bytes (`Backend/app/api/v1/customers.py:210–231` & `Backend/app/api/v1/client.py:119–127`):**
   - `upload_document` reads the uploaded file into memory via `read_upload_file(file)` and then **only saves the filename string** in MongoDB, discarding the actual file bytes!
   - `submit_client_payment` in MongoDB mode ignores the uploaded `file` bytes and sets `"proof_url": proof_filename or "assets/images/receipt_sample.png"`.

#### How to Fix:
1. **Backend Storage Persistence:**
   - Save uploaded files (`customer documents`, `payment receipts`, `site work photos`, `ticket photos`, and `KEDL documents`) to MinIO (`app/services/storage_service.py`) or a persistent `/app/uploads` volume mounted in Docker, and store the real downloadable URL/key in MongoDB.
   - When all 5 KYC documents (`e_bill`, `aadhaar`, `pan`, `cancelled_cheque`, `registry`) are uploaded, automatically mark `customer.documents_verified = True` and Stage 2 (`DOCUMENTS_RECEIVED`) as `"done"`.
2. **Flutter Real File / Camera Pickers:**
   - Use `image_picker` / `file_picker` in `site_job_detail_screen.dart`, `kedl_file_detail_screen.dart`, and `customer_detail_screen.dart` so employees upload real site photos and PDF/image documents via `MultipartFile`.

---

### [DB-01] Fix Broken SQL-Only Endpoints That Crash in MongoDB Mode

#### What is Wrong Now:
In `Backend/app/db/session.py` (lines `30–32`), `get_db()` is hardcoded to yield `None`:
```python
async def get_db() -> AsyncGenerator[Optional[AsyncSession], None]:
    yield None
```
Because the production app uses **MongoDB Atlas**, every API endpoint that calls a SQLAlchemy service (`PaymentService`, `KedlService`, `ClientService`, `LeadService`, etc.) without a `if db is not None:` check and a MongoDB handler **crashes with a `500 Internal Server Error`**.

#### Affected Endpoints That Must Be Wired to MongoDB:
1. **Payments (`Backend/app/api/v1/payments.py`):**
   - `POST /api/v1/payments/{payment_id}/verify` (lines `144–159`) — **Admin cannot verify payments!** Add `mongo_verify_payment(payment_id, admin_user)` which sets `payment.status = "verified"`, updates `customer.paid_amount`, marks Stage 3 (`ADVANCE_VERIFIED`) as `"done"`, and triggers workflow handoff.
   - `POST /api/v1/payments/{payment_id}/reject` (lines `162–179`) — **Admin/Sales cannot reject payments!** Add `mongo_reject_payment(payment_id, reason, current_user)`.
   - `POST /api/v1/customers/{customer_id}/payments` (lines `26–65`) — **Staff cannot record payments for a customer!** Route to `mongo_record_client_payment`.
   - `PATCH /api/v1/payments/{payment_id}` (lines `182–199`) — Add MongoDB update handler.
2. **KEDL (`Backend/app/api/v1/kedl.py`):**
   - `PATCH /api/v1/kedl-demands/{demand_id}` (lines `190–222`) — **KEDL employee cannot mark a demand as paid or waived!** Route to `mongo_update_kedl_demand`.
   - `POST /api/v1/kedl-files/{file_id}/documents` (lines `225–252`) — **KEDL employee cannot upload documents!** Store document metadata & file URL in `db["kedl_files"]`.
3. **Work Assignments (`Backend/app/api/v1/work_assignments.py`):**
   - Missing `POST /api/v1/work-assignments/{assignment_id}/photos` endpoint in `work_assignments.py` for saving site verification photos to the `work_assignments` document in MongoDB.
4. **Client Documents (`Backend/app/api/v1/client.py`):**
   - `GET /api/v1/client/documents` (lines `130–141`) — Crashes because it calls `ClientService.get_client_customer(db, current_user)` with `db=None`. Wire it to fetch `customer["documents"]` from MongoDB.
5. **Leads (`Backend/app/api/v1/leads.py`):**
   - `GET /api/v1/leads/{lead_id}` (lines `118–129`) and `PATCH /api/v1/leads/{lead_id}` (lines `132–149`) — Wire both to `db["leads"]` in MongoDB.

---

## 4. Developer Implementation Checklist

- [ ] **1. Remove Fake & Hardcoded Data (`HC-01`, `HC-02`, `HC-03`):**
  - [ ] Remove `pay-001` & `pay-002` auto-seeding from `mongo_get_client_payments()` in `Backend/app/db/mongo.py`.
  - [ ] Pass logged-in `current_user` info into `mongo_sales_approve_payment()` and remove `"Rajesh Sharma"` / `"EMP-SLS-042"` defaults.
  - [ ] Remove hardcoded `"Vikram Singh"` / `"EMP-SRV-104"` from `create_client_ticket` (`client.py`) and `assign_ticket` (`tickets.py`).
  - [ ] Remove `'Aryan Jadaun'` default name in `client_dashboard_screen.dart` and fake `'2026-10-10'` milestone dates in `customer_detail_screen.dart`.
- [ ] **2. Fix Broken MongoDB Endpoints (`DB-01`):**
  - [ ] Add MongoDB handlers for `POST /payments/{id}/verify`, `POST /payments/{id}/reject`, `POST /customers/{id}/payments`, and `PATCH /payments/{id}`.
  - [ ] Add MongoDB handlers for `PATCH /kedl-demands/{id}` and `POST /kedl-files/{id}/documents`.
  - [ ] Add `POST /work-assignments/{id}/photos` in `work_assignments.py` to persist site photo proofs in MongoDB.
  - [ ] Add MongoDB handlers for `GET /client/documents`, `GET /leads/{id}`, and `PATCH /leads/{id}`.
- [ ] **3. Wire Real 10-Stage Timeline & Done/Incomplete Toggle (`WF-02`, `WF-03`):**
  - [ ] Return the live 10-stage `timeline` array in `GET /api/v1/customers/{customer_id}`.
  - [ ] Replace the hardcoded `_stages` list in `customer_detail_screen.dart` with the live backend timeline and add a **Done / Incomplete** toggle for Admin & assigned Employees.
  - [ ] Allow Site Employees/Admin to mark a stage/job **Incomplete** if rework is needed.
  - [ ] Update `PATCH /api/v1/kedl-files/{file_id}` so approving the `net` file automatically marks `KEDL_PROCESS` and `SYSTEM_LIVE` as `done` on the customer record.
- [ ] **4. Implement Automatic 4-Employee Sequential Handoff (`WF-01`):**
  - [ ] Link the 4 employee roles (`Sales`, `Site`, `KEDL`, `Service`) to the customer record.
  - [ ] Automatically shift the active workflow, update `customer.stage` and `customer.assigned_to`, and send in-app notifications as each employee completes their stages (`Sales [1–3]` → `Site [4–7]` → `KEDL [8–9]` → `Service/Handover [10]`).
- [ ] **5. Wire Real File & Photo Uploads (`HC-04`):**
  - [ ] Persist uploaded files (KYC documents, payment proofs, site photos, KEDL PDFs) to storage and save real URLs in MongoDB instead of discarding bytes or generating fake filenames.
