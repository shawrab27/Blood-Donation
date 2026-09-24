# BloodPulse Blood Hub — Reconnaissance Report (RECON.md)

This report documents the current state of the BloodPulse repository (Django backend and Flutter frontend) to guide the implementation of the Complete Blood Hub Flow (v2) based on Stitch Project `5715169077018899213` and the 10-screen Stitch visual specification.

---

## 1. Django Backend Inspection

### 1.1 Existing Models (`blood_pulse_backend/api/models.py`)
- **`BloodRequest`**:
  - *Current fields*: `patient_name`, `blood_group`, `urgency_level`, `hospital_location`, `contact_number`, `created_at`, `is_active`.
  - *Gaps & Required Extensions*:
    - `mode` (`EMERGENCY` = waves, `DIRECT` = chosen donors)
    - `component` (`WHOLE`, `RBC`, `PLATELETS`, `PLASMA`)
    - `units_needed` (1-10)
    - `urgency` (`CRITICAL_2H`, `URGENT_6H`, `TODAY_24H`, `SCHEDULED`), `needed_by`
    - `condition_category` (`SURGERY`, `ACCIDENT`, `THALASSEMIA`, `CANCER`, `DENGUE`, `DELIVERY`, `OTHER`), `condition_note` (max 80 chars)
    - `patient_photo` (private storage)
    - `scope` (`LOCAL`, `DISTRICT`, `DIVISION`, `NATIONWIDE`) and `effective_scope`
    - `division`, `district`, `upazila`, `hospital` (FK nullable) or `hospital_name_other`, `ward_bed`
    - `attendant_name`, `contact_phone`
    - `lat`, `lng`, `geohash`
    - `requisition_slip` (private storage)
    - `trust_score`, `trust_band` (`LOW`, `MEDIUM`, `HIGH`)
    - `status` (`PENDING_ADMIN`, `ACTIVE`, `COVERED`, `FULFILLED`, `EXPIRED`, `CANCELLED`, `REJECTED`)
    - `current_wave`, `next_wave_at`, `expires_at`, `escalated_to_admin`
    - `client_request_id` (UUID), `is_drill`, `created_at`
  - *New Associated Models Needed*:
    - `RequestTarget` (for DIRECT mode and Request All list)
    - `EmergencyNotification` (wave push tracking)
    - `RequestAcceptance` (journey tracking: `ACCEPTED`, `ON_THE_WAY`, `ARRIVED`, `DONATED`, `FAILED`, `CANCELLED`)
    - `FakeReport` (reporting unverified/malicious requests)
    - `AcceptanceEvent` (timeline milestone log)
    - `DonationIssue` (medical rejection, no-show, logistics)
    - `StandbyOffer` (ranked backup donor offers)
    - `DeferralRecord` (medical deferral tracking & appeal status)

- **`DonorProfile`**:
  - *Current fields*: `user`, `blood_group`, `district`, `phone_number`, `nid_hash`, `last_donation_date`, `is_verified`, `is_profile_complete`, `is_available`, `email_verified`, `bio`, `institute`, `address`, `total_bags_donated`, `profile_picture`, `manual_rank_override`, `latitude`, `longitude`.
  - *Gaps & Required Extensions*:
    - `is_searchable` (boolean consent flag, default `False`)
    - `campus` (text field, aliased to/backed by `institute`)
    - Counters: `fulfilled_count`, `no_show_count`, `cancel_count`, `alert_count`, `response_count`
    - Ratings: `rating_avg`, `rating_count`
    - Timestamp: `last_active_at`
    - Geospatial: `last_lat`, `last_lng` (stored strictly **fuzzed** to ~500 m), `geohash`
    - Safety controls: `deferral_until`, `alert_pause_until`
    - Firebase linking: `firebase_uid` (crucial for Firestore security rules)

- **`Hospital`**:
  - *Current fields*: `name`, `district`, `address`, `is_referral_center`. (Currently 0 records in database).
  - *Required Extensions*: `name_en`, `name_bn`, `division` (FK), `upazila` (FK), `lat`, `lng`, `phone`, `is_verified`. Management command `import_hospitals --csv <path>` to be created.

- **`CompatibilityRule`**:
  - Exists in `models.py`: `blood_group`, `can_give_to`, `can_receive_from`.
  - In Prompt 1, pure function `compat.py` will formalize whole blood, packed RBC, platelets, and plasma rules with medical disclaimer.

- **Disaster Models**:
  - None currently exist. Prompt 4 will introduce `DisasterEvent`, `DonationPoint`, `HospitalNeed`, `DonationSlot`, `Pledge`, and `AuditLog`.

---

## 2. Firebase Admin, Auth, and Firestore Tracking

### 2.1 Initialization & Auth UID Linking
- Firebase Admin SDK is initialized via `_get_firebase_app()` checking `FIREBASE_SERVICE_ACCOUNT_JSON` or `firebase-service-account.json`.
- `FirebaseAuthView` verifies Firebase ID tokens using `firebase_admin.auth.verify_id_token(id_token)`.
- **Key Finding**: Django `User` and `DonorProfile` currently do **not** store the Firebase Auth `uid`. They match strictly on verified email.
  - *Resolution*: Add `firebase_uid = models.CharField(max_length=128, unique=True, null=True, blank=True)` to `DonorProfile` so backend can link participants and populate `tracking/{acceptanceId}` in Firestore with exact UIDs.

### 2.2 Firestore Chat & Rules
- `firestore.rules` currently defines permissions for `/users`, `/requests`, `/chat_rooms`, and `/chats` enforcing `request.auth.uid in resource.data.participants`.
- For Live Tracking, a new block `/tracking/{acceptanceId}` will be added:
  - Participants: `[donorUid, requesterUid]`
  - Donor writes only donor position (throttled to at least 5s apart in rules).
  - Requester writes only requester position (if opted-in).
  - Clients cannot alter participants, status, or destination.
  - Lifecycle: Document created by Django backend upon journey start (`ON_THE_WAY`) and deleted upon completion. Fallback polling endpoint (`/api/journeys/{id}/location/`) supported if Firebase UID is unlinked.

---

## 3. Email & Identity Verification (OTP)

- **Current Config**: `settings.py` configures Django's default SMTP backend pointing to `smtp-relay.brevo.com:587`.
- **Constraint (Render Free Tier)**: Render blocks outbound SMTP ports (25, 465, 587). Standard `send_mail` times out or fails on Render.
- **Current Model**: `EmailVerificationCode` exists with plaintext 6-digit code.
- **New Architecture (Prompt 2)**:
  - HTTPS transactional email API via Brevo REST API (`https://api.brevo.com/v3/smtp/email`) behind a clean `EmailSender` interface.
  - Environment variables: `BREVO_API_KEY`, `EMAIL_FROM`, `OTP_PEPPER`.
  - Security: `EmailOTP` model storing only `HMAC-SHA256(code, OTP_PEPPER + otp_id)` with `hmac.compare_digest`. No raw codes in DB or logs.
  - Daily budget guard: `EMAIL_DAILY_BUDGET = 250` (well below Brevo's 300 free/day limit).
  - Rate limiting & lockout: 60s resend cooldown, 5 wrong attempts lock code, max 3 sends/hour/email.

---

## 4. Storage, Push Notifications (FCM), & Trust Scoring

- **Storage**: Currently defaults to Django's `FileSystemStorage` (`default_storage`). Ready for future Cloudinary configuration without changing app code. Image uploads will have EXIF/GPS metadata stripped via Pillow server-side.
- **FCM Utility**: `send_blood_request_notification` exists in `api/utils.py`. Will be refactored to support chunked multicast (`send_each_for_multicast`) for wave alerts, high priority, and collapse keys.
- **Trust Scoring**:
  - Previously only in Flutter `CalculateTrustScoreUseCase`.
  - Prompt 1 moves authoritative trust evaluation server-side to `trust.py`: Rule-based 0-100 score + optional Gemini AI check (`GEMINI_API_KEY` with 5s timeout) to determine `trust_band` (`LOW`, `MEDIUM`, `HIGH`) and scope ceilings.

---

## 5. Flutter Frontend Architecture

### 5.1 Design Tokens & Fonts
- Design System: Defined in Stitch project `5715169077018899213` ("Vital Flow").
- Tokens in `AppColors`:
  - Primary: `#C30121`
  - Secondary: `#2B2B2B`
  - Tertiary: `#0D68AA`
  - Surface: `#FDF3F3` / `#FFF8F7`
  - Neutral: `#8E7D7F`
- Typography: Headlines in `Georgia`, Body / Buttons / Labels in `Inter`.
- Shapes: Pill / Stadium radius (`kCapsuleRadius = 50.0`, `BorderRadius.circular(50)`). Zero blur/glass effects.

### 5.2 Localization
- Fully configured via `l10n.yaml` with `app_en.arb` and `app_bn.arb`.
- All new Blood Hub strings will be provided in both English and Bangla.

### 5.3 Router (`appRouter`)
- Powered by `go_router`. Existing routes include `/dashboard`, `/feed`, `/emergency-request`, `/map`, `/live-dispatch`, `/identity-verification`.
- The 10 standardized routes will be mapped cleanly:
  1. `/blood-hub`
  2. `/blood-hub/search`
  3. `/blood-hub/request/direct`
  4. `/emergency`
  5. `/emergency/national`
  6. `/emergency/personal`
  7. `/journeys`, `/journeys/:id`
  8. Sheet on `/journeys/:id` (Donation Issue)
  9. `/standby/:offerId`
  10. `/identity/verify`

### 5.4 Packages Checklist
- `geolocator`: ^13.0.2 (**Present**)
- `flutter_map`: ^8.3.1 (**Present**)
- `latlong2`: ^0.10.1 (**Present**)
- `image_picker`: ^1.1.2 (**Present**)
- `url_launcher`: ^6.3.2 (**Present**)
- `share_plus`: ^13.3.0 (**Present**)
- `firebase_messaging`: ^16.4.3 (**Present**)
- `flutter_local_notifications`: ^18.0.1 (**Present**)
- `hive` & `hive_flutter`: ^2.2.3 / ^1.1.0 (**Present**)
- `cloud_firestore`: ^6.7.1 (**Present**)
- `connectivity_plus`: (**Missing** — will add `connectivity_plus: ^6.1.0` in Prompt 5 for offline banner detection).

---

## 6. Bangladesh Location & Campus Data Status

- **Divisions**: 8 administrative divisions populated in DB (`Division` model).
- **Districts & Upazilas**: Only 7 districts and 7 upazilas currently populated in the database.
- **Hospitals**: 0 hospital rows currently in database.
- **Campuses**: Currently represented as informal strings in Flutter widgets (`availableCampuses`).
- **Policy Compliance**: We will NOT invent arbitrary location data. Prompt 1 includes `import_hospitals --csv` and a clean seeding structure. Official Bangladesh geo data (64 districts, 495 upazilas) can be populated via an official seed script.

---

## 7. Gaps versus the 10 Stitch Screens

| # | Screen | Route | Current State | Required Work |
|---|---|---|---|---|
| **1** | Blood Hub | `/blood-hub` | Existing `blood_hub_view.dart` has partial search/cards | Align layout with Stitch screen `1ffd59a5...`: 3 cards ("Search for Donor", "Emergency Blood", "Blood Campaigns"). |
| **2** | Search Results & Map | `/blood-hub/search` | Search provider has local filter stub | Cursor pagination, fuzzed OpenStreetMap donor clustering, "Request All" -> emergency pre-fill. |
| **3** | Priority Requisition | `/blood-hub/request/direct` | Basic form in `emergency_request_screen.dart` | Refactor to Stitch screen `be056f...`: optional photo, hospital autocomplete, urgency chips, prescription slip. |
| **4** | Emergency Hub | `/emergency` | None (redirected to single form) | Two-card hub: National Emergency (frozen state if none) + Personal Emergency card. |
| **5** | Disaster Overview | `/emergency/national` | None | Frozen state ("No emergency right now"), hospital demand progress bars, slot pledging, emergency hotlines (999, 16163). |
| **6** | Personal Emergency | `/emergency/personal` | Basic form exists | Tactile 8-group chips, component selector, bag stepper, scope radio cards, boundary selectors. |
| **7** | Active Requests | `/journeys`, `/journeys/:id` | `live_dispatch_screen.dart` prototype | Segmented Requester/Donor views, 4-step progress line, OSRM route polyline, live donor marker glide. |
| **8** | Donation Issue | Sheet on Screen 7 | None | Bottom sheet: Medical Rejection (90-day deferral), No-show (guarded), Logistics -> Standby auto-trigger. |
| **9** | Standby Donor Alert | `/standby/:offerId` | None | Backup donor banner, countdown timer, masked requester details until accept. |
| **10** | Identity Verification | `/identity/verify` | Basic SMS/email screen | Animated 6-digit boxes, Brevo HTTPS OTP, auto-verify on 6th digit, custom on-screen numeric keypad. |

---

## 8. Summary of Risks & Mitigations

1. **Render Free Tier SMTP Outbound Block**: Outbound connections to port 587 are blocked on Render. **Mitigation**: All transactional email strictly calls Brevo's HTTPS REST API.
2. **Neon Database Safety**: Standing rules strictly forbid running migrations on Neon directly. **Mitigation**: Migrations are generated and verified on local SQLite/Postgres only.
3. **Privacy of Donor Locations & Contacts**: Exposing exact GPS or phones would violate donor trust. **Mitigation**: Coordinates fuzzed to 500m on search/map; phone numbers revealed exclusively after mutual acceptance and identity verification.
4. **Firestore Cost on Free Tier**: Live tracking writes could exhaust Firestore quotas. **Mitigation**: Client write policy limits donor writes to at most once per 10s and only if moved >25m.
