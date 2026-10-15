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

## 4. Current Status (as of early Oct 2026)

- Backend live on Render; `/api/health/` 200; UptimeRobot monitor created.
- Flutter app ran end-to-end on a real Android device; some slowness attributed to Render cold starts.
- FCM verified on a real phone; Firestore verified.
- Backend: 77/77 tests passing at last report; `manage.py check` 0 issues.
- PulseAI RAG pipeline built; answer quality still being fixed.
- Ownership/copyright pass done (LICENSE + headers).
- Firebase config files untracked from git; `.example` templates exist.
- commit 0a2671c on fix/ui-polish, features reported, NOT VERIFIED.

## 5. Open Issues and Risks
- Mock names still in some Dart files (remove).
- `IsAdminUser` wrongly applied to `/api/users/update-fcm/` (regression).
- Several `AllowAny` endpoints and one endpoint with no permission class (audit).
- CORS allow-all overrides allowlist.
- Render deployed commit unverified.
- Exposed Firebase keys: check if repo is public; rotate if so (user deferred).
- No device golden-path evidence; admin dashboard not built.
- Model/DB drift left unfixed on purpose.
- An earlier migration run dropped `auth_provider` and `google_photo_url` from `api_donorprofile` on Neon (test data only; no recovery needed).
- 2026-10-08 proof: flutter test +70 -2; analyze 13 warnings; Render=main, DEBUG=True; Neon 0034-0037 unapplied; map simulated; 7 Argon2 users; Flutter Web deployed against locked decision (pending user decision).

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
