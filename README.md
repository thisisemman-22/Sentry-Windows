# SENTRY — Flutter Windows Desktop Application (`campus_parking_desktop`)

**Batangas State University — The National Engineering University (BatStateU TNEU), Alangilan Campus**  
*Smart Entry, Navigation, Tracking, Recognition, and Yard Management (`AI_Campus_Parking_System`)*

## Team 6 — Flutter Windows Desktop Application
- **#29 Team Leader / Desktop Developer:** Emmanuel Tamboong (`authentication`, `overview`, core architecture, Riverpod DI, HTTP/WebSocket client, theme & design system)
- **#30 Gate Monitoring Developer:** `live_gate_monitoring` & `device_monitoring`
- **#31 Guard Review Developer:** `guard_reviews` & `access_logs`
- **#32 Parking & Administration Developer:** Jarom Magtibay (`parking_management` & `administration`)

## Quick Start Commands

### 1. Run in Mock Mode (Default for Independent Development & Defense Demo)
```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=config/local.example.json
```

### 2. Run in Real FastAPI Mode (Strict Adapter Mode)
```powershell
flutter run -d windows --dart-define-from-file=config/demo.example.json
```
> **Fail-Closed Rule:** In `DATA_SOURCE=real` mode, if `API_BASE_URL` or `WS_BASE_URL` is unreachable or returns an error, the application **never** falls back to mock success.

### 3. Static Analysis & Automated Tests
```powershell
flutter analyze
flutter test
```

## Core Architectural Invariants
1. **FastAPI Is the Sole Authority:** No local database credentials, no direct LAN camera/ESP32 actuation, and no client-side authorization fabrication.
2. **Six Separate State Dimensions:** Observation (`observation_received`) -> Attempt (`identity_verification_pending` | `authorization_allowed` | `authorization_denied` | `guard_review_required` | `expired` | `cancelled`) -> Decision (`allowed` | `denied` | `review_required`) -> Gate Claim (`claimed`) -> Passage Confirmation (`physical_passage_confirmed`) -> Committed Visit (`active` -> `closed`) & Parking Assignment (`held` -> `assigned` -> `released`).
3. **Physical vs. Allocation State:** Every parking bay in Lots A–D tracks `physical_status` (`available` | `occupied` | `unknown`) independently from `allocation_status` (`unassigned` | `held` | `assigned`). `unknown` or `is_stale: true` is **never** displayed as available.
4. **Confirmed Backend Extensions (Patrick Carpio — 2026-11-11):**
   - Extended Gate Attempt Telemetry (`plate_text`, `ocr_confidence`, `detection_confidence`, `rfid_uid`, `face_recognition_status`, and `face_similarity_score` displayed strictly as raw calibrated cosine similarity `[-1, 1]`, never as a percentage).
   - Guard/Admin Paginated Campus Visit Logs (`GET /api/v1/access-visits`).
   - Guard **"Confirm Vehicle Crossed Gate"** (`guard_attestation`) fallback button (`POST /api/v1/passages/entries` and `/exits`).
