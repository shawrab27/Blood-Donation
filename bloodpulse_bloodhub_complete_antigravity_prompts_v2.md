# BloodPulse Blood Hub, Complete Antigravity Prompt Pack (v2)

**This replaces the earlier emergency pack.** It covers your full flow: Search + donor map, Emergency (National and Personal), private live tracking, donation issues and standby donors, email OTP verification, and the frozen "no emergency" state. Free and no-cost services only.

## What changed from v1

- Search + donor map, the normal Priority Blood Requisition form, and the "Request All → Emergency form" link are now included.
- Live donor tracking (two-sided, private), donation-issue handling, and a standby-donor ranking algorithm are now included.
- Email OTP (6 digits, animated) is now included. **Render's free plan blocks SMTP ports, so email must go through an HTTPS email API** (Brevo's free plan allows 300 emails a day).
- The Emergency Hub now always shows both cards. When no disaster is active, the National card is **frozen** with a clear "No emergency right now" message.

## Your screens (left to right on the Stitch board)

| # | Screen | Route |
|---|---|---|
| 1 | Blood Hub (Search for Donor, Emergency Blood, Blood Campaigns) | /blood-hub |
| 2 | Search results (search bar, Available Donors, Nearby Donor Network map) | /blood-hub/search |
| 3 | Priority Blood Requisition (normal request form) | /blood-hub/request/direct |
| 4 | Emergency Blood hub (National / Personal cards) | /emergency |
| 5 | Disaster Overview (or frozen state) | /emergency/national |
| 6 | Personal Emergency form | /emergency/personal |
| 7 | Active Requests: journey timeline + live map (Requester View / Donor View) | /journeys, /journeys/:id |
| 8 | Donation Issue / Mark Failed (bottom sheet) | sheet on screen 7 |
| 9 | Standby Donor Alert (backup donor needed) | /standby/:offerId |
| 10 | Identity Verification (email OTP) | /identity/verify |

## How to use

1. Attach the Stitch board screenshot (and any Stitch code export) to **Prompts 0, 6, 7, 8, 9**.
2. Paste the prompts **in order, one at a time**. Read the report before continuing.
3. Prompt 0 saves the rules in the repo. Every later prompt begins by re-reading them.
4. The agent must **never** run migrations on Neon or push to GitHub. You do that yourself after local tests.
5. Task 2 (mock-data cleanup) should be finished first. Prompt 0 checks this.

---

## PROMPT 0: Rules and read-only recon

```
You are working on BloodPulse: Flutter app (Riverpod + go_router), Django REST Framework on Render (free tier), PostgreSQL on Neon, Firebase (Firestore + FCM + Auth), flutter_map + OpenStreetMap, Hive for cache.

We are building the complete BLOOD HUB flow. The attached Stitch board is the visual source of truth for 10 screens: Blood Hub, Search results + donor map, Priority Blood Requisition, Emergency hub, Disaster Overview, Personal Emergency form, Active Requests (live tracking), Donation Issue sheet, Standby Donor Alert, Identity Verification (email OTP). If any text in a screenshot is unreadable or a decision is ambiguous, ASK me. Do not guess.

THIS PROMPT IS READ-ONLY. Do not change app or backend code yet.

STEP 1: Create docs/bloodhub/RULES.md with exactly these standing rules:

1. SCOPE: only the Blood Hub features (search, requests, emergency, tracking, standby, identity OTP, disasters) and their notifications. Do NOT touch feed, chat internals, Health Hub, or the Cloudinary migration. For uploads use Django's default_storage so the later Cloudinary switch is config-only.
2. Never assume file or class names. Inspect the repo and follow its architecture and naming.
3. NO mock, fake or placeholder data in app or backend code. Real loading, empty and error states only. Demo data is allowed only in a local-only management command that refuses to run unless DEBUG=True and the database is local.
4. DESIGN FIDELITY: match the screenshots' layout, hierarchy, spacing, chips, cards and capsule buttons using existing theme tokens (primary #C30121, secondary #2B2B2B). No hardcoded colors or fonts inside widgets. The designs use a serif display font for titles: use the app's existing font if it has one; if a new font is needed, ask me first, bundle it (never fetch at runtime), and make sure it supports Bangla. NO BackdropFilter, blur or glass effects (slow on cheap phones). States not in the screenshots (loading, empty, error, offline, locked, frozen) must reuse the same components and style.
5. i18n: every user-visible string goes through the existing localization system, Bangla and English.
6. RESPONSIVE (any phone): SafeArea everywhere; no fixed heights on anything containing text; chips in Wrap; long content scrolls; pinned bottom bars respect SafeArea and the keyboard; text scale up to 1.5 must not overflow; content max width 560 dp centered on wide screens; touch targets at least 48x48 dp; works from 320x568 dp to tablets.
7. SECURITY AND PRIVACY: the server decides everything that matters (scope, trust, eligibility, who may see what). Never trust client values. Secrets only from environment variables; no API keys in the app. No personal data or OTP codes in logs. Contact phone numbers are revealed only after a donor accepts. Donors appear in search and on the map only if they opted in (is_searchable), and map positions are fuzzed to about 500 m. Live tracking exists only between the matched requester and donor, only while the journey is active, and is deleted afterwards. Strip EXIF/GPS metadata from every uploaded image server-side. Uploaded medical files are private (never public URLs). Never run migrations on Neon or any non-local database. No destructive commands. No git push.
8. EMAIL: Render's free plan blocks outbound SMTP ports (25, 465, 587). Send email only through an HTTPS email API behind an EmailSender interface (Brevo transactional API as the default, env vars BREVO_API_KEY and EMAIL_FROM). A console sender may exist only when DEBUG=True.
9. MAPS: flutter_map with OpenStreetMap raster tiles. Put the tile URL template in ONE config constant so it can be swapped later. Set userAgentPackageName to the real applicationId. Show visible attribution "© OpenStreetMap contributors". No bulk tile prefetching. Routing/ETA is computed by the BACKEND (RoutingService: OSRM public server first, provider swappable, 30 s cache, straight-line fallback at FALLBACK_SPEED_KMH=20 with a 1.4 detour factor). No map or routing keys in the app.
10. ERRORLESS CODE: null-safe parsing that never crashes on unknown or missing server values; sealed AppFailure/Result types instead of raw exceptions in UI; every screen handles loading, empty, error and offline; retry with backoff for idempotent GETs; no force-unwrap (!) in new code; guard every async gap (ref.mounted / mounted); dispose every controller, timer, stream and Firestore/location listener; runZonedGuarded plus FlutterError.onError report to the existing crash logging; idempotency keys on every create action.
11. SMOOTH MOTION: shared route transition (fade-through, 280 ms, easeOutCubic) for all new routes; Hero for donor/hospital cards where natural; AnimatedSwitcher for status changes; skeleton loaders instead of spinners; map markers glide between updates instead of jumping; all motion 400 ms or less and skipped when MediaQuery.disableAnimations is true; RepaintBoundary around maps and animated lists.
12. DEPENDENCIES: prefer packages already in pubspec.yaml / requirements.txt. If a new one is needed, name it and justify it in your report.
13. MEDICAL RULES (compatibility, eligibility, deferral) live in ONE file each with the comment "to be reviewed by qualified medical staff before real-world use".
14. EVIDENCE: every phase ends with a report listing files changed, real command outputs (flutter analyze, flutter test, python manage.py check, python manage.py test), and anything skipped or partial. Never write "done" without this.

STEP 2: Confirm Task 2 is complete: grep the whole repo for "Sarah Jenkins", "Dr. Alim", "Tanvir Ahmed". If found, list and stop.

STEP 3: Inspect the repo and write docs/bloodhub/RECON.md answering:
- Django: existing models and fields for blood requests (including the "normal registration/request form" already in the backend), hospitals, campaigns/camps, donor profile (blood group, campus/institution, last donation date, availability, location, searchable/consent flag, deferral), donation history, FCM tokens, compatibility rules, trust score, ratings.
- How Firebase Admin is initialised and how Django users link to Firebase Auth UIDs. How chat uses Firestore and its security rules (needed for tracking).
- Existing email configuration (SMTP or API) and whether OTP or email verification code exists already.
- Existing storage config; existing FCM sending utility; existing trust scoring and where it runs.
- Flutter: theme tokens and fonts, localization setup, router, current Blood Hub / Live Dispatch / map code, API client + auth interceptor, Hive boxes, applicationId, and which of these packages exist: geolocator, flutter_map, latlong2, image_picker, url_launcher, share_plus, firebase_messaging, flutter_local_notifications, hive, connectivity_plus, cloud_firestore.
- Existing Bangladesh location data (division/district/upazila) and campus list. If none, say so. Do NOT invent it.
- Gaps versus the 10 screens, a proposed model diff (reuse existing models), and risks.

STOP after writing RECON.md and show me a summary. Wait for my approval.
```

---

## PROMPT 1: Backend A (data model, search, map, requests, waves)

```
First read docs/bloodhub/RULES.md and RECON.md and follow them. Build the backend core. Reuse existing models where RECON says they exist. Create migration files but DO NOT apply them to Neon; test on a local database only.

=== DONOR PROFILE ADDITIONS ===
is_searchable (consent, default False, asked at registration/profile), campus (FK or text, per RECON), fulfilled_count, no_show_count, cancel_count, alert_count, response_count, rating_avg, rating_count, last_active_at, last_lat / last_lng (stored FUZZED to about 500 m plus geohash), deferral_until, alert_pause_until.
DeferralRecord: donor, reason (MEDICAL, OTHER), starts_at, until, provisional (bool), request, appeal_status (NONE, PENDING, APPROVED, REJECTED).

=== BLOOD REQUEST (extend or create) ===
mode (EMERGENCY = waves, DIRECT = only the chosen donors);
blood_group; component (WHOLE, RBC, PLATELETS, PLASMA); units_needed (1-10);
urgency (CRITICAL_2H, URGENT_6H, TODAY_24H, SCHEDULED); needed_by (datetime, required for SCHEDULED);
condition_category (SURGERY, ACCIDENT, THALASSEMIA, CANCER, DENGUE, DELIVERY, OTHER); condition_note (max 80 chars, shown only to donors who accepted);
patient_name; patient_photo (private, optional); scope (LOCAL, DISTRICT, DIVISION, NATIONWIDE) and effective_scope;
division, district, upazila; hospital FK (nullable) or hospital_name_other; ward_bed (max 40); attendant_name; contact_phone;
lat, lng, geohash; requisition_slip (private, optional); trust_score, trust_band (LOW, MEDIUM, HIGH);
status (PENDING_ADMIN, ACTIVE, COVERED, FULFILLED, EXPIRED, CANCELLED, REJECTED);
current_wave, next_wave_at, expires_at, escalated_to_admin; client_request_id (UUID, unique per user); is_drill; created_at.
RequestTarget (for DIRECT and for a "Request All" list): request, donor, status (PENDING, ACCEPTED, DECLINED, EXPIRED).
EmergencyNotification: request, donor, wave, sent_at, fcm_status, response; unique(request, donor).
RequestAcceptance: request, donor, status (ACCEPTED, ON_THE_WAY, ARRIVED, DONATED, FAILED, CANCELLED), created_at; unique(request, donor).
FakeReport: request, reporter, reason.
Hospital (reuse): name_en, name_bn, division, district, upazila, lat, lng, phone, is_verified. Management command import_hospitals --csv <path>. Do NOT invent hospital data.

=== SETTINGS CONSTANTS (emergency/conf.py, env-overridable) ===
DONATION_INTERVAL_DAYS=120; EMERGENCY_ALERT_CAP_24H=3; DISASTER_ALERT_CAP_24H=2; DONOR_BUSY_HOURS=6; DIRECT_BLAST_CAP=50;
WAVE_INTERVAL_MINUTES={CRITICAL_2H:10, URGENT_6H:15, TODAY_24H:30};
WAVES: LOCAL [(3 km,15),(7,30),(10,40)]; DISTRICT = LOCAL + [(district-wide,60)]; DIVISION = DISTRICT + [(division-wide,100)]; NATIONWIDE = DIVISION + [(all,200)];
REQUEST_EXPIRY_HOURS={CRITICAL_2H:6, URGENT_6H:12, TODAY_24H:36, SCHEDULED: until needed_by + 6h}; FALLBACK_SPEED_KMH=20.

=== SERVICES (pure functions, each unit-tested) ===
compat.py (WHOLE/RBC standard ABO-Rh; PLASMA reverse ABO ignoring Rh; PLATELETS same ABO first, others in later waves).
eligibility.py: donor is eligible if profile complete, available, is_searchable or otherwise opted in to alerts, last_donation at least DONATION_INTERVAL_DAYS ago, deferral_until and alert_pause_until in the past, not the requester, no active acceptance within DONOR_BUSY_HOURS, fewer than the 24 h alert cap.
geo.py: geohash prefix candidates, then haversine refine; fallback to home upazila/district when a donor has no location.
trust.py: rule-based score 0-100 (email/identity verified, account age, slip attached, prior fulfilled requests, prior fake reports, verified hospital, request frequency). Optional server-side Gemini check ONLY if GEMINI_API_KEY is set in the environment (5 s timeout, never blocks). Bands: HIGH >= 70, MEDIUM 40-69, LOW < 40. Scope ceiling: LOW -> LOCAL only and goes on an admin review list; MEDIUM -> DISTRICT; HIGH -> DIVISION; NATIONWIDE always PENDING_ADMIN until admin approval. If the requested scope is higher than allowed, downgrade and return scope_downgraded=true.
waves.py, notify.py, tick.py as follows.
 waves: build the wave plan from effective_scope; exact group first, then compatible; create EmergencyNotification rows; set next_wave_at. If a "Request All" list is present, wave 0 goes to those donors (eligibility still applies; return skipped counts by reason), then normal waves continue only if scope is wider than the list. After the last wave with no acceptance set escalated_to_admin=true.
 notify: FCM multicast in chunks of 500 using the existing Firebase Admin setup. Data payload: type, request_id, blood_group, units, hospital, urgency. Android priority high, channel "emergency_alerts", ttl by urgency, collapse key = request_id. Remove invalid tokens. Failures are logged without personal data and never raised.
 tick: run_due_waves() uses select_for_update(skip_locked=True) and is idempotent; it also expires overdue requests and deletes/locks requisition slips and patient photos 30 days after a request closes.
accept logic: transaction + select_for_update; at most units_needed active acceptances (later ones get 409 ALREADY_COVERED); when full, status COVERED and no more waves; if an acceptance fails or cancels the status returns to ACTIVE.
images.py: re-encode every uploaded image with Pillow (removes EXIF/GPS), max 1600 px, max 5 MB; PDFs accepted only for the requisition slip (max 5 MB).

=== ENDPOINTS (authenticated; errors as {"code","message"}) ===
GET  /api/donors/search/?q=&blood_group=&campus=&division=&district=&upazila=&lat=&lng=&radius_km=&available_only=true&cursor=  -> cursor-paginated list of opted-in, eligible donors: {id, display_name, blood_group, campus, area, distance_band, last_active_label, rating_avg (only if rating_count >= 3), can_request}. Never returns phone numbers or exact positions. Throttle 60/min/user. Indexes on blood_group, geohash, district, upazila, campus.
GET  /api/donors/map/?bbox=w,s,e,n&zoom=&blood_group=  -> at most 200 items; fuzzed positions; server-side clustering by geohash prefix at low zoom.
GET  /api/hospitals/?q=&lat=&lng=&limit=10
POST /api/emergency/requests/  -> mode EMERGENCY or DIRECT, all fields above, optional target_donor_ids (max DIRECT_BLAST_CAP) and search_snapshot. Idempotent on client_request_id. If the user is not identity_verified (see Prompt 2) return 403 {"code":"IDENTITY_REQUIRED"} and save nothing. Response 201: {id, status, trust_band, effective_scope, scope_downgraded, targeted_count, skipped:{reason:count}}.
GET  /api/emergency/requests/mine/  ;  GET /api/emergency/requests/{id}/  (requester only: status, wave info, counts, accepted donors)
POST /api/emergency/requests/{id}/cancel/  /fulfil/
GET  /api/emergency/incoming/  ;  POST /api/emergency/requests/{id}/accept/  /decline/  /report/
GET  /api/internal/emergency/tick/?token=...  (constant-time compare; UptimeRobot calls it every 5 minutes)
Throttles: create 3/hour/user, accept 20/hour/user.
Permissions: a user reads only their own requests. Slips and photos are served through an authenticated media view to the requester, accepted donors (photo only) and staff.

=== TESTS ===
compat; eligibility; geo radius; wave progression; stop-when-covered; race test on the last slot; scope gating; NATIONWIDE -> PENDING_ADMIN; idempotent create; IDENTITY_REQUIRED gate; search filters and privacy (no phones, only opted-in donors, fuzzed coordinates); map cap and clustering; request-all skipped counts; throttles; tick idempotency; EXIF removed from uploads; permission checks.

Deliver: migration files (not applied to Neon), docs/bloodhub/API.md, and the evidence report.
```

---

## PROMPT 2: Backend B (email OTP identity verification)

```
First read docs/bloodhub/RULES.md, RECON.md and API.md. Build the email-OTP identity verification. Users who are not yet identity_verified must verify by email OTP before they can submit a request, and before live tracking works for them.

=== DATA ===
User/profile: identity_verified_at, verified_email. A user is identity_verified if verified_email is set OR RECON shows they already have a completed verified donor profile/certificate.
EmailOTP: user, email, code_hash, created_at, expires_at (10 minutes), attempts, max_attempts (5), consumed_at, invalidated_at, send_count.
OTPAudit: user, email_hash, ip_hash, event (SENT, SEND_FAILED, WRONG_CODE, LOCKED, VERIFIED, RATE_LIMITED), at.

=== RULES ===
- Generate the code with secrets.randbelow(10**6), zero-padded to 6 digits.
- Store ONLY HMAC-SHA256(code, OTP_PEPPER env + otp id). Compare with hmac.compare_digest. Never log or store the raw code (a console sender may print it only when DEBUG=True).
- One active code per user; a new send invalidates the old one.
- Limits (constants): 60 s between sends per user; max 3 sends per email per hour; max 5 sends per user per day; max 10 sends per IP per hour; max 5 wrong attempts per code, after which the code is locked and a new one is required; after 3 locked codes in 24 h block sending for 1 hour.
- Provider quota guard: a daily counter (EMAIL_DAILY_BUDGET=250, under Brevo's 300/day free limit). When reached return 503 EMAIL_QUOTA_REACHED and flag it in Django admin.
- Normalize emails (strip, lowercase); reject malformed and known disposable domains from a small configurable list.
- Send with the EmailSender interface over HTTPS (Brevo transactional API). 8 s timeout. A failed send does not count against the user's limits and returns EMAIL_SEND_FAILED. Bilingual (Bangla + English) plain and HTML template with the 6-digit code, "expires in 10 minutes", and "If you didn't request this, ignore this email". Never put request or patient details in the email.
- Return the same response shape whether or not the email exists in the system.

=== ENDPOINTS ===
POST /api/identity/email-otp/send/    {email} -> {cooldown_seconds, expires_in_seconds, attempts_left: 5}
POST /api/identity/email-otp/verify/  {code}  -> 200 {identity_verified: true} or 400 {code: "OTP_WRONG", attempts_left} or 423 {code: "OTP_LOCKED", retry_after_seconds} or 410 {code: "OTP_EXPIRED"}
GET  /api/identity/status/            -> {identity_verified, verified_email_masked, method_options: ["EMAIL"]}
WhatsApp and SMS are NOT implemented (they cost money); the API reports only EMAIL.
Error codes must be stable strings the Flutter app can map to localized messages.

=== GATES ===
Enforce identity_verified on: request creation (IDENTITY_REQUIRED), starting or reading a journey/tracking, and accepting a standby offer for the requester side. Donors with completed verified profiles are already verified.

=== TESTS ===
code format; hash-only storage; expiry; attempts and lockout; resend cooldown; per-email, per-user and per-IP limits; daily budget; provider failure handling (mock the HTTP call); old code invalidated by a new send; verify sets identity_verified; gates return IDENTITY_REQUIRED; no code appears in logs.

Deliver docs/bloodhub/OTP.md (env vars: BREVO_API_KEY, EMAIL_FROM, OTP_PEPPER) and the evidence report.
```

---

## PROMPT 3: Backend C (journey, live tracking, donation issues, standby)

```
First read docs/bloodhub/RULES.md, RECON.md, API.md and OTP.md. Build everything that happens AFTER a donor accepts.

=== JOURNEY ===
Journey = RequestAcceptance with a timeline: ACCEPTED -> ON_THE_WAY -> ARRIVED -> DONATED. Log every step in AcceptanceEvent(acceptance, status, at, by, approx_lat, approx_lng).
Endpoints:
GET  /api/journeys/?role=requester|donor&status=active  (a user only ever sees journeys they are part of)
GET  /api/journeys/{id}/  -> timeline, donor {first_name, display_name, blood_group, rating_avg, donation_count, verified}, requester summary, hospital {name, lat, lng}, eta_seconds, distance_m, request summary. Phone numbers appear only for the two participants and only when both are identity_verified.
POST /api/journeys/{id}/on-the-way/   (donor; starts location sharing)
POST /api/journeys/{id}/arrived/      (donor; server checks the last location is within 500 m of the destination, else flags it for review)
POST /api/journeys/{id}/donated/      (donor marks done; pending confirmation)
POST /api/journeys/{id}/confirm-donation/ (requester confirms; if not confirmed within 12 h and no dispute, auto-confirm in tick)
POST /api/journeys/{id}/cancel/       (donor "Can't make it": no medical deferral; a cancel after ON_THE_WAY adds cancel_count; 2 cancels in 30 days shows a warning)
GET  /api/journeys/{id}/route/        -> {polyline (encoded), distance_m, duration_s, source: "osrm"|"fallback"}; RoutingService calls OSRM, caches for 30 s per rounded coordinate pair, falls back to a straight line at FALLBACK_SPEED_KMH; 4 requests/min/journey.
POST /api/journeys/{id}/rate/         (requester, 1-5 stars after DONATED); rating_avg is exposed only after 3 ratings.
Start-deadline check in tick: if a donor has not tapped "on the way" within CRITICAL 15 / URGENT 30 / TODAY 60 minutes, send a reminder at half time; if still nothing 5 minutes after the deadline, mark the acceptance STALLED and (CRITICAL) auto-start standby, otherwise notify the requester with a "Find backup donor" action.

=== LIVE TRACKING (Firestore, free tier) ===
If RECON shows Django users are linked to Firebase Auth UIDs (as chat does), use Firestore:
 Doc tracking/{acceptanceId}: participants [donorUid, requesterUid], requestId, status, destination {lat,lng,name}, donor {lat,lng,heading,speed,accuracy,updatedAt}, requester {lat,lng,updatedAt} (optional, opt-in), etaSeconds, distanceMeters.
 Django (Admin SDK) creates the doc when the journey starts and deletes it when the journey ends (tick removes leftovers within 24 h).
 Update firestore.rules: read only if request.auth.uid is in participants; the donor may write only the donor map, the requester only the requester map; donor writes must be at least 5 s apart (compare request.time to the stored updatedAt); no client can change participants, status or destination.
 Write rules tests if the Firebase emulator is available; otherwise document manual test steps.
If the UIDs are NOT linked, use fallback B instead: POST /api/journeys/{id}/location/ (donor) and GET /api/journeys/{id}/location/ (requester, 5 s polling), stored in a small table and deleted on journey end. Say in your report which one you used.
Client write policy (enforced in docs for the Flutter phase): send at most every 10 s and only if the donor moved at least 25 m or 60 s passed.

=== DONATION ISSUE AND STANDBY ===
DonationIssue: acceptance, reported_by, reason (MEDICAL_REJECTION, NO_SHOW, LOGISTICS), note (max 200), created_at.
POST /api/journeys/{id}/issues/  (requester only; max 3 issues per request)
 MEDICAL_REJECTION: create DeferralRecord for the donor for 90 days (provisional=true), exclude from matching, notify the donor with an "Appeal" action. Donor appeal: POST /api/deferrals/{id}/appeal/ creates an admin review item; admin can lift it.
 NO_SHOW: allowed only after the donor's ETA plus 20 minutes (or the start deadline plus 20 minutes if never started); increments no_show_count; 3 no-shows in 90 days pauses emergency alerts for 14 days (alert_pause_until). No medical deferral.
 LOGISTICS: no penalty.
 In all three cases: acceptance -> FAILED, request goes back to ACTIVE, and STANDBY promotion starts immediately.

STANDBY ALGORITHM (standby.py, weights in conf.py, unit-tested)
 1. When a journey starts, precompute a ranked pool of up to 3 standby donors (not notified yet). Requesters see only a count ("standby ready: 2"), never identities. Donors see their own rank.
 2. Candidate filter: compatible group, eligible (same rules as alerts, but allow one extra alert over the 24 h cap for standby), not previously declined or failed on this request, within the request's effective scope.
 3. Score (0-100): proximity 40 (based on route ETA when available, otherwise fallback ETA: 1 - min(eta_min, 60)/60); reliability 25 (Bayesian: (fulfilled+1)/(fulfilled+no_show+2)); exact group match 15; recent activity 10 (seen in the last 24 h); eligibility margin 5 (days beyond the 120-day interval, capped); response rate 5 (response_count/alert_count, smoothed).
 4. Promotion: re-rank with fresh data at failure time. Offer to the top donor with a response window (CRITICAL 5 min, URGENT 10, TODAY 15). CRITICAL requests offer to the top 2 at the same time. Decline or timeout -> next candidate. After 3 failed offers, skip waiting and trigger the next alert wave immediately.
StandbyOffer: request, donor, rank, offered_at, expires_at, response (PENDING, ACCEPTED, DECLINED, EXPIRED).
GET  /api/emergency/standby-offers/  ;  POST /api/emergency/standby-offers/{id}/accept/  /decline/
 The accept path reuses the normal accept logic (atomic), creates a new acceptance and journey, and the requester's timeline restarts with the new donor. The offer view shows only generic text ("the previous donor could not complete"), the hospital, units, urgency and distance; the requester contact is masked until accept.
FCM types: emergency_request, standby_offer, journey_update, issue_reported, deferral_notice. Channels: emergency_alerts, standby_offers, journey_updates.

=== TESTS ===
timeline transitions and permissions (a third user gets 403); phone reveal only after accept and both verified; arrived proximity check; auto-confirm; start-deadline and stall logic; route cache and fallback (mock OSRM); rating threshold; each issue reason's effect; issue limits; NO_SHOW timing guard; standby scoring order; standby filtering; offer expiry and cascade; three failures trigger the next wave; standby accept race; deferral appeal; tracking doc lifecycle (mock Firestore).

Deliver docs/bloodhub/JOURNEY.md, the firestore.rules diff, and the evidence report.
```

---

## PROMPT 4: Backend D (National / Mass Emergency)

```
First read docs/bloodhub/RULES.md, RECON.md and API.md. Build the national emergency backend. When no event is active the app must show a frozen state, so the API must clearly say so.

=== DATA ===
DisasterEvent: title_en, title_bn, type (FIRE, COLLAPSE, ACCIDENT, BLAST, OTHER), status (DRAFT, PENDING_APPROVAL, ACTIVE, CLOSED), districts (list), poster_image (optional, private storage via default_storage, EXIF stripped), official_note_en / official_note_bn (max 280 chars), created_by, approved_by, activated_at, expires_at (default +72 h), is_drill.
DonationPoint: kind (HOSPITAL, CAMP), name_en, name_bn, lat, lng, address, phone (reuse Hospital or the existing camp/campaign model if it has a location).
HospitalNeed: event, point, blood_group, units_required, units_collected, updated_by, updated_at.
DonationSlot: event, point, starts_at, ends_at, capacity.
Pledge: event, donor, point, slot, code (6 chars, unique per event), status (PLEDGED, ARRIVED, DONATED, NO_SHOW, CANCELLED).
AuditLog: actor, action, object_type, object_id, before, after, created_at (written on every event state change and every need change).

=== ENDPOINTS ===
GET  /api/disasters/active/  -> {"event": null} when nothing is active (the app then shows the FROZEN state), otherwise the event with poster, notes, donation_interval_days, and points: {required, collected, pledged, status NEEDED/PARTIAL/COVERED, urgent_groups[], updated_at, updated_by_display, slots with remaining capacity}. Cache 30 s, invalidate on writes.
GET  /api/disasters/{id}/
POST /api/disasters/{id}/pledges/  {point_id, slot_id}. Server checks: donor eligible; donor group compatible with an open need at that point (else 409 GROUP_NOT_NEEDED; O- always allowed if any need is open); slot capacity; total pledges <= ceil(1.3 x remaining need); one active pledge per donor per event; identity_verified.
POST /api/disasters/{id}/pledges/{pledge_id}/cancel/
=== ADMIN (Django admin, no new UI) ===
DisasterEventAdmin with inlines for HospitalNeed and DonationSlot. Actions: Submit for approval; Approve and activate (approver must be a DIFFERENT staff user than created_by, enforced in the model and admin); Extend 24 h; Close. On activation send a disaster push to eligible donors in event.districts whose group is compatible with an open need (DISASTER_ALERT_CAP_24H). Auto-fill updated_by/updated_at. Drill events are visible and pushed only to staff and testers. tick expires events past expires_at.

=== TESTS ===
null event when none active; two-person rule; cap of 130%; slot capacity; GROUP_NOT_NEEDED; eligibility; drill visibility; cache invalidation; audit log; expiry.

Deliver docs/bloodhub/DISASTER.md (admin guide) and the evidence report.
```

---

## PROMPT 5: Flutter foundation (kits, routing, notifications, location)

```
First read docs/bloodhub/RULES.md, RECON.md, API.md, OTP.md, JOURNEY.md and DISASTER.md. The backend is done. Build the Flutter FOUNDATION only; no final screens yet.

1. Feature structure under lib/features/blood_hub/ following the repo's conventions: data (models, API client using the EXISTING HTTP client and auth interceptor), providers (Riverpod), presentation.
2. Models match the docs exactly. Unknown or missing enum values fall back safely and never crash. Stable error codes map to localized messages (IDENTITY_REQUIRED, ALREADY_COVERED, GROUP_NOT_NEEDED, OTP_WRONG, OTP_LOCKED, OTP_EXPIRED, EMAIL_QUOTA_REACHED, THROTTLED, NOT_ELIGIBLE, EXPIRED, etc.).
3. Routes (go_router): /blood-hub, /blood-hub/search, /blood-hub/request/direct, /emergency, /emergency/personal, /emergency/national, /identity/verify, /journeys, /journeys/:id, /standby/:offerId. Notification taps deep-link correctly when the app is in the foreground, background or terminated. A shared transition (fade-through, 280 ms, easeOutCubic) is applied to every new route.
4. DESIGN KIT (small, reusable, in the style of the screenshots): BpCard, BpChip (selectable), BpPillButton (primary/secondary/disabled/loading), BpStepper, BpSectionHeader, BpStatusChip, BpEmptyState, BpSkeleton (built-in animated gradient, no package), showBpSheet (isScrollControlled, useSafeArea, drag handle), BpErrorBanner with Retry, BpOfflineBanner.
5. MOTION KIT: shake animation (TweenSequence, 350 ms, +-8 px), pop animation (scale 1 -> 1.12 -> 1 in 120 ms), staggered entrance helper, animated countdown text, AnimatedMarker interpolation (1 s glide) for map markers. All respect MediaQuery.disableAnimations.
6. MAP KIT (BpMap): flutter_map with the tile URL from ONE config constant, userAgentPackageName = the real applicationId, visible attribution, recenter button, marker builders (donor, hospital, me), polyline layer, zoom-aware clustering support, and a debounced (500 ms) "bounds changed" callback. Add a NavigateExternally helper that opens a geo: intent with url_launcher (no API key).
7. LOCATION SERVICE (geolocator): permission flow with a short explainer sheet before the system dialog; manual division/district/upazila fallback so a denied GPS never blocks a request; a position stream for journeys with distanceFilter 25 m and, on Android, a foreground-service notification while sharing ("Sharing your location with the requester"); use while-in-use permission plus the foreground service; do NOT request ACCESS_BACKGROUND_LOCATION. Cancel the stream when the journey ends.
8. NOTIFICATIONS: Android channels emergency_alerts, standby_offers, journey_updates (max importance, sound, vibration); handle data types emergency_request, standby_offer, journey_update, issue_reported, deferral_notice, disaster_alert; request POST_NOTIFICATIONS with a short Bangla/English explainer; add a "Make sure alerts reach you" sheet with battery-optimisation/autostart guidance for Xiaomi, Oppo, Vivo, Realme.
9. ERROR HANDLING: sealed AppFailure/Result; runZonedGuarded + FlutterError.onError to the existing crash logging; retry with backoff on idempotent GETs; connectivity provider driving BpOfflineBanner; idempotency key generation (UUID) helper.
10. CACHES (Hive): last active disaster, my open requests and journeys, and the request-form draft. Clear drafts after a successful submit.
11. Tests: model parsing (including bad/unknown values), repositories with a fake HTTP client, error-code mapping, motion helpers respect disableAnimations.

Deliver the evidence report (flutter analyze, flutter test, list of files, new packages with reasons).
```

---

## PROMPT 6: Flutter: Blood Hub, Search + map, Priority Requisition, Emergency hub, Personal form

```
First read docs/bloodhub/RULES.md and the docs. Attach the Stitch board again. Build these screens to match the screenshots. Real API data only; all strings localized (Bangla + English); every screen has loading (skeleton), empty, error and offline states.

1. BLOOD HUB (edit the existing view). Three cards in the designed order: "Search for Donor" (button "Find Now" -> /blood-hub/search), "Emergency Blood" (button "Broadcast Emergency" -> /emergency), "Blood Campaigns" list with "View All Campaigns" (existing routes and data source). Keep any existing behaviour that already works.

2. SEARCH RESULTS (/blood-hub/search):
 - Search bar plus a filter sheet: blood group chips, campus, Division -> District -> Upazila (existing dataset per RECON; if none exists STOP and ask me, do not invent), "available only" toggle, radius. Filters are debounced (400 ms) and reflected as removable chips.
 - "Available Donors" list (infinite scroll, cursor pagination): avatar, name, blood group badge, campus, area, distance band, last active, rating (only when provided), a "Request" button and a selection checkbox.
 - Sticky action bar: "Request Selected (n)" and "Request All (n)".
   * A single donor via "Request" or a selection -> Priority Blood Requisition (mode DIRECT, target_donor_ids).
   * "Request All" -> Personal Emergency form, pre-filled from the filters (blood group, scope from the geography filter, the donor list) and still editable (mode EMERGENCY with target_donor_ids/search_snapshot). Explain in the confirmation sheet how many donors will be alerted and how many are skipped (the server returns skipped counts).
 - "Nearby Donor Network" map (BpMap) under the list, with a list/map toggle: fuzzed donor markers coloured by blood group, clusters at low zoom, tap a marker for a mini card with a Request button, "locate me" button, refresh on bounds change (debounced), the OpenStreetMap attribution visible. Never show exact positions or phone numbers.
 - Empty result: suggest widening filters and offer a "Broadcast Emergency" shortcut.

3. PRIORITY BLOOD REQUISITION (/blood-hub/request/direct), matching the screenshot: optional Patient Photo (camera/gallery, compress to 1600 px, quality 80, max 5 MB), Patient Details (name, required blood type, disease/condition short note max 80 chars, contact number validated with ^(?:\+?88)?01[3-9]\d{8}$), Location and Urgency (hospital search via /api/hospitals/ with GPS-sorted suggestions and a "not listed? type it" option, urgency chips exactly as in the screenshot mapped to the urgency enum, required date/time picker for SCHEDULED), Medical Verification (camera/file upload of prescription or requisition, image or PDF, max 5 MB, with preview and remove), and the "Submit Request" button. On submit: if the server says IDENTITY_REQUIRED go to /identity/verify and resubmit automatically with the same idempotency key; on success show a success sheet ("Sent to N donors") and a button to /journeys.

4. EMERGENCY HUB (/emergency): National Emergency card ("Join Disaster Response" -> /emergency/national) and Personal Emergency card ("Request Blood for Patient" -> /emergency/personal). The National card is ALWAYS shown; when there is no active event it is FROZEN (see Prompt 9).

5. PERSONAL EMERGENCY FORM (/emergency/personal): one scrollable page with a pinned bottom CTA, sections in the screenshot order: Required Blood Group (8 single-select chips), Component Needed (Whole Blood, Packed RBC, Platelets, Plasma), Units/Bags stepper 1-10, Time Urgency chips (Within 2 hours, Within 6 hours, Today), Patient Condition chips (no free-text diagnosis), Dispatch Broadcast Scope radio cards (Local 5-10 km default, District, Division, Nationwide; helper text: "Wider reach needs a higher trust level. Nationwide needs admin approval."), Geographic boundary selectors, Hospital/Clinical Facility and Bed (search + ward/bed max 40), Attendant and Case Details (name and validated phone), optional requisition slip upload. CTA "Broadcast Emergency Alert" is disabled until valid; tap -> confirmation sheet ("O+ · 2 bags · Dhaka Medical · Within 2 hours · Local") -> POST with a fresh idempotency key (IDENTITY_REQUIRED handled as above) -> navigate to the request status (in /journeys as the requester's view). Save the draft in Hive; clear on success. Show the server's scope-downgrade message if returned.

Constraints: RULES.md rules 4, 6, 10 and 11 apply to every screen. Use const widgets, ListView.builder, Riverpod select, and RepaintBoundary around the map.

Deliver the evidence report with a description or screenshot of each screen at 360x640 and 412x915.
```

---

## PROMPT 7: Flutter: Identity Verification (animated 6-digit email OTP)

```
First read docs/bloodhub/RULES.md and docs. Attach the Identity Verification screenshot again. Build /identity/verify to match it, and add the smooth animations. The reference idea (a video the user liked) is: six boxes, a highlighted active box, auto-verify when the last digit is entered, and "Didn't receive the code? Resend". Implement it in native Flutter animations only (no new package).

LAYOUT (as in the screenshot): title "Identity Verification"; short explanation that verification is required before submitting a request or tracking a donor; "Select Verification Method" chips: Email (selected), WhatsApp and SMS shown DISABLED with a small "Soon" tag; Email address field with a "Send OTP" pill; 6 code boxes with the label "Enter 6-digit code"; "Resend in 00:59"; primary button "Verify & Submit Request" (arrow icon); a custom numeric keypad (0-9 and backspace) below.

BEHAVIOUR
- Send OTP -> POST /api/identity/email-otp/send/. Show a sending state on the pill; on success the code boxes slide in and fade in (staggered 40 ms per box) and the resend countdown starts. The countdown uses the server's cooldown_seconds and an absolute deadline timestamp, so it stays correct after the app is backgrounded.
- Input uses the custom keypad (no system keyboard, so the layout never jumps). Add a "Paste code" chip that appears when the clipboard holds exactly 6 digits, and support long-press paste on the boxes.
- Each digit pops in (scale 1 -> 1.12 -> 1) and the active box border animates to the primary color (150 ms). Backspace works across boxes.
- AUTO-VERIFY when the 6th digit is entered (POST /api/identity/email-otp/verify/). The "Verify & Submit Request" button also works and shows a loading state.
- WRONG CODE: boxes shake (350 ms) with a red border and haptic feedback, then clear; show "Incorrect code. N attempts left."
- LOCKED (OTP_LOCKED): keypad disabled and a countdown "Try again in mm:ss" with a Send new code button once allowed.
- EXPIRED: a message and a Resend button.
- SUCCESS: the boxes turn green one after another (wave), a check mark scales in, hold 500 ms, then a fade-through to the next step. When this screen was opened from a request draft, it submits that draft automatically with the SAME idempotency key and shows the result; when opened from tracking, it returns to the journey.
- EMAIL_QUOTA_REACHED / EMAIL_SEND_FAILED / THROTTLED: friendly localized messages with a retry.
- Accessibility: Semantics labels for each box ("Digit 3 of 6, filled"), live-region announcements for errors and success, reduced-motion respects MediaQuery.disableAnimations (states change by color only).
- Responsiveness: the keypad and boxes fit from 320x568; at text scale 1.5 nothing overflows; boxes scale with width (min 40 dp, max 56 dp).
- Resume: if the user leaves and returns while a code is still valid, restore the code-entry state from the server status (do not force a new send).

Tests: widget tests for typing, backspace, paste, auto-verify, wrong code shake state, locked state, success navigation, and the countdown after a simulated background pause.

Deliver the evidence report.
```

---

## PROMPT 8: Flutter: Active Requests (live tracking), Donation Issue, Standby alert

```
First read docs/bloodhub/RULES.md and docs. Attach the tracking, Donation Issue and Standby screenshots again. Build the journey experience. Everything is PRIVATE: a user sees only journeys they take part in.

1. ACTIVE REQUESTS (/journeys): header with back button and "Active Requests"; a segmented control "Requester View" | "Donor View" that switches between journeys where I am the requester and journeys where I am the donor. Each list item opens /journeys/:id. Empty and error states included.

2. JOURNEY SCREEN (/journeys/:id), as in the screenshot:
 - ETA header (for example "18 Mins") with a status chip and text like "2.4 km away · Currently near <area>". Updates as the donor moves.
 - "Donation Journey" 4-step timeline (Accepted, On the way, Arrived at hospital, Donated). The progress line animates between steps; the current step pulses once.
 - Map (BpMap): donor marker gliding between position updates (AnimatedMarker), hospital/destination marker, route polyline from GET /api/journeys/{id}/route/ (refresh at most every 30 s or when the donor moved more than 300 m; draw the last route while refreshing), "recenter" button, an "Open in maps" button, OpenStreetMap attribution. If tracking data is stale (older than 60 s) show "Last seen X min ago" instead of a moving marker.
 - Donor card: name, rating star (only when provided), donation count, verified badge, buttons "Call Donor" (tel:), "Send Message" (existing chat route), and "Donation Issue".
 - REQUESTER VIEW actions: Donation Issue, Confirm Donation Received (after the donor marks done), Rate donor (after DONATED). Optional toggle "Share my location with the donor" (off by default).
 - DONOR VIEW actions: "I'm On My Way" (starts sharing and the foreground notification), "I've Arrived", "I've Donated", "Can't Make It" (confirmation sheet, no penalty note per the server). Requester contact is shown only after accept and both parties verified. Show the destination and, if the requester opted in, the requester's live position.
 - If a user is not identity_verified, show the Identity Verification screen first (IDENTITY_REQUIRED) and return here after success.

3. LIVE TRACKING CLIENT: donor writes position to Firestore tracking/{id} (or the fallback endpoint from JOURNEY.md) at most every 10 s and only if moved at least 25 m or 60 s passed. Requester listens to the same doc. Cancel listeners and the location stream on dispose, on journey end, and when the user stops sharing. Show a persistent "Sharing live location" chip with a Stop button. Never keep sharing after DONATED, FAILED or CANCELLED.

4. DONATION ISSUE SHEET (requester), matching the screenshot: options "Medical Rejection (মেডিকেল রিজেক্ট)" with the small "Auto Standby Ready" tag, "No-show (অনুপস্থিত)", and "Logistics (যানবাহন/অন্যান্য)"; an optional note (max 200 chars, live counter); a warning banner explaining the effect of the chosen reason (Medical Rejection defers the donor for 90 days pending review; No-show is available only after the donor's ETA plus 20 minutes and shows when it unlocks; Logistics has no penalty); primary button "Alert Standby Donor". After submit: the timeline resets, a "Finding your backup donor..." state appears with the standby count from the server, and the new donor's card slides in when one accepts.

5. STANDBY DONOR ALERT (/standby/:offerId), matching the screenshot: "Backup donor needed", the blood group badge with "N Units Needed", the hospital and urgency, distance/ETA card with a small map preview, generic reason text ("the previous donor could not complete"), your standby rank ("You are ranked as 2nd standby donor"), a countdown for the response window, and buttons "Can't Make It" and "I'm On My Way". The requester contact card is MASKED until accept (deliberate privacy change from the screenshot) and unmasks with a slide animation after accept. Handle ALREADY_COVERED and EXPIRED gracefully.

6. DEFERRAL NOTICE (donor): when a provisional 90-day deferral is applied, a clear localized notice with an "Appeal" button that calls /api/deferrals/{id}/appeal/.

Constraints: RULES.md 6, 10, 11 apply. The map must stay smooth at 60 fps on a mid-range phone: RepaintBoundary, no rebuild of the whole screen on each position update (use a dedicated provider and select).

Tests: journey state transitions, view switching, stale-tracking label, sheet validation, standby countdown, and disposal (no listener leaks) using fake streams.

Deliver the evidence report.
```

---

## PROMPT 9: Flutter: National Emergency (frozen state, banner, overview, pledge)

```
First read docs/bloodhub/RULES.md and docs. Attach the Disaster Overview screenshot again.

1. FROZEN STATE (no active event): the National Emergency card in the Emergency hub is greyed and non-interactive, with a shield/check icon, the message "No emergency right now" (Bangla: "এখন কোনো জাতীয় জরুরি অবস্থা নেই", ask me to review the Bangla wording) and a second line "You'll be alerted here when a national emergency is declared." The "Join Disaster Response" button is disabled. Opening /emergency/national without an event (for example from an old notification) shows a full-screen version of the same frozen message with a button back to the Emergency hub. When an event has just closed show "This emergency has ended. Thank you." with totals only if the API provides them.

2. GLOBAL BANNER (app shell, above all tabs, only when an active non-hidden event exists): background = theme secondary (#2B2B2B) with a 3 dp red top edge, a "LIVE" chip with a slowly blinking dot (1.2 s), the event title in the current language, and a chevron; tap -> /emergency/national. Safe-area aware.

3. DISASTER OVERVIEW (/emergency/national) matching the screenshot: header with poster image (cached, with a placeholder), bilingual event title, "Verified by BloodPulse Admin" chip only if approved; official instruction box (2 lines, "Read more" expands to 280 chars); donor eligibility note built from donation_interval_days; cards for hospitals AND camps: name, district, status chip (NEEDED / PARTIAL / COVERED), "Collected Bags 42/100" progress bar with a Semantics label (animate the fill on first load and on updates), urgent blood-group chips, "31 donors on the way", "Updated 8 min ago". Button "Pledge to Donate (Select Slot)"; when no slot remains it is disabled and reads "Pledge to Donate (0 slots left)"; when COVERED show "Fully covered, thank you". Sticky bottom CTA "I'm Ready to Donate": picks the best point for the donor (open need for a compatible group, slots available, nearest if GPS is on) and opens the pledge sheet; if none fits show an honest message that their blood group is not urgently needed right now. Hotline row: "Call 999" and "Fire Service 16163" (tel:), with the numbers in one constants file marked "verify periodically". Pull to refresh; refresh every 60 s while open; offline cache from Hive with an "offline, last updated" notice. A pinned "My pledge" card (code, place, slot, Cancel) when the user has one. Include a small "Directions" button per point that opens an external maps intent.

4. PLEDGE SHEET: slot list with times and remaining capacity -> short self-declaration checklist (age 18-60, weight at least 50 kg, feeling well today, no fever/cough, no donation in the last 120 days). Put the questions in docs/bloodhub/eligibility_questions.md marked "DRAFT: to be reviewed with a doctor". The server still verifies eligibility. Then confirm -> success view with the 6-character pledge code and a directions button. Handle GROUP_NOT_NEEDED, slot full, IDENTITY_REQUIRED and NOT_ELIGIBLE with clear localized messages.

5. A "disaster_alert" notification opens /emergency/national.

Deliver the evidence report.
```

---

## PROMPT 10: Responsive, performance and final QA

```
First read docs/bloodhub/RULES.md. Goal: prove everything works on any phone, is error-free, and finish QA.

1. RESPONSIVE TESTS: widget tests for BloodHub, Search, PriorityRequisition, EmergencyHub (with an active event and frozen), PersonalForm, IdentityVerify, Journeys list, Journey (requester and donor views), StandbyAlert, DisasterOverview at 320x568, 360x640, 393x852, 412x915 and 600x960; text scale 1.0, 1.3, 1.5; locales en and bn. Assert tester.takeException() is null (no overflow), the primary CTA is visible and hittable, and every interactive element is at least 48x48 dp. Fix the UI, not the test.
2. KEYBOARD: focusing the lowest field on each form keeps the field and the CTA reachable.
3. PERFORMANCE: grep for BackdropFilter/blur (none); lists use builders; images cached; motion respects disableAnimations; map screens keep rebuilds local (profile once with the Flutter DevTools performance overlay on a mid-range device or emulator and report frame times); no listener, timer or stream leaks (tests with fake streams).
4. ERROR HANDLING AUDIT: grep new code for "!" force unwraps and unguarded async gaps; simulate server errors (401, 403 IDENTITY_REQUIRED, 409, 423, 429, 500, timeout) and offline for every screen and confirm friendly recoverable states.
5. ACCESSIBILITY: Semantics on chips, stepper, progress bars, OTP boxes, timeline and banner; contrast on #C30121 stays at or above 4.5:1.
6. LOCAL-ONLY DEMO DATA: management command seed_bloodhub_demo (refuses unless DEBUG=True and a local database) creating clearly flagged demo donors, a hospital, a drill disaster and a routing stub, so the whole flow can be tested.
7. END-TO-END CHECKLIST (local backend, one real phone, one emulator). Report PASS/FAIL with evidence for each:
 A. Blood Hub shows 3 options; each opens the right screen.
 B. Search by blood group, then campus, then division/district/upazila; results and map agree; no phones or exact positions anywhere.
 C. Single "Request" opens Priority Requisition; submit works; "Request All" opens the Emergency form pre-filled.
 D. A user without verification hits IDENTITY_REQUIRED, completes email OTP, and the draft submits automatically once.
 E. OTP: wrong code shake and attempts counter, lockout after 5, resend cooldown, expiry, success animation, paste works.
 F. Emergency request sends waves; a second account gets the push and accepts; a third account gets ALREADY_COVERED.
 G. Journey: on the way -> live map moves smoothly -> arrived -> donated -> requester confirms -> rating.
 H. Privacy: a third user cannot read the journey, the Firestore doc or the route; phone shown only after accept and both verified; tracking stops and the doc is deleted at the end.
 I. Donation Issue: Medical Rejection (90-day provisional deferral + appeal), No-show (blocked before ETA + 20 min, then allowed), Logistics; each promotes the standby donor; the requester timeline resets.
 J. Standby cascade: decline and timeout move to the next candidate; three failures trigger the next wave immediately.
 K. National: with no event the card and screen are frozen with the "No emergency right now" message; after a drill event is approved by a second admin the banner appears for staff/testers only, the overview shows correct progress, pledges respect slot capacity and the 130% cap, and expiry freezes it again.
 L. Airplane mode: cached disaster page and my open requests open with an offline notice; the app recovers when the network returns.
 M. Bangla language and font scale 1.5 pass on the OTP screen, the Personal form and the Overview.
 N. Rotation and small-screen (320 dp) check on the OTP keypad and the journey map.
8. FINAL CHECKS: flutter analyze, flutter test, python manage.py check, python manage.py test, makemigrations --check, grep new Flutter files for hardcoded hex colors, grep for "Sarah Jenkins", "Dr. Alim", "Tanvir Ahmed" (zero matches), and confirm no secret or key appears in the diff.
9. Write docs/bloodhub/FINAL_REPORT.md: a table of features (Done / Partial / Skipped with reason), known limitations (for example: waves and standby offers are driven by the 5-minute tick on the free plan, so they can be up to 5 minutes late; OSRM's public server has no guarantee; tracking stops if the OS kills the app), and the list of migrations I must apply to Neon myself.

Do not report completion without real command outputs and the PASS/FAIL table.
```

---

## Notes for you (not for the agent)

- **Email setup (5 minutes):** create a free Brevo account, verify your sender email, create an API key, and add `BREVO_API_KEY`, `EMAIL_FROM` and `OTP_PEPPER` (a long random string) as Render environment variables. Do not use Gmail SMTP: Render's free plan blocks SMTP ports, so it will time out.
- **Email limits:** Brevo's free plan sends 300 emails a day. The prompt caps OTP sends at 250 a day. That is fine for a pilot, but a national launch needs a paid plan or a second provider.
- **Maps:** OpenStreetMap's public tile server is meant for light use. It is fine for a pilot with attribution. Before a big launch, switch the single tile-URL constant to a provider with a free tier or your own tile server. OSRM's public routing server also has no guarantee, so the app falls back to straight-line ETAs if it is down.
- **Live tracking cost:** each moving donor writes to Firestore about every 10 seconds. The free quota is limited, so watch the Firebase usage page during your pilot.
- **Location permission:** the design avoids "background location" permission because Google Play reviews it strictly. Tracking works while the app is open or shows its foreground notification.
- **Medical review:** compatibility rules, the 120-day interval, the 90-day deferral and the eligibility questions are drafts. Have a doctor or your teacher review them before real use, and say so in your research paper.
- **Data you must provide:** a hospital CSV, a campus list, and a Bangladesh division/district/upazila dataset. The agent is told to ask instead of inventing them.
- **Design changes I made on purpose:** the Standby screen hides the requester's contact until the donor accepts; WhatsApp and SMS OTP are shown as disabled ("Soon") because they cost money; there is no blur or glass effect.
