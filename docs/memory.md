# Blood Pulse — Project Memory (for AI sessions)

Purpose: give any fresh AI session the context it needs. Read together with PRD.md, Architecture.md, rules.md, design.md, tasks.md, security.md.
**Never store secrets here.** Use `.env` and secret managers.

## 1. Owner Context
- Owner: CSE student at BAUST, Bangladesh. Started from zero coding knowledge (Dart/Flutter learned in parallel).
- Wants beginner-friendly, short, one-task-at-a-time steps (exams ongoing).
- Presents the project to the Software Development course teacher next semester; also targets a research paper.
- AI execution environment: Antigravity (+ Gemini Pro). Prompts for Antigravity are written in English.

## 2. Project Identity
- Name: Blood Pulse. Slogan: "You give today , They live today."
- Separate project: BAUST BloodLink (campus-only MERN project). Do not mix with Blood Pulse.

## 3. Locked Decisions
- Backend stays Django (FastAPI rewrite rejected). DB: Neon Postgres + pgvector. Hosting: Render free tier.
- Flutter app is Android + iOS only. Flutter Web removed. A separate React/Next.js site is a future project.
- Chat stays on Firebase Firestore for MVP (Option B); Channels migration after pilot.
- Maps: OpenStreetMap (`flutter_map`), not Google Maps.
- Verification: campus Student/Teacher ID for pilot; hospital verification/referral removed from scope.
- OTP: Just-In-Time only; none at login/registration.
- 90 days is the only cooldown (from one constant only). Wording "Donations completed" / "Requests supported".
- Gender: Male/Female only. Blood group admin-locked after save; modifications require admin-approved `BloodGroupChangeRequest`.
- Profile Leaderboard: Top Donors + Global Rank exist per Stitch design with minimal fields (`id`, `name`, `photo`, `bags`, `rank`). Users can opt out via `show_in_rankings` (default ON) which excludes them from public boards while retaining private rank access.
- XP Engine: Level thresholds 1–10 (0 to 4500 XP). 100 XP awarded ONLY for verified donations (`verified=True`). Self-reported donations never award XP or count toward leaderboard bags.
- Navbar: Feed, Blood Hub, Communities, Health Hub, Profile.
- Admin panel = web dashboard (not Django admin theme, not Flutter Web).
- Deployment of any web build, if ever: Cloudflare Pages (supersedes earlier Vercel idea).
- Architecture rules: Service Adapter Pattern, feature-first Clean Architecture, 200–300 line limit, no API calls in UI files.
- Scope: Product scope is nationwide Bangladesh (64 districts). Do not reference or hard-code any single institution in product copy, defaults or logic. The Student institution field is a normal data feature.

## 4. Current Status (Phase 0 Baseline - 2026-10-16)

- Working branch: `chore/p0-foundation` (created from `backup-before-p0`, commit `25eb822 "wip: before P0"`).
- Flutter Analyze: 0 errors, 0 warnings, 0 infos (`No issues found!`).
- Flutter Test: 450 passed, 2 failed (`Golden DonorSearch 360dp`, `Golden DonorSearch 412dp` pixel delta) out of 452 tests.
- Django Check: `manage.py check` reports 0 issues identified.
- Django Migrations: `makemigrations --check --dry-run` reports 0 changes detected. Highest migration in repo: `0055`.
- Neon DB Migrations: LIVE READ-ONLY QUERY VERIFIED on production Neon (`django_migrations` table): all migrations 0001 through 0055 are 100% applied (highest: `0055_bloodgroupchangerequest_report_file_content_type_and_more` applied 2026-10-14 22:00:11 UTC). Stale doc claims of 0034-0037 unapplied are debunked and corrected.
- Django Backend Tests: 344 passed, 1 failed, 8 errors (out of 353 tests) on fresh test DB `test_neondb`:
  - 1 failure: `Step4PrivacyByDesignTests.test_backfill_management_command_is_idempotent` (coordinate fuzzing assertion)
  - 8 errors: `Step10DFeedTests.test_seed_feed_demo_creates_posts` (neon.tech host check safety block), 6 product tests in `Step10FProductsTestCase` (neon.tech host check safety block), `PostgresSpatialIndexBenchmarkTest.test_postgres_20k_donor_query_benchmark` (NOT NULL constraint on `emergency_alerts_enabled` from migration 0053).
  - Expected failures verified: Stale 120-vs-90 day eligibility passed (already 90d locked), chat throttle passed, concurrent-accepts passed.
- Gate Script: `scripts/gate.ps1` and `scripts/gate.sh` operational with `docs/known_failures.txt` regression protection.
- Anomaly Tracker: `docs/anomalies.md` tracking all 40 anomalies (#1-#40) with phases and decisions.
- Render Deployed Commit: UNVERIFIED (no deployment configs in repository; needs manual dashboard verification).

## 5. Open Issues and Risks
- Render deployed commit unverified (no Render webhook/config in git).
- 40 open anomalies tracked in `docs/anomalies.md` across Phases 1-6.
- 9 baseline test failures/errors documented in `docs/known_failures.txt`.
- Mock names still in some Dart files (remove in Phase 1+).
- CORS allow-all overrides allowlist (Phase 6 security audit).
- Exposed Firebase keys: check if repo is public; rotate if so (user deferred).
- Model/DB drift: None detected; repo migrations match Neon production at 0055.

## 6. Research Paper Notes
- Working title: "BloodPulse: An AI-Verified, NID-Authenticated Federated Blood Donor Management Platform for National Deployment in Bangladesh". Targets: IEEE Access or JMIR.
- Seven identified research gaps: no AI fake detection, no NID auth, no inter-community federation, no hospital referral integration, no legal deterrent layer, no blood report analysis, no 64-district live location.
- Must be described honestly: fraud detection = prompted LLM (not a trained model); NID = OCR pattern check; hospital referral = form field.
- Needs: pilot data, consent/ethics process, metric logging.

## 7. Repo and Environment
- Repo: github.com/shawrab27/Blood-Donation. Working branch: `fix/ui-polish`.
- Backup branches exist (`backup-2026-10-01`, `backup-before-audit`, `backup-before-migration-fix`).
- Environment variable names (values live only in `.env` / Render): DJANGO_SECRET_KEY, DJANGO_DEBUG, DJANGO_ALLOWED_HOSTS, CORS_ALLOWED_ORIGINS, DJANGO_ENV, DATABASE_URL, DATABASE_URL_DEV, GEMINI_API_KEY, EMAIL_* (5), FIELD_ENCRYPTION_KEY.

## 8. Cost Reality (pilot vs scale)
- Pilot: $0 using free tiers (with caps).
- Later: SMS ≈ BDT 0.30/SMS, VPS $12–40/mo, Porichoy NID ≈ BDT 2–5/verification, Play Store $25 once, Apple $99/yr, Gemini paid tier.
- Commercial ideas (parked): hospital subscriptions, pharma ads, ICT Division grant, DGHS endorsement.

## 9. Session Handoff Workflow
1. Paste handoff into a fresh session.
2. AI confirms understanding in a few lines.
3. AI writes Antigravity prompts for the chosen task only.
4. Antigravity runs it; user pastes the output back; AI reviews critically (no assuming success).

## 10. Update Log
- Keep this section short. Add a dated one-liner after each verified milestone.
- 2026-10-10: Two-device Blood Hub integration (S1-S8) verified 100% on feature/blood-hub-integration; 146/147 backend tests pass, 107/107 Flutter tests pass, 0 analyzer issues, Firestore rules hardened and emulator-verified.
- 2026-10-15: Profile Evolution Phase 1, Phase 2, & Phase 3 100% verified: Gap #13 security hotfix on branch `hotfix/public-profile-leak` (commit `ee3b0f219f4033e042a5640dce58c08d73ca3042`, un-deployed per protocol), sanitized public profile with confidential fields scrubbed, Gaps 1–7 models (`BloodGroupChangeRequest`, `DonorReview`, `XPEvent`, `DonationHistory` sync, `DonorProfile` bio/weight/rankings flag), additive migrations 0053–0055 applied to SQLite and Neon Rehearsal, endpoints (`/profile/me/`, `/last-donation/`, `/ratings/`, `/global-rank/`, `/top-donors/`, `/stories/`, `/donations/`, `/certificate/`), Portrait A4 certificate generation with Noto Sans Bengali font, dynamic red QR & verification endpoint, Stitch-matching Flutter UI with Heartbeat ECG tabs, multi-viewport zero-overflow verification across 5 screen sizes (320x640, 360x780, 390x844, 412x915, 600x1024) and 1.3x text scale, 20/20 Flutter widget tests pass, 12/12 profile backend tests pass, 0 flutter analyze issues, 0 manage.py check issues.
- 2026-10-20: Task P-01 (Anomaly N1) verified on `fix/p01-snooze`: "Pause Emergency Alerts" snooze toggle off bug fixed across client `ProfileModel.copyWith` null clearing and server `donor_snooze_view` explicit `off`/`enable: false` handling; server persists `alert_pause_until` and `emergency_alerts_paused_until` in `ProfileMeView.get()` and `patch()` surviving restart; Wave engine re-includes donor immediately upon turning off; full-size capsule button (`minHeight: 48`) with dynamic countdown and days/months picker (1d, 3d, 7d, 30d, 60d, 90d) below Impact; client rollback on API error. Quality gate `scripts/gate.ps1` 100% PASS (flutter analyze PASS, flutter test PASS with known baseline, manage.py check PASS, makemigrations check PASS, manage.py test PASS). Tag: `after-P-01`.
- 2026-10-20: Task P-04 (Anomaly N4) verified on `fix/p04-search-cards`: Redesigned Blood Hub > Search for Blood result cards to 2-per-row compact dark red (`#960017`) cards with white text (>8.4:1 contrast); soft light surface (`#FDF3F3`) background; strictly enforces 4 privacy fields (donor name, blood group, district, tier) with zero PII; card tap opens detailed modal popup displaying only the 4 privacy fields and prominent Request Blood action; campus chip removed for nationwide scope. Quality gate `scripts/gate.ps1` 100% PASS; `p04_donor_search_card_test.dart` (5/5 PASS), `step4_donor_card_privacy_test.dart` (2/2 PASS). Tag: `after-P-04`.
