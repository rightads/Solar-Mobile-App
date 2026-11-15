<div align="center">

# ☀️ SolarPro

### **Next-Gen Clean Energy & Rooftop Solar EPC Operating System**

*Accelerating Solar Adoption with End-to-End Project Telemetry, 4-Stage Operational Handoff, Net-Metering Workflow, and Enterprise Resource Planning.*

---

[![Flutter Version](https://img.shields.io/badge/Flutter-3.24.4%20%7C%203.44+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/Dart-3.9+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11%20%7C%203.12-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas%20%7C%20Motor-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://mongodb.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%20AsyncPG-336791?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Compose%20Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Security Grade](https://img.shields.io/badge/Security%20Audit-A%2B%20Hardened-brightgreen?style=for-the-badge&logo=shield&logoColor=white)](#-security--production-hardening)
[![License](https://img.shields.io/badge/License-MIT-orange?style=for-the-badge)](LICENSE)

[Live Deployment](#-live-deployment) • [Key Features](#-key-features) • [Visual Showcase](#-visual-showcase) • [System Architecture](#-system-architecture) • [Workflow Engine](#-solar-lifecycle-workflow) • [Tech Stack](#-technology-stack) • [Quick Start](#-quick-start--installation) • [API Schema](#-api-endpoints-overview)

</div>

---

## ⚡ Executive Overview

**SolarPro** is an industrial-strength, enterprise-ready platform engineered for Solar EPC (Engineering, Procurement, and Construction) companies. It completely digitizes the fragmented rooftop solar journey from the initial lead capture to lifetime asset operations and maintenance.

### 🛑 The Problem
Traditional solar installers manage high-stake projects using WhatsApp groups, paper forms, and fragmented spreadsheets. This causes:
* **Discom Submission Bottlenecks:** Lost Net-Metering, Load Enhancement, and Name Change files with power distribution utilities (e.g., KEDL, Tata Power, BSES).
* **Payment Delays & Disputes:** Unverified milestone payments, lost physical receipts, and delayed subsidy disbursement.
* **Labour Handoff Friction:** Poor visibility across Civil, Structural, and Electrical contractor teams.
* **Client Anxiety:** Repetitive customer service calls regarding stage progress and solar telemetry.

### 💡 The Solution
SolarPro orchestrates the entire company into a **unified reactive ecosystem**:
1. **Interactive Client Command Portal:** Transparent 10-stage timeline, live generation & savings telemetry, real-time demand notices, and 1-tap support tickets.
2. **4-Role Field Employee Engine:** Strict automated handoff transitions: `Sales Executive` ➡️ `Site EPC Operations` ➡️ `KEDL Discom Liaison` ➡️ `Service & O&M Engineer`.
3. **Executive Super Admin Hub:** Master inventory tracking, workforce role approvals, milestone escrow reconciliation, and executive business analytics.
4. **Dual-Core Asynchronous Engine:** Combines **PostgreSQL** (ACID ledgers & transactional integrity) with **MongoDB Motor** (high-throughput sensor telemetry, JSON documents, and flexible milestone workflows).

---

## 🌐 Live Deployment

| Component | URL | Port | Notes |
|:---|:---|:---:|:---|
| **Website** | [`https://solarpro-app.in`](https://solarpro-app.in) | `443` | React site with app downloads, served by LiteSpeed (CyberPanel) |
| **Backend API** | `https://82.29.165.43:8443/api/v1` | `8443` | FastAPI behind nginx, reached **by IP only** (no domain) |
| **Health check** | `https://82.29.165.43:8443/api/v1/health` | `8443` | Returns `{"status":"ok","db":"mongodb"}` |
| **Android app** | [GitHub Release `Android`](https://github.com/rightads/Solar-Mobile-App/releases/tag/Android) | – | Signed release APK, rebuilt on every push to `main` |
| **Windows app** | [GitHub Release `Windows`](https://github.com/rightads/Solar-Mobile-App/releases/tag/Windows) | – | Zipped desktop build, rebuilt on every push to `main` |

**How the app reaches the backend**

* The domain `solarpro-app.in` belongs to the website only. The mobile and desktop apps call the API directly at the VPS IP on port **8443**. These values are set in [`SolarPro/lib/core/constants/app_constants.dart`](SolarPro/lib/core/constants/app_constants.dart) (`serverIp`, `serverPort`).
* The API uses HTTPS with a **self-signed certificate** issued for `82.29.165.43` (valid until 2036). It is created on the server by `Backend/scripts/deploy.sh` and stored in `Backend/certs/` (not in git).
* The app trusts **only** that certificate. Its SHA-256 fingerprint is pinned in `app_constants.dart` (`apiCertSha256`) and enforced by [`pinned_http_overrides.dart`](SolarPro/lib/core/network/pinned_http_overrides.dart):
  ```
  89a63f6cb346b38df113e320a8b88f550ccb586878cfd004e4e7b65e4ef6af4c
  ```
* Browsers and tools like `curl` will report the certificate as untrusted. That is expected. To call the API from a terminal, trust the certificate explicitly:
  ```bash
  openssl s_client -connect 82.29.165.43:8443 </dev/null 2>/dev/null | openssl x509 > api.crt
  curl --cacert api.crt https://82.29.165.43:8443/api/v1/health
  ```

> [!WARNING]
> **Do not delete `Backend/certs/` on the VPS.** If the certificate is regenerated (deleted folder or a new server IP), every installed app stops connecting until `apiCertSha256` is updated and new builds are shipped. The new fingerprint is printed in the deploy log as `📌 App settings: API_PORT=… API_CERT_SHA256=…`.

**Deployment (CI/CD)**

Everything deploys from GitHub Actions on push to `main`. Nothing is deployed by hand:

| Workflow | Triggered by changes in | What it does |
|:---|:---|:---|
| `backend-ci-cd.yml` | `Backend/**`, `website/**` | Compile, lint, security regression suite, `pip-audit`, then SSH to the Hostinger VPS, `git reset --hard origin/main`, and run `Backend/scripts/deploy.sh` |
| `build_android.yml` | `SolarPro/**` | Builds the signed release APK and publishes it to the `Android` release |
| `build_windows.yml` | `SolarPro/**` | Builds the Windows desktop app and publishes it to the `Windows` release |
| `build_macos.yml` | `SolarPro/**` | Builds the macOS app as a workflow artifact |

`deploy.sh` starts the Docker containers (`backend`, `nginx`, `website`). It saves the API port in `Backend/.env` as `API_HOST_PORT` (first free port from 8443, reused on later deploys), creates the certificate if it is missing, checks API health over HTTPS, and installs the website build into LiteSpeed for `solarpro-app.in`.

---

## 📱 Visual Showcase

<div align="center">

| **Client Access & Real OTP** | **Role-Based Portal Gateway** | **Multi-Role Authentication** |
|:---:|:---:|:---:|
| <img src="docs/assets/screen_client_login.png" width="260" alt="Client Login Screen" /> | <img src="docs/assets/screen_portal_select.png" width="260" alt="Portal Selection" /> | <img src="docs/assets/screen_portal_employee.png" width="260" alt="Employee Login" /> |
| *2Factor Carrier OTP & Ambient Particles* | *Dynamic Portal Switcher: Client / Staff / Admin* | *Role-gated authorization for Field Staff* |

<br/>

| **Executive Super Admin Portal** | **Client Registration & Onboarding** | **Interactive Solar Dashboard** |
|:---:|:---:|:---:|
| <img src="docs/assets/screen_portal_admin.png" width="260" alt="Admin Portal" /> | <img src="docs/assets/screen_register.png" width="260" alt="Client Registration" /> | <img src="docs/assets/screen_main_view.png" width="260" alt="Client Telemetry & Milestones" /> |
| *Hardware-level security & elevated control* | *Fast client signup & KYC vault initialization* | *Live solar generation, battery & grid feed* |

</div>

> [!NOTE]  
> All user interfaces feature **60 FPS hardware-accelerated animations**, custom sun-glow vector shaders, and zero layout shift design powered by Flutter Riverpod and GoRouter.

---

## 🌟 Key Features

### 1. ☀️ Client Command Center
* **Live Energy Telemetry:** High-precision generation graphs (`fl_chart`), solar inverter status, daily power production (kWh), lifetime environmental savings (CO₂ offset & trees saved), and grid export stats.
* **10-Stage Visual Tracker:** Clear, real-time stage progress indicator showing exact milestone status (from Site CAD Survey to Net-Meter Commissioning).
* **Payment Vault:** View milestone breakdown, submit payment proof (UPI, IMPS, Cheque) with instant photo attachments, and download tax invoices.
* **Discom Demand Tracker:** Direct notification and document view when utility demand notes are issued.
* **Service Tickets:** Raise service and fault tickets with live technician assignment tracking.

### 2. 👷 4-Stage Autonomous Employee Engine
```mermaid
graph LR
    subgraph S1["1. Sales Operations"]
        A[Lead Acquisition] --> B[KYC Vault 5/5 Docs]
        B --> C[Advance Payment]
    end
    subgraph S2["2. Site EPC Ops"]
        D[Structure Erection] --> E[Electrical Cabling]
        E --> F[Civil Works]
    end
    subgraph S3["3. Discom KEDL"]
        G[Name Change File] --> H[Load Enhancement]
        H --> I[Net Metering Approval]
    end
    subgraph S4["4. Service & O&M"]
        J[Commissioning & Handover] --> K[Field Breakdowns]
        K --> L[Annual Maintenance]
    end

    C ==> D
    F ==> G
    I ==> J

    style S1 fill:#1e293b,stroke:#f59e0b,stroke-width:2px,color:#fff
    style S2 fill:#1e293b,stroke:#3b82f6,stroke-width:2px,color:#fff
    style S3 fill:#1e293b,stroke:#10b981,stroke-width:2px,color:#fff
    style S4 fill:#1e293b,stroke:#8b5cf6,stroke-width:2px,color:#fff
```

* **Role 1 — Sales Executive:** Pipeline CRM, lead conversion, automated proposal quoting, and verification of 5 KYC documents (Aadhaar, Electricity Bill, Property Tax, Bank Cancelled Cheque, Passport Photo).
* **Role 2 — Site Operations (Structure / Electrical / Civil):** Trade-specific task queues, photo upload verification with geo-tagging, and equipment checklist sign-offs.
* **Role 3 — Discom Liaison (KEDL Officer):** Tracking Name Change, Load Enhancement, and Net Meter files with demand notice upload & government tracking IDs.
* **Role 4 — Service & Maintenance Engineer:** Post-commissioning handover, preventive maintenance logs, and emergency inverter fault resolutions.

### 3. 🛡️ Executive Super Admin Management
* **Privileged Staff Onboarding:** Dynamic registration gating; employee profiles remain `pending` until approved and granted specific permissions by the Admin.
* **Milestone Escrow Verification:** Single-click review and verification of client receipts before advancing EPC stages.
* **Supply Chain & Inventory Management:** Live warehouse stock tracking for solar PV modules (Mono PERC / Bifacial), grid-tie inverters, DC cables, and mounting structures.
* **Enterprise Reporting:** Real-time revenue analytics, sales conversion velocity, and project delivery SLAs.

---

## 🏗️ System Architecture

SolarPro implements a decoupled, event-aware distributed architecture designed for high availability and low latency:

```mermaid
flowchart TD
    subgraph Clients["📱 Client & Staff Interfaces"]
        FA[Flutter Mobile App<br/>Android & iOS]
        FW[Flutter Web Portal<br/>Desktop & Admin]
    end

    subgraph Gateway["🌐 Reverse Proxy & Security Layer"]
        NGX[Nginx 1.25 Reverse Proxy<br/>Rate Limiting & SSL Termination]
    end

    subgraph BackendApp["⚡ Application Core (FastAPI)"]
        FAP[FastAPI Async Server<br/>Gunicorn + Uvicorn Workers]
        AUTH[JWT & PBKDF2 Auth Module]
        WF[Sequential Workflow Engine]
        NOTIF[Push & SMS Notification Service]
    end

    subgraph Gateways["📡 External Cloud Services"]
        SMS1[2Factor.in Gateway]
        SMS2[Fast2SMS Fallback]
        SMTP[Gmail / Resend Mailer]
    end

    subgraph DataStorage["🗄️ Persistence & Storage"]
        PG[(PostgreSQL 16<br/>ACID Transactions & Balances)]
        MG[(MongoDB Atlas Motor<br/>Projects, Stages & Telemetry)]
        RD[(Redis Cache<br/>OTP Rate Limits & Sessions)]
        S3[(MinIO / S3<br/>KYC Documents & Site Photos)]
    end

    FA & FW -->|HTTPS / WSS| NGX
    NGX -->|Reverse Proxy| FAP
    FAP --> AUTH & WF & NOTIF
    NOTIF --> SMS1 & SMS2 & SMTP
    FAP --> PG
    FAP --> MG
    FAP --> RD
    FAP --> S3

    style Clients fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#fff
    style Gateway fill:#0f172a,stroke:#818cf8,stroke-width:2px,color:#fff
    style BackendApp fill:#0f172a,stroke:#34d399,stroke-width:2px,color:#fff
    style Gateways fill:#0f172a,stroke:#fbbf24,stroke-width:2px,color:#fff
    style DataStorage fill:#0f172a,stroke:#f43f5e,stroke-width:2px,color:#fff
```

---

## 🔄 Solar Lifecycle Workflow

The core business logic enforces strict milestone transitions across 10 deterministic stages:

| Stage # | Stage Key | Description | Responsible Actor | Handoff Trigger |
|:---:|:---|:---|:---|:---|
| **01** | `SALE_CONFIRMED` | Lead closed and site contract finalized | Sales Executive | Client booking lock |
| **02** | `DOCUMENTS_RECEIVED` | 5/5 Mandatory KYC documents uploaded & validated | Sales Executive | Document checklist verified |
| **03** | `ADVANCE_VERIFIED` | Milestone 1 advance payment received & verified | Super Admin | Payment audit confirmation |
| **04** | `STRUCTURE_WORK` | Rooftop elevated GI mounting structure fabricated | Site Civil / Structure Team | Site photo upload & QA |
| **05** | `ELECTRICAL_WORK` | PV module array stringing, inverter mounting & DC wiring | Site Electrical Team | Electrical test report |
| **06** | `CIVIL_WORK` | Foundation grouting, earthing pits & chemical compound | Site Civil Team | Structural stability sign-off |
| **07** | `INSTALLATION_COMPLETE` | Internal EPC installation completed & factory tested | EPC Site Supervisor | Site handover report |
| **08** | `KEDL_PROCESS` | Discom liaison for Name Change, Load Enhancement & Net Meter | KEDL Liaison Officer | Government demand approval |
| **09** | `SYSTEM_LIVE` | Bi-directional net meter installed and grid synchronized | KEDL & Discom Inspectors | Grid export validation |
| **10** | `HANDED_OVER` | Final warranty docs, plant monitoring credentials delivered | Service & O&M Engineer | Client acceptance sign-off |

---

## 🔒 Security & Production Hardening

SolarPro has completed a comprehensive security audit (**Grade A+**) adhering to OWASP Mobile Top 10 and OWASP API Security guidelines:

* 🛡️ **Zero Hardcoded Secrets:** Strict environment isolation via `.env` with no default secrets in source code or docker images.
* 📲 **Carrier-Grade OTP Gateways:** Real SMS OTP verification via **2Factor.in** and **Fast2SMS** fallback with SHA-256 OTP hashing and brute-force rate-limiting.
* 🔐 **Fine-Grained Role Escalation Prevention:** Strict whitelist validation on `/api/v1/auth/register`. Client accounts cannot elevate to staff/admin roles without cryptographic master authorization.
* 🛡️ **NoSQL & ReDoS Sanitization:** Strict regex sanitization (`re.escape`) across search parameters, eliminating NoSQL injection vectors.
* 🌐 **Secure Transport Enforcement:** HTTPS only (TLS 1.2 / 1.3) on the API port `8443`, with **certificate pinning** in the app: it trusts only the server's own certificate fingerprint. Android `usesCleartextTraffic=false`, and release builds refuse any non-`https://` API URL.
* 🔑 **Production Keystore Signing:** Standardized Android keystore configuration (`upload-keystore.jks`) using environmental signature injection.

---

## 🛠️ Technology Stack

<div align="center">

| Layer | Technologies & Frameworks |
|:---|:---|
| **Mobile & Web UI** | **Flutter 3.24+ / 3.44+**, Dart 3.9+, Riverpod 2.6 (State Management), GoRouter (Navigation), Google Fonts, Animate Do, Shimmer, Dotted Border |
| **Visualization & Shaders** | **FL Chart** (Solar yield & generation curves), Custom Vector Shaders, Lottie Animations |
| **Backend REST Core** | **FastAPI 0.110+**, Starlette, Pydantic v2, Python 3.11/3.12, Gunicorn + Uvicorn Async Workers |
| **Primary Databases** | **PostgreSQL 16** (SQLAlchemy Asyncpg, Alembic Migrations) & **MongoDB Atlas** (Motor Async Driver) |
| **Caching & Queue** | **Redis 7** (Distributed locks, OTP rate limiting, transient cache) |
| **Object Storage** | **MinIO S3 / AWS S3** (KYC Documents, Customer Bills, Invoices, Geo-tagged site photos) |
| **Telecom & Gateways** | **2Factor.in API** (Primary SMS Gateway), **Fast2SMS API** (Secondary Gateway), Resend / Gmail SMTP |
| **DevOps & Containers** | **Docker**, Docker Compose, Nginx Reverse Proxy, Hostinger VPS, GitHub Actions CI/CD |

</div>

---

## 📂 Project Organization

```text
Solar-Mobile-App/
├── .github/
│   └── workflows/
│       ├── backend-ci-cd.yml          # Backend CI + deploy to Hostinger VPS
│       ├── build_android.yml          # Signed release APK -> "Android" release
│       ├── build_windows.yml          # Windows desktop build -> "Windows" release
│       └── build_macos.yml            # macOS app build (artifact)
├── Backend/                           # FastAPI Core Engine
│   ├── app/
│   │   ├── api/v1/                    # Domain API Routers (Auth, Leads, KEDL, Client, etc.)
│   │   ├── core/                      # Config, Security, JWT, Logging & Exceptions
│   │   ├── db/                        # Dual Database layer (PostgreSQL + MongoDB Motor)
│   │   ├── models/                    # SQLAlchemy ORM models
│   │   ├── schemas/                   # Pydantic v2 validation schemas
│   │   └── services/                  # Business logic (Workflow Handoff, SMS, Email, S3)
│   ├── Dockerfile                     # Hardened multi-stage Python container
│   ├── docker-compose.yml             # Local microservices orchestration
│   └── requirements.txt               # Locked production dependencies
├── SolarPro/                          # Flutter Mobile & Desktop Application
│   ├── android/                       # Native Android harness & release keystore
│   ├── assets/                        # High-resolution logos, icons, vector assets
│   ├── docs/assets/                   # Visual UI screenshots & showcase media
│   └── lib/
│       ├── core/                      # Theme, Router, Network Clients, Storage
│       └── features/                  # Domain Feature Modules:
│           ├── admin/                 # Super Admin oversight & approvals
│           ├── auth/                  # Animated 3-Portal Login & Registration
│           ├── client/                # Client Telemetry, 10-Stage Tracker & Invoices
│           ├── employee/              # Shared Employee Work Center & Assignments
│           ├── kedl/                  # Discom Net-Metering, Load & Name Files
│           ├── leads/                 # Sales CRM & KYC Document Collection
│           ├── payments/              # Milestone Invoicing & Receipt Uploads
│           └── tickets/               # Post-installation Service & Fault Tracking
├── SECURITY_AUDIT_REPORT.md           # Full production readiness & vulnerability audit
├── WORKFLOW_AND_HARDCODE_FIXES.md     # 4-Role Handoff & Architecture specification
└── README.md                          # Repository Documentation (You are here)
```

---

## 🚀 Quick Start & Installation

### 1. Prerequisites
* **Flutter SDK:** `^3.24.0` or `3.44.4+` (`flutter --version`)
* **Android SDK:** Platform 34+, Build-Tools `34.0.0+`
* **Python:** `3.11+` or `3.12+`
* **Docker & Docker Compose:** Optional for instant containerized deployment

---

### 2. Backend Setup

#### Option A: Docker Compose (Recommended)
```bash
# Clone the repository
git clone https://github.com/rightads/Solar-Mobile-App.git
cd Solar-Mobile-App/Backend

# Configure environment variables
cp .env.example .env

# Spin up FastAPI, PostgreSQL, MongoDB & MinIO
docker compose up --build -d
```
The API will be live at `http://localhost:8000` with Swagger documentation at `http://localhost:8000/docs`.

#### Option B: Local Python Environment
```bash
cd Solar-Mobile-App/Backend

# Create and activate virtual environment
python -m venv venv
# Windows:
.\venv\Scripts\Activate.ps1
# Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run migrations and launch server
alembic upgrade head
uvicorn app.main:create_application --factory --host 0.0.0.0 --port 8000 --reload
```

---

### 3. Mobile App Setup (Flutter)

```bash
cd Solar-Mobile-App/SolarPro

# Get dependencies
flutter pub get

# Check attached devices / emulators
flutter devices

# Run in debug mode on connected device (uses the live API by default)
flutter run

# Point a debug build at a local backend instead
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Or build release Android APK (live API, pinned certificate)
flutter build apk --release
```

The app connects to the live backend at `https://82.29.165.43:8443/api/v1` by default. Release builds only accept `https://` URLs.

---

## ⚙️ Environment Configuration

Create a `.env` file in `Backend/` based on `.env.example`:

| Variable | Description | Default / Example |
|:---|:---|:---|
| `ENV` | Environment stage (`development`, `staging`, `production`) | `production` |
| `DATABASE_URL` | PostgreSQL Async Connection String | `postgresql+asyncpg://user:pass@localhost:5432/solar_db` |
| `MONGO_URI` | MongoDB Connection URI | `mongodb+srv://user:pass@cluster.mongodb.net/solar_db` |
| `SECRET_KEY` | Cryptographic key for JWT issuance (min 32 chars) | `generate-using-openssl-rand-hex-32` |
| `TWO_FACTOR_API_KEY` | 2Factor.in Real SMS Delivery Gateway Key | `your-2factor-api-key` |
| `FAST2SMS_API_KEY` | Fast2SMS Secondary Gateway Key | `your-fast2sms-api-key` |
| `MINIO_ENDPOINT` | Object Storage Endpoint | `s3.solarpro.com` or `localhost:9000` |
| `SMTP_USER` / `SMTP_PASS` | System transactional notification credentials | `alerts@solarpro.com` |

---

## 📡 API Endpoints Overview

The backend exposes a structured, RESTful API versioned under `/api/v1`:

| Module | Route | Methods | Description |
|:---|:---|:---:|:---|
| **Health** | `/api/v1/health` | `GET` | System heartbeat, DB status & server uptime |
| **Auth** | `/api/v1/auth/otp/send` | `POST` | Dispatches real carrier SMS OTP (2Factor / Fast2SMS) |
| **Auth** | `/api/v1/auth/otp/verify` | `POST` | Verifies OTP and returns Bearer Access Token |
| **Auth** | `/api/v1/auth/login` | `POST` | Password login for Staff, Sales, Engineers & Admin |
| **Client** | `/api/v1/client/dashboard` | `GET` | Fetches generation telemetry, timeline & assigned officer |
| **Leads** | `/api/v1/leads` | `GET`, `POST` | Lead pipeline management & conversion to customer |
| **KYC Docs** | `/api/v1/customers/{id}/documents` | `GET`, `POST` | Upload & verify Aadhaar, EB Bill, PAN, Cheque |
| **Payments** | `/api/v1/payments` | `GET`, `POST` | Milestone payments, receipt uploads & Admin verification |
| **Work Tasks** | `/api/v1/work-assignments` | `GET`, `PATCH`| Structure, Electrical & Civil task status sync |
| **KEDL Files** | `/api/v1/kedl/files` | `GET`, `POST` | Name change, load enhancement & net metering tracker |
| **Service** | `/api/v1/tickets` | `GET`, `POST` | Client breakdown tickets, technician assignment & resolution |
| **Inventory** | `/api/v1/inventory` | `GET`, `POST` | Solar panels, inverters & hardware stock control |

---

## 🗺️ Roadmap & Future Enhancements

- [x] **v1.0 — Core Foundation:** 10-Stage Milestone Workflow, Flutter Riverpod App, FastAPI Backend, Dual PostgreSQL & MongoDB Storage.
- [x] **v1.2 — Security & Real SMS:** Production Security Audit Grade A+, 2Factor.in & Fast2SMS live OTP integration, Android Keystore.
- [ ] **v1.5 — IoT Inverter Protocol Bridge:** Direct RS-485 / Modbus TCP telemetry integration for Sungrow, Growatt, GoodWe, and Solis solar inverters.
- [ ] **v2.0 — AI Solar Rooftop Analysis:** Satellite roof boundary polygon estimation, shadow irradiance loss modeling, and automated CAD string sizing.
- [ ] **v2.2 — Multi-Language Discom Portals:** Regional language localization (Hindi, Marathi, Gujarati, Tamil) for state electricity board field officers.

---

## 📄 License & Ownership

Distributed under the **MIT License**. See `LICENSE` for more information.

Developed with 🧡 for the Clean Energy Revolution.  
*SolarPro Systems — Powering Rooftops, Empowering People.*

<div align="center">
  <sub>Built by <a href="https://github.com/aryanjadaun">Aryan Singh Jadaun</a> and Contributors</sub>
</div>
