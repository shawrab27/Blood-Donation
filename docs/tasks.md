# Blood Pulse — Tasks

Legend: `[x]` done and verified · `[~]` reported done, NOT independently verified · `[ ]` pending · `[P]` parked

Working style: **one task at a time**, short steps, evidence required.

## Phase 0 — Safety and Backup
- [ ] Back up current branch state (tag/branch) before further changes
- [ ] Take a Neon DB backup before any migration (previous pg_dump failed via the pooler — use a direct connection)
- [ ] Check whether `github.com/shawrab27/Blood-Donation` is public; if yes, rotate exposed Firebase keys

## Phase 1 — Stabilize App and UI Truth Pass
- [x] Step 0: Stabilize working tree & lock 90-day cooldown:
  - Fixed test failures in `test/features/blood_hub/` (resolved layout bugs, updated obsolete finders, preserved all assertions).
  - Multi-viewport & text scale 1.3 responsive overflow test suite passing (zero `RenderFlex` overflows across 320x568, 360x800, 412x915).
  - Locked 90-day donation cooldown as single source of truth across client (`AppConfig.donorCooldownDays`), backend (`DONOR_COOLDOWN_DAYS = 90`), RAG pipeline, Knowledge Base CSVs, and localized strings (`app_en.arb`, `app_bn.arb`).
  - Verification: `flutter analyze` 0 issues, `flutter test` 150/150 passing, `manage.py check` 0 issues, `manage.py test` 173/173 passing.
- [x] Remove mock fallbacks ("Sarah Jenkins", "Dr. Alim", "Tanvir Ahmed") from `app_router.dart`, `live_dispatch_screen.dart`, `blood_hub_view.dart`, `notification_center_screen.dart`, `feed_provider.dart` (verified 0 hits across `lib/`)
- [x] Remove hardcoded fake phone +8801700000000 from client codebase (verified 0 hits across `lib/`), disable call buttons safely when donorPhone is empty
- [x] Blood Hub UI Phase 1A complete:
  - `BloodHubLandingScreen`: 3 action cards, hero section, feature grid, routed to main shell tab 1
  - `DonorSearchScreen`: Search bar, blood group/division/zila filter chips, 500m fuzzed OSM map pins, real donor cards
  - `PriorityBloodRequisitionScreen`: 3-card form (patient details, location & urgency with hospital directory autocomplete, medical verification upload)
  - 100% test coverage for renders, empty states, error states, and responsive 360dp / 412dp screen layouts (all 14 screen tests passing, 0 analyzer issues)
- [x] Phase 1B: EmailOtpScreen (6-digit keypad + verification), PosterEditor + sheets, ThankYouLetterScreen, FollowUpScreen, DonorTrackingMap (<300 lines per file, zero fake claims)
- [ ] Phase 1C: NationalEmergencyDisaster, LiveDispatch, FailureReport, StandbyAlert, ClosedRequest
- [ ] Remove or kDebugMode-gate the 1-tap Demo Donor login
- [x] flutter test: full test suite passing (107/107 tests); flutter analyze to 0 issues
- [ ] Delete junk files clean_urls.md, concise_urls.md, url_table.md
- [x] Chat: keep ONE Firestore path (chat_rooms); locked down chats/ (403 forbidden); Firestore rules verified with emulator unit tests
- [ ] Fix `IsAdminUser` regression on `/api/users/update-fcm/` (donors must be able to register their own FCM token)
- [ ] Audit every `AllowAny` endpoint and `emergency_requests_list_create_view` (no permission class); lock down or justify each
- [ ] Tighten CORS (remove `CORS_ALLOW_ALL_ORIGINS = True`)
- [ ] Full device golden-path test with pass/fail evidence (auth → camera OCR → PII redaction log → trust gate ≥ 60% → admin approve)
- [x] Two-device end-to-end integration test suite (S1–S8 flow: OTP -> accept -> tracking -> arrived/donated -> thanks -> standby promotion -> E2EE ciphertext -> hardened logout) passing 100% (8/8 tests pass, 146 total backend tests pass)
- [x] Confirm Phase 1A & 1B screens match design.md (palette, pill shapes, 5-tab order, top header)

## Phase 2 — Safe Deploy
- [ ] Verify which commit Render is actually running
- [ ] Render: DJANGO_DEBUG=False
- [ ] Neon: apply 0034-0037, import 36,534 institutions (currently 181), pg_trgm; rehearse on a Neon branch first
- [ ] Merge fix/ui-polish -> main (Render deploys main a13f844; assistant + institutions endpoints 404 live)
- [ ] Test migrations on a branch/copy first; then deploy
- [ ] Confirm UptimeRobot monitor shows Up
- [ ] Release keystore for Play Store (started, unfinished)

## Phase 3 — PulseAI
- [~] RAG pipeline (pgvector, 33-row verified CSV, numeric guard)
- [~] PulseAI floating entry FAB (#C30121 circle, #FF6B7A blood drop + ECG, 1600ms pulse, hidden on auth screens, 4-action sheet)
- [ ] Fix PulseAI answers that were not coming out correctly
- [ ] Rebuild as full chatbot: vector-DB RAG, platform/button guide, donation how/where/fear/health guidance, calm de-escalation
- [ ] PulseAI order must be redact -> pgvector RAG -> grounded Gemini -> numeric guard; api/services/assistant_service.py (Gemini->CSV->helpline) bypasses it
- [ ] KB rows beyond the 33 doctor-reviewed ones are NOT reviewed; hold from production
- [ ] Bilingual (Bangla + English) answer quality check
- [ ] Verify FCM token POST and guarded chatbot UI (no red screen)
- [ ] Expand evaluation (adversarial set) within Gemini rate limits

## Phase 4 — Core Features
- [ ] Admin web dashboard (Stitch design exists): Wave Engine Control
- [ ] Trust & Fraud Engine page
- [ ] Role & Permission Editor
- [ ] Donor Management with GDPR-style Full Erase + Export
- [ ] Tests for wave engine admin views (currently none)
- [ ] Tests for PII scrub / soft-delete / erase flows
- [x] Blood Hub Backend Request Lifecycle v2 (`feature/blood-hub-backend`):
  - 10-state machine (`DRAFT` -> `PENDING_EMAIL_OTP` -> `OPEN` -> `MATCHED` -> `IN_TRANSIT` -> `ARRIVED` -> `DONATED` -> `CLOSED` | `FAILED` | `EXPIRED`) with HTTP 409 conflict protection.
  - Service layer architecture (`blood_hub_lifecycle_service.py`, `targeting_service.py`, `match_operations_service.py`, `emergency_activation_service.py`).
  - Atomic acceptance (`select_for_update`) & dynamic donor/requester phone unmasking post-acceptance.
  - Standby donor promotion on failure report (Haversine nearest, 5-minute timer).
  - Thank you letter generation & 24h follow-up wellness scheduler (management command + secret token internal endpoint).
  - 2-admin dual authorization for National Emergency activation & capacity-deducted disaster pledges.
  - 100% test coverage (10 new lifecycle/emergency tests passing, 139 total backend tests passing, `manage.py check` 0 issues).
- [x] Step 1: Auth & Roles Platform Evolution (`feature/step1-auth-roles`):
  - Single login (Google Sign-In + phone OTP + password credentials; no separate donor/receiver login screens).
  - Registration asks first: "I want to: [Donate & Request Blood] / [Only Request Blood]".
  - `ONLY_REQUEST` accounts: `is_searchable = False`, excluded from `get_base_eligible_donor_queryset`, donation cooldown timer bypassed (`cooldownDaysRemaining == 0`).
  - Google users start with incomplete profile and route directly to Feed; Blood Hub, Community, and Profile protected by soft-wall modal.
  - PulseAI guard for incomplete profiles on personal donor queries returns: "Your blood group is not set in your profile. Please complete registration."
  - Backend migration `0039_donorprofile_user_intent.py` additive with DB default; verified with `sqlmigrate`.
  - Backend tests: 5/5 intent tests pass (`api.tests.test_auth_roles_intent`), 21/21 assistant tests pass (`assistant`).
  - Flutter analyze: 0 issues; Flutter auth tests: 17/17 tests passing.
- [ ] Donor deferral (auto-exclude + auto re-match) using the 90-day rule
- [ ] Blood Hub restructure (merge search + request into one flow)
- [ ] Live donor tracking map: position is SIMULATED by a timer (donor_tracking_map.dart). Needs real GPS -> Firestore (500 m fuzz) -> requester listener
- [~] Google user incomplete-profile gate (Feed/Health/Communities open; Blood Hub and Profile locked with 'complete your registration')
- [~] Passive-donor XP + tier badge (no leaderboard)
- [x] National Emergency Mode Backend (2-admin authorization, active status gate, disaster pledge tracking)
- [ ] Cloudinary image migration

## Phase 5 — Smaller Features
- [~] Auto Poster Generator (3 templates, Canva-like editor, share via `share_plus`, download after submit)
- [ ] Thanks letter
- [ ] Impact page (use approved wording only)

## Phase 6 — Research Evidence
- [ ] Define consent/ethics process for collecting health data from real donors
- [ ] Define pilot metrics: response latency, fraud filtering rate, location accuracy
- [ ] Build metric logging that works without storing unnecessary PII
- [ ] Draft paper sections honestly: LLM-prompted trust score (not a trained model), OCR-only NID check, form-only hospital referral
- [ ] Choose target journal (IEEE Access or JMIR) and check requirements

## Phase 7 — BAUST Pilot
- [ ] Recruit 50–200 student donors
- [ ] Run pilot; collect baseline vs Blood Pulse data
- [ ] Handle issues; record outcomes

## Phase 1 — Profile Evolution & Stitch Alignment (Phase 1)
- [x] Part 1A — Security Hotfix, Models & Additive Migrations:
  - Security Hotfix (Gap #13): Sanitized public profile endpoint `/api/profile/<id>/` with `PublicDonorProfileSerializer`. Stripped `phone_number`, `nid_hash`, `latitude`, `longitude`, `weight_kg`, `address`, `email`, `fcm_token`, `public_lat`, `public_lng`, and `password` for all non-owner and anonymous callers. Added unit test suite `api/tests/test_public_profile_security.py` (3/3 passed).
  - Storage Audit (Part 1A.b): Evaluated Render ephemeral disk vs Cloudinary vs Cloudflare R2 / Firebase Storage. Report upload held pending user choice of private storage provider.
  - Gaps 1–7 Models & Methods (`api/models.py`):
    - `DonorProfile`: `bio` (validated max 120 chars), `weight_kg` (private health data, nullable), `show_in_rankings` (boolean, default True), admin-locked `blood_group`.
    - `DonationHistory`: added `hospital`, `city`, `donation_type` (WHOLE/PLATELET), `how` (VOLUNTARY/EMERGENCY/DRIVE), `bags` (default 1), `volume_ml` (default 450), `linked_request` (FK nullable), `source` (self_reported/verified), `verified` (boolean), `donated_at` (nullable DateField), `created_at`. Bidirectional sync between `bags` and `bags_donated`.
    - `BloodGroupChangeRequest`: user, current_group, requested_group, reason, lab_name, test_date, notes, consent, status, reviewed_by, reviewed_at. Unique open request constraint. Approval atomically updates `DonorProfile.blood_group`.
    - `DonorReview`: reviewer, donor, blood_request, stars (1–5), optional tag, comment (max 200). Strict constraints: unique review per blood request, completed donation check, requester-only check, reviewer != donor check. Maintains `donor.rating_avg` and `donor.rating_count`.
    - `XPEvent`: append-only ledger with `UNIQUE(user, event_type, ref_type, ref_id)`. `XP_LEVEL_THRESHOLDS` (Levels 1–10: 0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500). 100 XP awarded ONLY for verified donations.
    - Model test suite `api/tests/test_profile_phase1a_models.py` (7/7 passed).
  - Additive Migrations: `0053_bloodgroupchangerequest_donorreview_xpevent_and_more.py` and data backfill `0054_backfill_donation_history.py` applied cleanly on SQLite and Neon Rehearsal (`ep-noisy-poetry-b3c07a8m`).
- [x] Part 1B — Endpoints (Fully functional and verified with 17/17 tests passing):
  - `GET /api/profile/me/`: Hero stats, verified bags, 90-day cooldown calculation in Asia/Dhaka, XP and Level progress, registration gate (403 REGISTRATION_INCOMPLETE for incomplete profiles).
  - `PATCH /api/profile/me/`: Bio validation (max 120), weight validation, availability, snooze 1 month, show_in_rankings; rejects blood group mutation with 400.
  - `PATCH /api/profile/me/last-donation/`: Anti-cheat (future date rejected, 90-day cooldown boundary enforced, max 3 attempts/day rate-limit, audit log written).
  - `GET /api/profile/top-donors/`: Top 4 by verified bags (tie-break: earliest donation, id), excludes unverified and show_in_rankings=False; 60s cache.
  - `GET /api/profile/global-rank/`: Paginated leaderboard by verified bags with caller's own rank row; 60s cache.
  - `GET /api/profile/<id>/`: Sanitized public profile, returns 404 for soft-deleted or suspended users.
  - `GET /api/profile/me/stories/`, `GET /api/profile/me/activity/`, `GET /api/profile/me/donations/`: Paginated and ordered by (-created_at, -id); auto_verified badge shown only if server flag is true.
  - `POST /api/profile/blood-group-change/` & `GET /status/`: One open request rule, consent check, encrypted BinaryField report upload with magic bytes validation (PDF/JPEG/PNG).
  - `POST /api/reviews/` & `GET /api/profile/<id>/reviews/`: Rate-limited, requester-only, completed-only, anti-self-review checks, updates rating_avg and rating_count.
  - Django admin: `BloodGroupChangeRequestAdmin` with secure report download and bulk approve/reject actions.
  - Query benchmarks: 0 N+1 queries across top-donors, activity, and donations endpoints.
- [x] Part 1C — Digital Certificate PDF (`reportlab` + `qrcode`) & Public Verification Endpoint:
  - Official SIL Open Font License Noto Sans Bengali font bundled (`fonts/NotoSansBengali-Regular.ttf` & `Bold.ttf`) for full Bengali script support.
  - A4 Landscape layout with primary red `#C30121` double frame, diagonal "BloodPulse" watermark, verified badge, donor ID (`BP-D{id:06d}`), and verified bags count.
  - Signed tamper-proof token using `TimestampSigner(salt='bloodpulse-certificate-v1')`.
  - Dynamic red QR code pointing to public verification endpoint.
  - `GET /api/profile/me/certificate/`: downloads generated PDF; returns 400 `{"code": "NO_VERIFIED_DONATION"}` if verified bags == 0.
  - `GET /api/profile/certificate/verify/`: rate-limited (30/min) public verification endpoint returning minimal public facts (name, blood group, bags, issue date, valid).
  - Test suite: 5/5 passing in `test_profile_certificate.py`; 32/32 full profile test suite passing.

- [x] Phase 2 — Flutter Frontend (1:1 Stitch Parity & Zero Fake Data):
  - Brand & Theme Tokens: Georgia headlines, Inter body, pill shapes (BorderRadius 50), Primary `#C30121`, Surface `#FFF8F7` / `#FDF3F3`, Noto Sans Bengali font registered in pubspec.
  - Hero Card (`ProfileHeroCard`): 176px circular photo with 5px red border (`#C30121`), frosted glass blood group pill inside bottom, upper-right rank capsule, Georgia headline name, bio (max 120 chars), 180x44px pill 'Edit Profile' button, admin-locked blood group disclosure.
  - Stats Row (`ProfileStatsRow`): 3 equal tiles (120px): Bags Donated (caption: "donations completed"), Next Eligible (64px circular canvas progress ring with days left), Last Donation (edit pencil, formatted date, hospital).
  - Rating & XP Row (`ProfileRatingXpCard`): 2 equal cards (104px): Rating (5 blood drop icons + total review count), XP (8px linear progress bar, level & badge tier).
  - Top Donors Leaderboard (`ProfileTopDonorsSection`): 5-column layout with Top 4 active verified donors + 5th column "+N View all Others", and header with tappable "Global Rank →".
  - Heartbeat Tabs Section (`ProfileTabsSection`): `HeartbeatTabIndicator` (3px red line with ECG spike) across 3 tabs:
    1. Your Stories (composer card + timeline feed with blood-drop nodes and like/comment metrics).
    2. Activity Summary (donor ID, verification step progress, auto-verified badge only when server flag is true).
    3. Donation History (verified vs self-reported badge, hospital, date, volume).
  - Footer: "Download Verified Certificate" 56px capsule button ("Platinum Donor • Donor # • Joined" removed).
  - Secondary Screens:
    - `EditProfileScreen`: bio counter (max 120), confidential weight field in kg with clinical badge, show_in_rankings toggle, and Request Blood Group Change button.
    - `BloodGroupChangeScreen`: requested group picker, lab name, test date picker, encrypted report attachment, and affirmative consent checkbox.
    - `GlobalRankScreen`: full nationwide leaderboard with pinned caller rank row, 20-donor pagination, and tier badges.
    - `PublicDonorProfileScreen`: sanitized public profile for `/profile/:id` with zero PII leaks and self-view redirect to `/profile`.
  - Quality Evidence: `flutter analyze` 0 issues; `flutter test` 10/10 tests passing across `profile_v2_feature_test.dart`, `profile_settings_suite_test.dart`, and `step5_profile_snooze_test.dart`.


## Phase 8 — Final Gate
- [ ] All tests green, `flutter analyze` clean, device test evidence saved
- [ ] No mock data, no secrets in git, permissions audited
- [ ] Release APK built and distributed via GitHub Releases
- [ ] Present to Software Development course teacher

## Already Built (self-reported — verify when touched)
- [~] Theme, auth (JWT, Google Sign-In, phone), OTP (JIT), blood requests with AI trust gate, 90-day countdown
- [~] Feed (post/like/comment/repost), Communities, Health Hub, Profile
- [~] E2EE chat with read receipts, Messages tab on Firestore
- [~] FCM push (confirmed on one real phone), offline notification cache
- [~] Bangla + English localization
- [~] Resources Hub wired to `/api/hospitals/`; donor search uses Haversine
- [~] Admin trust views (backend), 77/77 backend tests passing at last report
- [~] Ownership protection: LICENSE files, copyright headers on 336 files
- [x] Neon Postgres + Render deployment live; `/api/health/` returns 200

## Parked (do NOT build unless user asks)
- [P] Google/Facebook/WhatsApp OTP login
- [P] Sponsorship, ads, monetization, doctor directory
- [P] Redis, rate-limit infra, load balancing, read replicas
- [P] Community President RBAC hierarchy
- [P] National-scale DB tuning
- [P] "Unknown blood group" flow, diagnostic center locator
- [P] Django Channels chat migration (after pilot)
- [P] Flutter Web / PWA inside the mobile app (future separate Next.js site)
