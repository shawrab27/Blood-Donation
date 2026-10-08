# Blood Pulse — Product Requirements Document (PRD)

> Status: living document. Items marked **[UNVERIFIED]** were self-reported by an AI coding session and have not been independently tested on a device.

## 1. Product Summary
**Blood Pulse** is a cross-platform (Android + iOS) blood donation management platform for Bangladesh. It connects donors, requesters, blood donation communities and (later) hospitals, with an AI layer that scores the trustworthiness of emergency requests and a health-education hub.

**Slogan (locked):** "You give today , They live today."

**Origin:** Started as a campus Java/JavaFX DBMS project at BAUST; rebuilt as Flutter (mobile) + Django (backend).

**Long-term vision:** national coverage across all 64 districts.
**Current target:** BAUST academic pilot (50–200 student donors), then regional, then national.

## 2. Problems Being Solved
1. Emergency blood requests spread through scattered Facebook posts and phone calls — slow and unverifiable.
2. Fake / spam requests waste donors' time and erode trust.
3. Donor communities (Badhan, Sandhani, Ashar Alo, etc.) work in silos with no shared tooling.
4. Donors do not know their eligibility (90-day cooldown) and have little health guidance.
5. Donor location data is sensitive; existing tools expose it carelessly.

## 3. Goals and Non-Goals
### Goals (current scope)
- Fast donor search by blood group + location, with privacy-safe proximity.
- Emergency request flow with AI trust scoring before broadcast.
- Private, encrypted donor ↔ requester communication.
- Eligibility tracking (90-day countdown).
- Health Hub (education, compatibility, report analysis, aftercare).
- Admin tooling for trust/fraud handling.
- A defensible research paper built on honest, measured pilot data.

### Non-Goals / Explicitly Parked (do NOT build unless user asks)
- Google/Facebook/WhatsApp OTP login
- Sponsorship, ads, monetization, doctor directory
- Redis, rate-limit infrastructure beyond what exists, load balancing, read replicas
- Community President RBAC hierarchy
- National-scale DB tuning
- Flutter Web as part of the mobile app (removed; a separate React/Next.js site is a future project)
- "Unknown / Want to test" blood group flow, diagnostic-center locator (future idea)
- Django Channels chat migration (deferred until after pilot)

## 4. Users and Personas
| Persona | Description | Key needs |
|---|---|---|
| Donor (Student) | BAUST/campus student; verified with Student/Teacher ID | Find requests nearby, know when eligible |
| Donor (Civilian) | Division/zila/upazila based | Same, plus local community links |
| Requester | Patient family / attendant | Fast, trusted donor reach, tracking |
| Community Admin | Club/org member | Visibility into community activity (RBAC hierarchy parked) |
| Platform Admin | Project owner | Approve/reject/ban, monitor trust engine, GDPR-style erase/export |

## 5. Functional Requirements
### 5.1 Onboarding and Auth
- Splash (logo + slogan + capsule "Let's Start") → Language select (EN/BN) → Login (phone + password) → Registration.
- Login has **no OTP**. OTP is **Just-In-Time (JIT)** only: when submitting/accepting a blood request.
- Registration fields: optional avatar; email; primary phone (mandatory); secondary phone (optional); password + confirm; age; gender (Male/Female only); blood group + confirm (locked after save, admin-editable only); Student (institute/dept/batch/class) vs Civilian (division/zila/upazila/village/NID optional); last donation date or "never donated" (feeds 90-day countdown).
- NID / birth certificate / medical report are **not** required at registration; required only inside Blood Hub when submitting an emergency request (JIT security layer).
- Verification uses campus Student/Teacher ID (not government NID) for the pilot.
- Google Sign-In and phone auth exist in the build.
- Google user with incomplete profile: Feed/Health/Communities only; Blood Hub and Profile locked with 'complete your registration'.

### 5.2 Navigation (5 tabs, locked order)
**Feed · Blood Hub · Communities · Health Hub · Profile**

### 5.3 Feed
- Story/post creator (Image / Text / Feeling / Check-in).
- Post actions: React (with count), Comment, Repost (loop-style icon; saved to profile repost archive).

### 5.4 Blood Hub (renamed from Emergency Search)
Three options: **Search for Donor**, **Emergency Blood**, **Blood Campaigns**.
- **Search for Donor:** filters = blood group, campus, division, district, upazila; donor list + OpenStreetMap nearby-donor map. "Request all" → personal emergency form; single request → Priority Blood Requisition form.
- **Emergency Blood:** splits into **National** (event poster, hospitals/camps, needs, pledges; frozen with "no emergency right now" when no event) and **Personal**.
- **Personal emergency form:** blood group, component, units, urgency, condition, dispatch scope (local/district/division/nationwide), hospital + bed, attendant details, optional requisition slip, "Broadcast Emergency Alert (AI Scoring)".
- After a donor accepts: private two-sided live tracking map (requester view / donor view), donation-issue handling, standby nearest-donor alert.
- JIT AI trust scoring gates the broadcast (threshold ≥ 60%).
- Auto Poster Generator (Oct 2026 request): shareable poster for Facebook/WhatsApp, 3 templates (with patient image / without / open), BloodPulse watermark, footer with website + Facebook links, editable fields.

### 5.5 Communities (3 segments, each with its own search)
1. Blood Donation Communities / clubs
2. Hospital Partners & Blood Banks
3. Personal Contacts & Local Guides (call + chat buttons)

### 5.6 Health Hub
Dashboard + 7 segments: AI Report Analyzer, BMI/Weight Tracker, Blood Science education, Blood Compatibility matrix, Donation Guide/FAQs, Resources Hub (hospitals/hotlines), Recovery/Aftercare tracker.

### 5.7 Profile
Avatar with tier badge (Golden/Silver/Bronze), bio, admin-locked blood group, edit-profile (blood group excluded), last-donation update, 90-day countdown, requests chart, user posts, donation history; passive-donor XP + tier badge, no leaderboard.

### 5.8 Chat and Notifications
- WhatsApp-style chat, E2EE (RSA keypair + AES-256 session), read receipts, Firestore for MVP.
- Notification tap opens overlay with **Call Now** or **Message**.
- Push via Firebase FCM; offline notification cache (Hive).

### 5.9 PulseAI (Chatbot / Helpline)
- Answers blood-related questions in Bangla and English; explains platform features; gives donation guidance; de-escalates frustrated users.
- RAG over a vector DB (pgvector, 768 dims) with verified clinical rows; numeric guard against hallucinated values; PII redaction before any data reaches the router or Gemini.

### 5.10 Admin Panel (web dashboard, designed in Stitch — not built)
Pages: Wave Engine Control, Role & Permission Editor, Trust & Fraud Engine, System Health & Ops, Donor Management (Full Erase + Export Data).

## 6. Business Rules (locked)
- **90 days** is the only donation cooldown (from one constant only).
- Wording: "Donations completed" / "Requests supported". **Never** "Successfully Transfused" or "Life Saved".
- Gender options: Male / Female only.
- Blood group is locked after save; only admin can change.

## 7. Non-Functional Requirements
- Works on any phone screen size; smooth transitions; no red-screen errors.
- Free / zero-cost stack for the pilot (free-tier limits must be acknowledged).
- Bangla + English localization.
- Donor location privacy: geohash search with ~500 m fuzzing.
- Files ≤ 200–300 lines; no direct API calls in UI files.
- Tests: `flutter analyze` clean, backend test suite green.

## 8. Success Metrics (pilot, for the research paper)
- Request response latency vs. traditional methods (Facebook/phone).
- Fake-request filtering rate.
- Location accuracy.
All metrics require real pilot data and an ethics/consent process (not yet defined).

## 9. Phased Rollout
1. **Phase 1 — BAUST pilot:** $0, 50–200 student donors.
2. **Phase 2 — Regional:** Rangpur, Play Store + VPS, 1,000–5,000 users.
3. **Phase 3 — National:** grant, Porichoy NID API, SMS gateway, 64 districts.

## 10. Research Paper Constraints
- Working title: *BloodPulse: An AI-Verified, NID-Authenticated Federated Blood Donor Management Platform for National Deployment in Bangladesh* (target: IEEE Access or JMIR; Route A, broad systems paper).
- **Honesty rules for the paper:**
  - AI fraud detection is a prompted third-party LLM call, **not** a trained/novel model — do not overclaim.
  - NID check is OCR pattern-matching, **not** government-verified.
  - Hospital referral is a form field, not an integration.
  - Pilot data collection and consent/ethics are still unscheduled.

## 11. Known Gaps and Risks
- Gemini free tier (rate-limited) cannot support claimed national scale.
- SMS OTP has real per-message cost (contradicts "$0").
- Play Store ($25) and App Store ($99/yr) fees.
- Firebase free-tier caps.
- Render free-tier cold starts (slow responses).
- Medical-report text sent to Gemini conflicts with strong privacy claims unless redacted — keep redaction mandatory.
- Admin panel not built; no systematic device golden-path test evidence yet.
