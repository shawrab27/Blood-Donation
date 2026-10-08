# Blood Pulse — Tasks

Legend: `[x]` done and verified · `[~]` reported done, NOT independently verified · `[ ]` pending · `[P]` parked

Working style: **one task at a time**, short steps, evidence required.

## Phase 0 — Safety and Backup
- [ ] Back up current branch state (tag/branch) before further changes
- [ ] Take a Neon DB backup before any migration (previous pg_dump failed via the pooler — use a direct connection)
- [ ] Check whether `github.com/shawrab27/Blood-Donation` is public; if yes, rotate exposed Firebase keys

## Phase 1 — Stabilize App and UI Truth Pass
- [ ] Remove mock fallbacks ("Sarah Jenkins", "Dr. Alim", "Tanvir Ahmed") from `app_router.dart`, `live_dispatch_screen.dart`, `blood_hub_view.dart`
- [ ] Remove hardcoded fake phone +8801700000000 (6 places incl. api/models.py default, live_dispatch call button)
- [ ] Remove or kDebugMode-gate the 1-tap Demo Donor login
- [ ] flutter test: fix countdown_test (expect 90) and profile_screen_test; flutter analyze to 0 issues
- [ ] Delete junk files clean_urls.md, concise_urls.md, url_table.md
- [ ] Chat: keep ONE Firestore path (chat_rooms vs chats); audit rules for both
- [ ] Fix `IsAdminUser` regression on `/api/users/update-fcm/` (donors must be able to register their own FCM token)
- [ ] Audit every `AllowAny` endpoint and `emergency_requests_list_create_view` (no permission class); lock down or justify each
- [ ] Tighten CORS (remove `CORS_ALLOW_ALL_ORIGINS = True`)
- [ ] Full device golden-path test with pass/fail evidence (auth → camera OCR → PII redaction log → trust gate ≥ 60% → admin approve)
- [ ] Two-device test (requester + donor), FCM notifications, real donor on the map
- [ ] Confirm every screen matches design.md (palette, pill shapes, 5-tab order, header)

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
- [ ] Donor deferral (auto-exclude + auto re-match) using the 90-day rule
- [ ] Blood Hub restructure (merge search + request into one flow)
- [ ] Live donor tracking map: position is SIMULATED by a timer (donor_tracking_map.dart). Needs real GPS -> Firestore (500 m fuzz) -> requester listener
- [~] Google user incomplete-profile gate (Feed/Health/Communities open; Blood Hub and Profile locked with 'complete your registration')
- [~] Passive-donor XP + tier badge (no leaderboard)
- [ ] National Emergency Mode (admin mass broadcast + hospital inventory)
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
