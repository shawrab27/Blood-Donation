# Blood Pulse — Architecture

> Rule: **Do not propose architecture changes.** This document describes the locked architecture. Changes only when the user asks.

## 1. System Overview
```
+--------------------+        HTTPS / JWT         +----------------------------+
|  Flutter Mobile    | -------------------------> |  Django REST API (Render)  |
|  (Android + iOS)   |                            |  DRF + SimpleJWT           |
|  Hive offline cache| <------------------------- |  Gunicorn + WhiteNoise     |
+---------+----------+                            +------+----------+----------+
          |                                              |          |
          | Firestore (chat) / FCM (push)                |          | Gemini API
          v                                              v          v
+--------------------+                       +----------------+  +--------------+
| Firebase           |                       | Neon Postgres  |  | Google Gemini|
| Firestore + FCM    |                       | (+ pgvector)   |  | (trust, RAG) |
+--------------------+                       +----------------+  +--------------+

Future (not started): React/Next.js website -> same Django API
Future (designed only): Web admin dashboard -> same Django API
```

## 2. Technology Stack
| Layer | Choice |
|---|---|
| Mobile | Flutter (Dart), Android + iOS only (Flutter Web removed) |
| Backend | Django + Django REST Framework, JWT (djangorestframework-simplejwt) |
| Database | Neon Postgres (free tier); SQLite fallback for local dev; pgvector for RAG |
| Hosting | Render.com free tier (backend); APK via GitHub Releases |
| Push | Firebase Cloud Messaging |
| Chat | Firebase Firestore (MVP); Django Channels deferred post-pilot |
| Maps | OpenStreetMap via `flutter_map` (no Google Maps billing) |
| OCR | Google ML Kit (on-device) |
| AI | Gemini (trust score, PulseAI) with regex numeric guard |
| Offline | Hive (notification cache) |
| Monitoring | UptimeRobot pinging `/api/health/` every 5 min |
| Localization | Bangla + English |

Backend stays **Django**. The FastAPI rewrite was proposed and rejected.

## 3. Flutter App Architecture
- **Feature-first Clean Architecture**: each feature folder contains `presentation/`, `domain/`, `data/`.
- **Service Adapter Pattern**: abstract interfaces (e.g., `SmsService`) with a mock implementation now and a real provider later, wired via dependency injection.
- **No direct API calls in UI files.** UI → state/controller → repository → data source/service.
- **File size limit:** 200–300 lines per file.
- Routing via `app_router.dart` + `router_notifier.dart` (auth redirect allowlist includes `/language`, `/forgot-password`, `/verify-otp`).

### Feature Modules (high level)
auth/onboarding · feed · blood_hub (search, emergency, campaigns, tracking) · communities · health_hub · profile · chat/messages · notifications · pulseai · admin-facing screens

## 4. Backend Architecture
### Core Models (from `api/models.py`)
Hospital · DonorProfile (unique `nid_hash`, unique phone, rank/badge properties) · BloodRequest · DonationHistory · RecentLog · SocialPost · FakeAccountFlag · AdminAction · Division · District · Upazila · NationalCommunity · MedicalPartner · LocalClub · ExecutiveMember · BloodScienceArticle · CompatibilityRule · DonationGuideSection · EmergencyContact · RecoveryTimelineStep

### Notable Modules
- `views_bloodhub.py` — emergency requests, waves
- `views_wave_engine.py` — WaveMetrics, LivePipeline, ForceEscalate (admin only)
- Admin trust views — QuarantineQueue, TrustWeights, ApproveRequest, RejectRequest, BanUser
- `throttles.py` — EmergencyBroadcastThrottle (3/min), AssistantChatThrottle (10/min)
- `utils.py` — `calculate_bmi` with negative-input guard
- `redact.py` — PII redaction, runs **before** any data reaches the router or Gemini

### Auth
- JWT access/refresh. Password-reset OTP stored as HMAC-SHA256 hash (`otp_hash`, max_length 64).
- OTP is Just-In-Time for blood request submit/accept; email OTP (6-digit) for unregistered users before tracking.

### Health Endpoints
`/api/health/` and `/health/` return 200.

## 5. Key Data Flows
### 5.1 Emergency Request (JIT security + AI gate)
1. Requester fills personal emergency form.
2. JIT: upload NID/birth certificate + medical report; OTP check.
3. On-device ML Kit OCR extracts text.
4. `redact.py` strips PII.
5. Redacted text → Gemini trust scorer → score.
6. Score ≥ 60% → broadcast waves by dispatch scope; below → quarantine queue for admin review.
7. Donor accepts → private two-sided live tracking.

### 5.2 Donor Proximity Search
- Haversine distance on real data; geohash bucketing; ~500 m privacy fuzzing; lat/lng bounds validated server-side.

### 5.3 PulseAI (RAG)
1. User query → redaction.
2. Embedding → pgvector semantic search over verified clinical rows (768 dims).
3. Gemini answers grounded in retrieved rows.
4. Regex numeric guard rejects numbers absent from sources.
5. Rate limiting + sleep/retry for Gemini 5 RPM limit.

### 5.4 Chat
- Firestore stores ciphertext. RSA keypair per user (private key in `flutter_secure_storage`), AES-256 session key. Read receipts (double tick).

### 5.5 Notifications
- Device posts FCM token to Django (`/api/users/update-fcm/`); push sent via FCM; Hive caches offline.

## 6. Environments and Config
- `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `DJANGO_ENV`, `DATABASE_URL` (and `DATABASE_URL_DEV`), `GEMINI_API_KEY`, `EMAIL_*` (5 vars), `FIELD_ENCRYPTION_KEY`.
- Firebase client config files (`google-services.json`, `firebase_options.dart`, `firebase.json`) are untracked; use `.example` templates.
- Service-account JSON and `.env` are gitignored. **Never commit secrets.**
- Release APK: minify/shrink disabled to protect `pointycastle`, `flutter_map`, ML Kit native libs.

## 7. Repositories and Branches
- Repo: `github.com/shawrab27/Blood-Donation`; working branch `fix/ui-polish`; other local branches include `main`, `backup-*`, `feat/*`, `fix/stabilize-core`.

## 8. Known Technical Debt
- Model/DB drift (`nid_hash` type, missing `db_table` declarations) intentionally unfixed.
- CORS: `CORS_ALLOW_ALL_ORIGINS = True` overrides the allowlist — must be tightened before real users.
- Render deployed commit unverified.
- Mock fallbacks ("Sarah Jenkins", "Dr. Alim", "Tanvir Ahmed") to be removed from `app_router.dart`, `live_dispatch_screen.dart`, `blood_hub_view.dart`.
- Firestore chat is MVP-only; Channels migration deferred.
- Render free-tier cold starts.
