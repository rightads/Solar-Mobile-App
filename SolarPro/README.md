<div align="center">

# ☀️ SolarPro Mobile & Web Client

### *Hardware-Accelerated Clean Energy Management App built with Flutter*

[![Flutter](https://img.shields.io/badge/Flutter-3.24.4%20%7C%203.44+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.6-blue?style=flat-square)](https://riverpod.dev)
[![GoRouter](https://img.shields.io/badge/Routing-GoRouter%2014-purple?style=flat-square)](https://pub.dev/packages/go_router)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-lightgrey?style=flat-square)](#)

---

</div>

This folder contains the complete cross-platform Flutter application for **SolarPro** — featuring animated portal gateways, 60fps vector sunburst shaders, 10-stage project milestone tracking, and real-time generation telemetry.

> 📖 **Looking for the complete architecture, backend APIs, and deployment guides?**  
> Check out the root [Repository README](../README.md).

---

## 📱 Features Implemented

* **Multi-Portal Experience:** Instant role-switching between **Client Command Center**, **4-Role Field Staff Operations** (Sales, Site EPC, Discom KEDL, Service), and **Executive Super Admin**.
* **Carrier SMS OTP:** Real mobile number authentication powered by 2Factor.in & Fast2SMS.
* **Telemetry Dashboards:** Interactive power generation, battery discharge, grid export curves via `fl_chart`.
* **KYC & Document Vault:** 5-point document scanner & upload tracker (Aadhaar, Electricity Bill, PAN, Cancelled Cheque, Photo).
* **Net-Metering Discom Tracker:** Live government file tracking with demand note status.
* **Offline-Resilient Architecture:** Riverpod state caching and automatic token refresh interceptors.

---

## 🚀 Running Locally

```bash
# 1. Install dependencies
flutter pub get

# 2. Analyze code quality
flutter analyze

# 3. Launch on connected device or emulator
flutter run

# 4. Build release APK
flutter build apk --release
```

---

## 📂 Architecture & Directories

* `lib/core/` — Application theme, design tokens, GoRouter configuration, API clients.
* `lib/features/auth/` — Animated login screen, OTP verification, registration.
* `lib/features/client/` — Client dashboard, energy analytics, project timeline, invoice history.
* `lib/features/employee/` — Field staff assignments, stage handoff triggers.
* `lib/features/admin/` — Administrative approvals, role assignments, company oversight.
* `lib/features/kedl/` — Discom Net-Metering, Load and Name change file tracker.
* `lib/features/tickets/` — Customer service breakdown tickets and resolutions.
