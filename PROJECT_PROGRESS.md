# SENTRY · Project Progress, Status & Implementation Summary

> **Batangas State University — The National Engineering University (BatStateU TNEU)**  
> **Alangilan Campus · Security Guard & ICT Administration Command Console**  
> *Last Updated: November 12, 2026*

---

## 1. Project Overview & Context

SENTRY is the intelligent campus access and yard management system for BatStateU TNEU Alangilan Campus. The application running in [`campus_parking_desktop/`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop) serves as the primary **Guardhouse & ICT Administration Command Console**, designed to manage real-time vehicle entry/exit, 3-factor identity checks (Plate OCR, ArcFace biometric cosine similarity, ESP32 RFID), dual-state bay occupancy (Overhead camera vs. Backend reservation), guard exception handling, RA 10173 biometric enrollment, and campus parking logistics across **Lots A, B, C, and D**.

---

## 2. GitHub Repository & Releases

- **GitHub Repository:** [`https://github.com/thisisemman-22/Sentry-Windows`](https://github.com/thisisemman-22/Sentry-Windows) (Branch: `main`)
- **Latest Release:** [`v1.0.0`](https://github.com/thisisemman-22/Sentry-Windows/releases/tag/v1.0.0)
- **Packaged Deliverables:**
  - [`SENTRY-Windows-x64.zip`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/SENTRY-Windows-x64.zip) (`12.4 MB`): Portable Windows 10/11 x64 bundle containing [`SENTRY.exe`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/SENTRY-Windows-Release/SENTRY.exe) / [`campus_parking_desktop.exe`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/SENTRY-Windows-Release/campus_parking_desktop.exe).
  - [`SENTRY-demo-release.apk`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/SENTRY-demo-release.apk) (`50.7 MB`): Standalone Android APK for mobile demonstration and testing (mock/offline mode, zero backend required).
  - Ready-to-run folder: [`SENTRY-Windows-Release/`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/SENTRY-Windows-Release).

---

## 3. What Has Been Completed

### A. Foundation, Toolchain & Architecture (Phases 1–3)
- **Isolated Clean Scaffolding:** Configured inside [`campus_parking_desktop/`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop) so that outer prompt notes, design mockups, and handoff files in `SENTRY/` are never mixed into the Git repository.
- **Cross-Platform Target Support:** Windows Desktop (C++ Runner), Web (HTML5/Canvas), and Android (Gradle Release).
- **Design Reference Alignment:** 
  - Extracted exact brand tokens and styles from [`design_reference/index.html`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/design_reference/index.html) and [`design_reference/style.css`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/design_reference/style.css).
  - Pure OLED dark mode (`#000000`) and BatStateU Crimson palette (`#C8102E`).
  - Interactive cursor-tracking SENTRY shield logo ([`sentry_interactive_logo.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/widgets/sentry_interactive_logo.dart)) with eye pupil physics, perspective rim narrowing, and eyelid blink timers.
- **Human-First Offline Typography:** Bundled 3 high-accessibility typefaces (SIL OFL) in [`assets/fonts/`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/assets/fonts):
  - **Schibsted Grotesk**: Editorial display headers and KPIs.
  - **Atkinson Hyperlegible Next**: Braille Institute low-vision reading font for high-stress guard readability.
  - **Atkinson Hyperlegible Mono**: Zero-ambiguity monospace figures for plates (`0` vs `O`, `1` vs `I`, `8` vs `B`), RFID tags, and similarity scores.

### B. UI/UX De-Cluttering & Progressive Disclosure
- **Shared UI & Motion Kit:** Built in [`sentry_ui.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/widgets/ui/sentry_ui.dart) and [`motion.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/motion/motion.dart).
- **Reduced Cognitive Load:** Replaced walls of uppercase text and raw UUIDs with single-takeaway cards (`SentryCard`, `MetricTile`, `CapacityBar`).
- **Progressive Disclosure:** Technical details (UUIDs, confidence scores, ArcFace event triggers, building distance matrices) are abstracted behind `InfoHint` (`?`) tooltips or right-sliding sheets (`showDetailsSheet`).
- **Responsive Mobile & Desktop Shell:** [`desktop_shell.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/app/desktop_shell.dart) adapts seamlessly:
  - **Desktop / Wide Screen:** Collapsible sidebar (`Ctrl+B`), top telemetry bar, keyboard navigation (`Ctrl+1`…`7`, `Ctrl+Shift+L` theme toggle).
  - **Mobile / Narrow Screen:** Converts sidebar to a Bottom Navigation Bar and drawer (`☰`).
- **Demo Controls Sheet:** [`demo_controls_sheet.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/app/demo_controls_sheet.dart) consolidates all 9 test scenarios (`T01`–`T20`), roster switching, and network/session failure drills into an on-demand modal.

### C. All 8 Production Operational Views (Phases 4–11)
1. **View 1: Authentication & Workstation Login** ([`login_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/authentication/presentation/login_screen.dart))
   - Editorial 2-column layout, quick persona switcher (`Guard` vs `Admin`), 401 error handling, and RA 10173 data privacy notice.
2. **View 2: Command Overview Dashboard** ([`overview_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/overview/presentation/overview_screen.dart))
   - Confirmed post-passage vehicles inside campus (strictly separating pre-passage 30s holds), today's throughput, pending reviews, 4-lot capacity bars with dual-state physical vs. allocation breakdown.
3. **View 3: Live Gate Monitoring** ([`live_gate_monitoring_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/live_gate_monitoring/presentation/live_gate_monitoring_screen.dart))
   - 4 lanes (`lane-car-in`, `lane-car-out`, `lane-moto-in`, `lane-moto-out`), 4-step progress stepper, calibrated ArcFace cosine similarity in `[-1.0, 1.0]` (never as a percentage), and **"Confirm Vehicle Crossed Gate (`guard_attestation`)"** fallback modal requiring 10–500 char notes.
4. **View 4: Guard Reviews & Exceptions** ([`guard_reviews_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/guard_reviews/presentation/guard_reviews_screen.dart))
   - Master-detail queue, mandatory safety boundary (hard denials and expired attempts forbid approval), optimistic concurrency conflict detection (`409 STALE_VERSION`), and post-approval passage confirmation workflow.
5. **View 5: Parking Management** ([`parking_management_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/parking_management/presentation/parking_management_screen.dart))
   - Interactive overhead lot blueprints (Lots A–D), 2-way driveway aisle, top-down vector vehicle renderings, occupancy conflict detection, and 7-building proximity priority matrix.
6. **View 6: Access Logs & Lookup** ([`access_logs_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/access_logs/presentation/access_logs_screen.dart))
   - Confirmed campus visits (`GET /api/v1/access-visits`), gate attempt history, and participant/multi-vehicle lookup (`U007` multi-vehicle independence keeping `V007` and `V008` records unmerged, plus live updates when new users/vehicles are registered in View 8).
7. **View 7: Device Monitoring** ([`device_monitoring_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/device_monitoring/presentation/device_monitoring_screen.dart))
   - Health state for producers `D01`–`D07` (online, degraded, offline), uptime, sequence numbers, heartbeat simulator. If `D05` goes offline, mapped bays safely turn unknown/stale.
8. **View 8: Administration, Manual Registration & RA 10173 Facial Enrollment** ([`administration_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/administration/presentation/administration_screen.dart))
   - Strictly gated to `role == 'administrator'` (`RoleRestrictedPanel` with `403 FORBIDDEN` explanation for Guards).
   - **Tab 1 — Drivers & Vehicles (`P01–P06`):** Participant directory with vehicle additions, authorization toggles, and 1-click jump to facial enrollment.
   - **Tab 2 — Manual User & Vehicle Registration (`POST /api/v1/admin/users/register`):** Full validation (`full_name`, optional/regex `user_code`, `email`, `role_code`, `building_code`, toggleable primary `vehicle_type`, normalized uppercase `plate_number`, and `rfid_uid`), inline field-level `409 DATABASE_CONFLICT` handling, `201 Created` confirmation banner, and 1-click **"Proceed to Facial Enrollment →"** button.
   - **Tab 3 — Facial Recognition Enrollment (`GET / POST / DELETE /api/v1/admin/users/{user_id}/face-enrollment`):** Searchable user selector, mandatory **RA 10173 Data Privacy consent gate checkbox** (disables upload/webcam/submit until checked), native Windows file upload (`file_selector` `.jpg`/`.jpeg`/`.png`) + webcam frame capture, in-memory thumbnail staging that is purged immediately upon submission, and Enrollment Status Card with **"Revoke & Delete Embedding"** confirmation dialog.
   - **Tab 4 — System Audit Log (`GET /api/v1/admin/audit-logs`):** Chronological record of guard attestations, reviews, user/vehicle registrations, and biometric template enrollments/revocations.

### D. Real API Architecture Wiring (`DATA_SOURCE=real`) & Automated Tests
- **Centralized `ApiClient` ([`api_client.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/network/api_client.dart)):**
  - Configured with `connectTimeout: 3s` and `receiveTimeout: 5s`, `Authorization: Bearer <access_token>` injection from `SecureSessionStore`, and automatic `Idempotency-Key: <uuid_v4>` injection on all mutation requests (`POST`, `PATCH`, `PUT`, `DELETE`).
  - Automatic single-attempt token refresh on `401` via `POST /api/v1/auth/refresh`; clears session and redirects to `LoginScreen` on refresh failure.
  - Full `ApiEnvelope<T>` parsing and HTTP `401`/`403`/`409`/`410`/`422`/`429`/`500`/`503` error mapping (`ErrorCatalog` + `ApiFailure`) with strict fail-closed behavior in `DATA_SOURCE=real`.
- **Real WebSocket Client ([`ws_client.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/network/ws_client.dart)):**
  - `WsRealtimeClient` connects to `WS_BASE_URL` (`/api/v1/ws/updates`) using an encrypted handshake frame and strips any accidental bearer tokens from query URLs (`buildSanitizedWsUri`).
  - Deduplicates `event_id`, tracks monotonic `stream_sequence`, triggers targeted invalidations across all 6 resource types (`access_attempt`, `access_visit`, `parking_assignment`, `parking_space`, `guard_review`, `device`), and handles close code `1008` session expiry.
- **Complete Repository Wiring (`lib/features/*/data/`):**
  - [`auth_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/authentication/data/auth_repository.dart), [`overview_providers.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/overview/state/overview_providers.dart), [`gate_monitoring_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/live_gate_monitoring/data/gate_monitoring_repository.dart), [`guard_reviews_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/guard_reviews/data/guard_reviews_repository.dart), [`parking_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/parking_management/data/parking_repository.dart), [`access_logs_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/access_logs/data/access_logs_repository.dart), [`device_monitoring_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/device_monitoring/data/device_monitoring_repository.dart), and [`administration_repository.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/administration/data/administration_repository.dart).
- **100% Passing Automated Tests (25/25 tests):**
  - [`test/contracts_and_invariants_test.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/test/contracts_and_invariants_test.dart) (8 unit/contract invariant tests).
  - [`test/widget_desktop_flow_test.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/test/widget_desktop_flow_test.dart) (End-to-end desktop flow test).
  - [`test/api_and_admin_features_test.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/test/api_and_admin_features_test.dart) (12 unit & widget tests covering `ApiClient` interceptors, `Idempotency-Key` injection, `401` single-attempt token refresh, `403`/`409` mapping, WS URL token stripping, Manual User Registration `409` duplicate plate conflict, 1-click transition to Facial Enrollment, RA 10173 consent gate, embedding revocation, production-first `DATA_SOURCE=real` defaults, 5x logo tap unlock, and secret developer backdoor credentials).
  - [`test/widget_overflow_audit_test.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/test/widget_overflow_audit_test.dart) (4 comprehensive regression suites auditing every screen, sub-tab, and modal across `1920x1080`, `1366x768`, `1280x720`, and `600x800` mobile preview drawer with zero `RenderFlex` overflows).
- **Static Analysis:** `flutter analyze` reports `0 issues found`.

### E. UI Polish, Motion Tuning, Brand Hero & Overflow Regression Audit (Prompt 2)
- **Desktop Shell Navigation Upgrades ([`desktop_shell.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/app/desktop_shell.dart)):**
  - **Grouped Sidebar:** Divided into 3 calm, labeled sections (`OPERATIONS`, `RECORDS & HARDWARE`, `SYSTEM`) with subtle separators in collapsed mode.
  - **Command Palette (`Ctrl+K`):** Global quick-jump search palette allowing operators to search and instantly jump to any of the 7 views, registered participants, or plate numbers.
  - **Compact 56px Top Bar:** Features a clean connection indicator (`Live` / `Out of date`), quick-jump trigger, mode telemetry pill (`LIVE` vs `MOCK` + per-second tabular Manila clock), and animated theme toggle (`Ctrl+Shift+L`).
  - **Calibrated Motion Transitions:** Tuned view switching to a snappy `220ms` combined fade and 1.5% horizontal slide curve (`SentryMotion.emphasized`), replacing sluggish transitions.
- **Prominent Interactive Logo Hero ([`sentry_interactive_logo.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/widgets/sentry_interactive_logo.dart)):**
  - **Login Hero (`login_screen.dart`):** Prominently placed inverted crimson logo (`size: 132`) with 3 concentric, animated pulse sonar rings.
  - **Desktop Shell Header:** 38px logo placed at the top of the sidebar.
  - **Empty Gate State (`live_gate_monitoring_screen.dart`):** Interactive 48px logo with calm "Gate idle — monitoring for incoming vehicle" messaging.
- **Strict 8px Spatial Rhythm & Responsive Layout Hardening:**
  - Applied the 3-point surface rule (Canvas, Card, Raised) with subtle borders (`0.65 alpha`) and zero visual clutter.
  - **Live Gates (`live_gate_monitoring_screen.dart`):** Responsive 4-lane cards (2x2 grid below 1080px, 1-column below 620px), flexible status pill text.
  - **Device Monitoring (`device_monitoring_screen.dart`):** Responsive LayoutBuilder with expanded device details and wrapping status buttons.
  - **Administration (`administration_screen.dart`):** Responsive LayoutBuilder for Operator Session Card, `isExpanded: true` on all dropdowns, responsive audit log list, wrapping vehicle badges in Driver Directory.
  - **Guard Reviews (`guard_reviews_screen.dart`):** Responsive inspector header with expanded reason title and wrapping conflict/info actions.
  - **Access Logs (`access_logs_screen.dart`):** Responsive visit rows and gate attempt history with expanded message text and wrapping badges.
  - **Overview (`overview_screen.dart`):** Responsive `_LotSummaryRow` right column with stacked free count and status pill, responsive `SectionHeader` with narrow-width title/trailing stacking.
  - **Parking Management (`parking_management_screen.dart`):** Min-height constrained bay cards with wrapping physical, allocation, and conflict status pills.
- **Zero-Overflow Regression Test Suite ([`test/widget_overflow_audit_test.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/test/widget_overflow_audit_test.dart)):**
  - Iterates every screen, sub-tab, and dialog modal across `1920x1080`, `1366x768`, `1280x720`, and `600x800` (mobile preview drawer).
  - Asserts zero `RenderFlex` overflow errors across all window dimensions.

### F. Production-First Default (`DATA_SOURCE=real`), Secret Developer Backdoor, Real Webcam Capture & UI Fixes (Prompt 3)
- **Production-First Default (`DATA_SOURCE=real`):**
  - Updated [`config/local.example.json`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/config/local.example.json) and [`app_config.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/config/app_config.dart) to default to `APP_ENV="production"`, `DATA_SOURCE="real"`, `API_BASE_URL="https://API_URL_PLACEHOLDER.local:8000"`, and `WS_BASE_URL="wss://API_URL_PLACEHOLDER.local:8000/api/v1/ws/updates"` with explicit `// TODO(API)` placeholders for Patrick's live FastAPI URL.
  - Removed all fake/pre-populated records, simulator buttons (`Cycle camera state`, `Simulate encounter`, simulated device status toggles, `MOCK` top-bar pill, and pre-filled demo login chips) from production mode, replacing them with clean empty/offline states and **Retry** buttons.
- **Hidden Developer Backdoor (Secret Test Mode):**
  - **Secret Credentials:** Entering `emman.dev@sentry.internal` and `SENTRY-DEV-4102!` on [`login_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/authentication/presentation/login_screen.dart) bypasses HTTP `POST /api/v1/auth/login`, switches the active session to `DataSourceMode.mock` in memory, loads the `U001–U007` fixtures, and logs in as `Administrator (Emmanuel Tamboong)`.
  - **Secret Gesture & Shortcut:** Clicking `SentryInteractiveLogo` 5 times within 2 seconds on `LoginScreen` (or pressing `Ctrl+Shift+Alt+D` anywhere) enables Developer Test Mode for the session with a `"Developer Test Mode Enabled"` toast.
- **Real Windows Webcam Capture (`camera` / `camera_windows`):**
  - Integrated `camera` and `camera_windows` in [`administration_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/administration/presentation/administration_screen.dart) (`_WindowsWebcamCaptureDialog` with live `CameraPreview` and **Capture Frame** button returning actual JPEG/PNG `Uint8List` bytes).
  - Strictly fails closed in production mode when no physical webcam is connected: *"No Windows webcam detected. Use 'Upload Face Images' to select photos from disk."*
- **Visual & Overflow Fixes:**
  - Shortened Overview KPI label to `"Confirmed inside"` (`12px` single-line with `Expanded` + `TextOverflow.ellipsis`).
  - Shortened `review_required` status pill to `"Review"` and added `"Idle"` pill state for empty lanes, plus prominent `"Confirm Vehicle Crossed Gate"` action button in [`live_gate_monitoring_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/live_gate_monitoring/presentation/live_gate_monitoring_screen.dart).
  - Styled [`access_logs_screen.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/features/access_logs/presentation/access_logs_screen.dart) and global `ChipThemeData` filter chips with `#C8102E` crimson selected background + `#FFFFFF` text/icon in both Light and Dark modes, and explicit high-contrast unselected colors (`#F1F5F9`/`#E2E8F0`/`#0F172A` in Light; `#18181C`/`#24242A`/`#FFFFFF` in Dark).
  - Cleaned up sidebar footer operator chip (`Emmanuel Tamboong`) with full-name tooltip and zero truncation clutter.

---

## 4. Architectural Invariants & Contract Adherence Table

| Invariant / Contract Rule | Implementation Status | Enforcement Location |
| :--- | :---: | :--- |
| **Invariant 1: Envelope & Timestamp Standards** | Verified | Schema v1.0.0, UUIDs, UTC wire timestamps formatted to Asia/Manila (UTC+8) via [`api_envelope.dart`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/campus_parking_desktop/lib/core/network/api_envelope.dart). |
| **Invariant 2: State Separation** | Verified | Allowed decision holds space with `visit_id == null`. Only passage confirmation (`guard_attestation` or sensor) creates an active visit. |
| **Invariant 3: Dual-State Parking** | Verified | Camera `physical_status` (`available` / `occupied` / `unknown`) tracked independently from backend `allocation_status` (`unassigned` / `held` / `assigned`). Unknown/stale bays are never counted as free. |
| **Invariant 4: Guard Review Safety Boundary** | Verified | Approve action is disabled on hard security denials (`UNKNOWN_CREDENTIAL`, `CREDENTIAL_REVOKED`, etc.) and expired holds. `409 STALE_VERSION` enforced. |
| **Invariant 5: Multi-Vehicle Independence (U007)** | Verified | `U007`'s vehicles `V007` and `V008` have separate histories. Competing simultaneous entry is rejected with `DUPLICATE_ACTIVE_VISIT`. |
| **Invariant 6: Fail-Closed Role Gating** | Verified | Guards receive `403 FORBIDDEN` / `ACCESS_DENIED` on admin audit logs, manual registration, and facial enrollment endpoints. |
| **Patrick Confirmation #1: Calibrated Cosine Similarity** | Verified | `face_similarity_score` displayed strictly as raw cosine similarity in `[-1.0, 1.0]` (e.g., `0.84 cosine similarity`), never formatted as a percentage. |
| **Patrick Confirmation #2: Confirmed Visits Endpoint** | Verified | Visits tab powered by `GET /api/v1/access-visits` schema. |
| **Patrick Confirmation #3: Guard Attestation Fallback** | Verified | Passage confirmation modal requires 10–500 character audit notes. |
| **RA 10173 Biometric Data Privacy Compliance** | Verified | Upload/Webcam/Submit gated behind explicit RA 10173 consent checkbox; raw photos purged immediately after ArcFace embedding extraction; supports 1-click consent withdrawal (`DELETE`). |

---

## 5. What Remains To Be Done (Roadmap & Next Steps)

1. **Live FastAPI Backend Integration (`DATA_SOURCE=real`):**
   - Connect the app to Patrick Carpio's live FastAPI backend once deployed on the campus LAN.
   - Run via:
     ```powershell
     flutter run -d windows --dart-define=DATA_SOURCE=real --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define=WS_BASE_URL=ws://127.0.0.1:8000/api/v1/ws/updates
     ```
2. **Hardware Sensor & Edge Producer Validation:**
   - Field-test live edge telemetry from:
     - Entrance / Exit gate barriers (relay controllers).
     - ESP32 RC522 RFID reader at the motorcycle lanes.
     - Overhead IP camera feeds (Lot A YOLOv8 plate recognition & ArcFace inference).
3. **Student Mobile Application Collaboration:**
   - Coordinate with the team working on the student-facing Android app for shared credentials, pass issuance, and destination routing sync.
4. **Continuous Maintenance:**
   - Keep this document updated after each milestone or major architectural modification.

---

## 6. Update Log

- **2026-11-11:** Initial creation and execution of Phases 1 through 13.
- **2026-11-11:** UX and accessibility overhaul; replaced cluttered screens with progressive disclosure cards; added offline bundled fonts (`Schibsted Grotesk`, `Atkinson Hyperlegible`).
- **2026-11-12:** Built standalone mobile Android APK (`50.7 MB`); adapted shell for mobile screens (bottom navigation + drawer).
- **2026-11-12:** Initialized Git, pushed clean code to [`thisisemman-22/Sentry-Windows`](https://github.com/thisisemman-22/Sentry-Windows).
- **2026-11-12:** Compiled native Windows release binary (`SENTRY.exe`) and published GitHub Release `v1.0.0` with Windows ZIP and Android APK assets.
- **2026-11-12:** Created this master tracking document ([`PROJECT_PROGRESS.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/PROJECT_PROGRESS.md)) in `\SENTRY`.
- **2026-11-12:** Executed [`antigravity_prompt_1_api_and_admin_features.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/antigravity_prompt_1_api_and_admin_features.md): wired full `DATA_SOURCE=real` HTTP & WebSocket client architecture (`ApiClient`, `WsRealtimeClient`, feature repositories), added Administrator **Manual User & Vehicle Registration** (`POST /api/v1/admin/users/register`) and **RA 10173 Facial Recognition Enrollment** (`GET/POST/DELETE /api/v1/admin/users/{user_id}/face-enrollment`), and verified `flutter analyze` (`0 issues`) + `flutter test` (`14/14 passing`).
- **2026-11-12:** Executed [`antigravity_prompt_1b_logic_and_prod_audit.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/antigravity_prompt_1b_logic_and_prod_audit.md) (Prompt 1.5 Logic, State, Security & Production-Readiness Audit): added startup fail-closed configuration error screen for `DATA_SOURCE=real`, eliminated synthetic mock data initialization in `real` mode, enforced 30-second space hold & 20-second decision expiration blocking passage confirmation with automatic bay release, added WebSocket exponential reconnection backoff (`1s, 2s, 4s, 8s, 16s` capped with jitter), fixed empty-collection `.first` crashes, added dialog controller disposal & in-flight submission guards, and verified `flutter analyze` (`0 issues`) + `flutter test` (`18/18 passing`).
- **2026-11-12:** Executed [`antigravity_prompt_2_ui_polish_and_overflow_audit.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/antigravity_prompt_2_ui_polish_and_overflow_audit.md) (Prompt 2 UI Polish, Motion Tuning, Prominent Interactive Logo & Zero-Overflow Responsiveness Audit): added 3-section labeled sidebar navigation (`OPERATIONS`, `RECORDS & HARDWARE`, `SYSTEM`), `Ctrl+K` command palette modal, compact 56px top bar with tabular Manila clock, 220ms view transitions, prominent interactive inverted logo with animated sonar rings on Login, sidebar header, and empty gate idle state, eliminated all RenderFlex overflow errors across `1920x1080`, `1366x768`, `1280x720`, and `600x800` (mobile preview drawer), and verified `flutter analyze` (`0 issues`) + `flutter test` (`22/22 passing`).
- **2026-11-12:** Executed [`antigravity_prompt_3_prod_default_and_fixes.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/antigravity_prompt_3_prod_default_and_fixes.md) (Prompt 3 Production-First Default, Secret Developer Backdoor, Real Webcam Capture & UI Fixes): switched default config to `DATA_SOURCE=real` (`APP_ENV=production`, `https://API_URL_PLACEHOLDER.local:8000`), removed mock clutter from production views, implemented secret developer backdoor credentials (`emman.dev@sentry.internal` / `SENTRY-DEV-4102!`), 5x logo tap, and `Ctrl+Shift+Alt+D` shortcut, integrated real Windows webcam capture (`camera` / `camera_windows`), fixed KPI/pill/chip/sidebar visuals, rebuilt release `SENTRY.exe`, and verified `flutter analyze` (`0 issues`) + `flutter test` (`25/25 passing`).
- **2026-11-12:** Executed [`antigravity_prompt_4_demo_trace_sweep.md`](file:///C:/Users/emman/OneDrive/Documents/SENTRY/antigravity_prompt_4_demo_trace_sweep.md) (Prompt 4 Codebase-Wide Demo Trace Sweep & Production Cleanliness Audit):
  - **Login Screen:** Input fields start completely blank (`''`); persona quick-fill chips hidden in production; zero text or hint leaks revealing backdoor credentials, gestures, or shortcuts.
  - **Top Bar & Shell:** No `DEV` or `MOCK` badge in real mode; demo controls sheet trigger removed; top bar connection pill renders live WebSocket status (`Connected` / `Reconnecting` / `Offline`) with fitted scale protection; clock displayed calmly with tabular figures.
  - **Overview Dashboard:** Zero hardcoded initial KPIs (`3`, `5 in · 2 out`, `4`, `26 / 32`); displays `—` and `'Awaiting backend connection'` until real FastAPI dashboard telemetry loads; calm empty states for parking lots (`'Awaiting parking lot telemetry'`) and activity feed (`'No recent gate activity'`).
  - **Live Gates:** Zero prefilled lanes (`UKQ247`, `DAL4266`, etc.); all 4 lanes initialize to `'Idle — Waiting for vehicle'`; center hero displays gate idle prompt; `'Simulate encounter'` button strictly gated behind developer test mode.
  - **Guard Reviews:** Empty queue defaults to clean `'No pending guard reviews'` state; `'simulate_stale_version_button'` / `'Test version conflict'` strictly gated behind developer test mode.
  - **Parking Management:** Empty bay state renders `'Awaiting lot telemetry'`; `'Cycle camera state'` button strictly gated behind developer test mode.
  - **Access Logs:** Visits tab shows `'No campus visits recorded'`; gate attempts tab shows `'No gate attempts recorded'`; participant lookup initializes without hardcoded `U007` selection and shows `'No registered drivers loaded'` when disconnected.
  - **Device Monitoring:** Displays clean empty state `'No site devices loaded'`; device simulator buttons (`Online`, `Degraded`, `Offline`) strictly gated behind developer test mode.
  - **Administration & Face Enrollment:** Initial enrollment selection starts unassigned (`null`) with zero prefilled `U001`/`U002` cards; biometric enrollment displays `'No registered users available'`; camera capture fails closed with `"No webcam detected — use Upload Face Images to select photos from disk"`; Guard role 403 test button (`'Test Calling Endpoint as Guard'`) hidden in production mode; test session expiry button hidden.
  - **Sign-Out Reset:** Signing out immediately resets `devModeUnlocked = false` and resets `sentryScenarioProvider` to clean `DATA_SOURCE=real`.
  - **Verification:** Built new comprehensive `test/prod_cleanliness_test.dart` (4/4 passed), verified `flutter analyze` (`0 issues found`), full `flutter test` (100% pass across all 5 test files), rebuilt release `SENTRY.exe`, and updated `SENTRY-Windows-x64.zip`.
- **2026-11-12:** Executed Official SENTRY Brand Logo & Icon Suite Implementation:
  - **Logo Geometry & Painter:** Extracted and formalized the mathematical BatStateU Crimson Shield (`#C8102E`) and car geometry with headlights/eyes from `sentry_interactive_logo.dart` into reusable `SentryLogoPainter` and `SentryLogo` static widget.
  - **Asset Suite Generation:** Created `test/generate_brand_assets_test.dart` leveraging Flutter's native rasterizer to generate master high-res PNGs (`sentry_logo.png` 1024x1024, `sentry_logo_512.png`, `sentry_logo_256.png`, `sentry_logo_inverted.png`, `sentry_logo_card.png`) and vector `sentry_logo.svg` in `assets/branding/`.
  - **Windows Runner Icon:** Generated multi-frame native Windows icon `windows/runner/resources/app_icon.ico` (containing 256, 128, 64, 48, 32, 24, 16 resolutions in 32bpp DIB and PNG formats) replacing the default Flutter bird.
  - **Android Launcher Icons:** Replaced default Flutter icons in `android/app/src/main/res/mipmap-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` with branded squircle tiles.
  - **Web Favicon & PWA Icons:** Updated `web/favicon.png`, `web/icons/Icon-192.png`, `web/icons/Icon-512.png`, `web/icons/Icon-maskable-192.png`, and `web/icons/Icon-maskable-512.png`.
  - **Metadata & Window Titles:** Updated `windows/runner/main.cpp` native window title (`"SENTRY · BatStateU TNEU Alangilan"`), `windows/runner/Runner.rc` Win32 metadata strings (`"Batangas State University - The National Engineering University"`, `"SENTRY - Smart Campus Access & Parking Management System"`, `"SENTRY.exe"`), `android/app/src/main/AndroidManifest.xml` (`android:label="SENTRY"`), and `web/manifest.json` / `web/index.html`.
  - **In-App Integration:** Added "About SENTRY" modal in sidebar footer menu displaying the interactive shield logo, version, and BatStateU institutional attribution.
  - **Verification & Rebuild:** `flutter analyze` (`0 issues`), `flutter test` (`31/31 passing`), rebuilt native Windows release binary `campus_parking_desktop.exe` / `SENTRY.exe`, repackaged `SENTRY-Windows-x64.zip`, committed and pushed to GitHub [`thisisemman-22/Sentry-Windows`](https://github.com/thisisemman-22/Sentry-Windows), and created GitHub Release `v1.1.0`.
