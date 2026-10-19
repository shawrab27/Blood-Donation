# BloodPulse Nationwide Deployment & Architecture Plan

This document establishes the verified deployment plan and system architecture for the nationwide launch of BloodPulse across all 64 districts of Bangladesh.

---

## 1. Product Scope & Institutional Target

- **Geographic Scope**: Nationwide Bangladesh (64 districts, 8 divisions, 495 upazilas).
- **Decoupled Architecture**: No single academic institution, hospital, or region is hardcoded in application logic, routing, or defaults.
- **Educational & Professional Affiliations**: Student/institution fields (`institution`, `occupation`) are regular user profile metadata rather than structural tenancy barriers.
- **Audience**: Voluntary blood donors, emergency patients/requesters, volunteer blood organizations, and accredited healthcare facilities nationwide.

---

## 2. Verified Technical Architecture

| Component | Implementation & Deployment Architecture | Status |
| :--- | :--- | :--- |
| **Backend API** | Django 5.2 + Django REST Framework deployed on Render. Automated tests run against isolated in-memory/SQLite or staging PostgreSQL instances (`USE_SQLITE=1`). | Verified & Hardened |
| **Database** | Neon Serverless PostgreSQL with pgvector and spatial index support for production. Additive-only migrations (0001 through 0060). | Verified |
| **Mobile Client** | Flutter 3.x for Android & iOS. Uses `ApiConfig` with dynamic candidate fallback discovery and zero circular proxies. | Verified |
| **Security & Cleartext** | `android:usesCleartextTraffic` strictly removed from production AndroidManifest; isolated to debug manifest. `READ_EXTERNAL_STORAGE` scoped to `maxSdkVersion="32"`. | Verified |
| **Release Signing** | Gradle release signing enforced via `android/key.properties`. Fails fast with clear error if keystore credentials are missing. Keystores strictly git-ignored. | Verified |
| **Authentication & Tokens** | SimpleJWT with 1-hour access, 7-day refresh, token rotation, and secure encrypted storage in `FlutterSecureStorage`. Session revocation on logout clears `UserDevice` and FCM tokens. | Verified |
| **Transactional Email / OTP** | Modular `EmailService` supporting Mailjet v3.1 HTTPS API, Resend, and Brevo. Guaranteed `locmem` test isolation during automated test runs. | Verified |
| **Emergency Wave Engine** | 5-Wave expanding geographic radius dispatcher with automated standby promotion, atomic double-booking prevention, and donor eligibility cooldowns (90 days). | Verified |
| **Realtime Chat & Media** | `DirectMessage` real-time journey chat with N+1 query elimination (`select_related`), delivery/read receipts, persistent remote storage for voice notes, and 7-day automated voice cleanup. | Verified |
| **Geospatial & Mapping** | OpenStreetMap (OSM) tile rendering with mandatory attribution, privacy-fuzzed donor coordinates, and server-side OSRM routing proxy with haversine fallback. | Verified |
| **PulseAI Health Assistant** | Multimodal health assistant powered by Gemini 2.5 Flash, guarded by prompt-injection filters, with on-device Bangla TTS and deterministic CBC report analyzer. | Verified |

---

## 3. Core Terminology & Platform Rules

1. **Impact Wording**: Strictly use **"Donations completed"** and **"Requests supported"**. Claims of "Lives Saved" or "Successfully Transfused" are prohibited as unprovable medical claims.
2. **Standard Deferral Interval**: Uniform **90-day cooldown** across all backend eligibility queries, profile countdowns, and snooze pickers.
3. **Zero Fake Data Policy**: All mock pins and fake donor fallbacks are banned; empty states honestly communicate real-time donor availability and offer radius expansion.
4. **Privacy by Design**: Donor contact information and exact GPS coordinates are masked; coarse geohashes and fuzzed markers protect donor residential privacy.

---

## 4. Nationwide Rollout Roadmap

### Phase 1: Operational Launch (Ready)
- [x] Canonical Bangladesh phone normalization (`+8801XXXXXXXXX`) across auth, registration, and profile queries.
- [x] Unified OTP service for password reset and blood requisition confirmation.
- [x] End-to-end two-device emergency journey flow: request -> wave notification -> acceptance -> chat/voice -> donation confirmation.
- [x] National Emergency 64-district filter screen and verified hospital directories.
- [x] Security hardening: FCM token revocation on logout, dependency pinning, and release signing enforcement.

### Phase 2: Post-Launch Scale & Monitoring
- [ ] Connect Redis/Upstash cluster for distributed multi-instance caching in high-load emergency spikes.
- [ ] Monitor Mailjet/Brevo delivery webhooks and bounce rates across Bangladeshi telecom domains.
- [ ] Establish telemetry dashboards for wave progression times, donor response latencies, and journey completion rates.

---

## 5. Deployment Verification Checklist

1. **Pre-flight Gate**: Run `scripts/gate.ps1 -KeepDb` to verify all 5 acceptance criteria.
2. **Environment Configuration**: Ensure `EMAIL_PROVIDER`, `MAILJET_API_KEY`, `MAILJET_SECRET_KEY`, and `GEMINI_API_KEY` are populated in the production environment settings.
3. **Android Release Build**: Verify release build with `flutter build apk --release` or App Bundle generation following `docs/release_signing.md`.
4. **Database Readiness**: Execute additive migrations on target PostgreSQL instance (`python manage.py migrate`).
