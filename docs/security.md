# Blood Pulse — Security Policy and Checklist

Blood Pulse handles sensitive data: phone numbers, location, blood group, medical reports, ID documents. Treat every item here as mandatory.

## 1. Data Classification
| Class | Examples | Handling |
|---|---|---|
| Critical | Passwords, JWT secrets, API keys, service-account JSON, DB URLs, OTPs | Never in git/logs/chat; env vars only |
| Sensitive PII | NID/ID images, phone, email, exact location, medical report text | Redact before AI; minimal retention; encrypted where applicable |
| Internal | Trust scores, admin actions, flags | Admin only |
| Public | Slogan, health education content | No restriction |

## 2. Secrets Management
- `.env` and `firebase-service-account.json` are gitignored — keep it that way.
- Firebase client files (`google-services.json`, `firebase_options.dart`, `firebase.json`) are untracked; use `.example` templates.
- **Action:** check if the GitHub repo is public. If yes, rotate the exposed Firebase keys and restrict them in Firebase/Google Cloud (package name, SHA fingerprint).
- Rotate any credential that was ever pasted in chats, logs, screenshots or commits. Credentials from the early Java prototype (admin key, DB login) must be considered compromised and must never be reused.
- Run a secret scanner (e.g. gitleaks) on full git history; purge if anything is found.
- Never hardcode secrets in Dart or Python source.

## 3. Authentication and Sessions
- JWT (SimpleJWT): short-lived access token, refresh rotation, secure storage on device (`flutter_secure_storage`).
- Passwords hashed with Django's default hashers; enforce minimum strength.
- OTP: Just-In-Time only; store only HMAC-SHA256 hash; expiry + attempt limit; never log OTP values.
- Registration verification via campus Student/Teacher ID (pilot). NID OCR is pattern-matching only — do not present it as government-verified.
- Blood group locked after save; only admin can change, with an `AdminAction` audit record.

## 4. Authorization (RBAC)
- Default: every endpoint requires authentication.
- Admin endpoints (`IsAdminUser`): wave engine, trust queue, ban/approve/reject, trust weights.
- **Known problems to fix and test:**
  - `IsAdminUser` was applied to `/api/users/update-fcm/` — donors must be able to update their **own** token. Use `IsAuthenticated` + ownership check.
  - `AllowAny` endpoints found in audit: `emergency_request_detail_view`, `emergency_wave_tick_view`, `maintenance_tick_view`, `email_otp_send/verify`, `active_deferral_view`, `active_national_emergency_view`, `institution_search`, `upazila_search`, assistant feedback/handoff/quick_actions/consent/conversations_delete. Each needs a written justification or lock-down (tick/maintenance endpoints should require a secret token or admin).
  - `emergency_requests_list_create_view` had no explicit permission class.
  - Viewsets in `api/views.py` were not covered by the permission table — complete the audit.
- Object-level checks: users can only read/modify their own profile, requests, chats and tokens.
- Write a permission test for every endpoint (anonymous, normal user, other user, admin).

## 5. API and Transport Security
- HTTPS only (Render provides TLS). Set `SECURE_*` cookie/HSTS settings for production.
- **CORS:** remove `CORS_ALLOW_ALL_ORIGINS = True`; use a strict allowlist.
- `DEBUG=False` and a strict `ALLOWED_HOSTS` in production.
- Input validation: lat/lng bounds, BMI sanity checks, 5 MB image cap (add similar caps to all uploads), file-type checks.
- Rate limits: EmergencyBroadcastThrottle (3/min), AssistantChatThrottle (10/min); add login/OTP throttles and re-test.
- Return generic error messages; never expose stack traces.

## 6. Privacy of Location
- Geohash search with ~500 m fuzzing; never return exact donor coordinates to other users.
- Live tracking only between a requester and the donor who accepted, only for the active request; stop and delete when finished.
- Donor can opt out/hide from search.

## 7. AI and Medical Data
- `redact.py` must run before any text goes to the router or Gemini. Add tests with realistic Bangla + English samples (names, phones, NID numbers, hospital names).
- Be honest in privacy claims: the Gemini call is a third-party API. Do not claim end-to-end privacy for AI-processed text.
- PulseAI: grounded RAG only; numeric guard; no diagnosis or dosage claims; add a visible "not medical advice" note; escalate emergencies to hotlines.
- Prompt-injection defense: treat user text and OCR text as untrusted; never let it alter system instructions or call tools.
- Keep the Gemini key server-side only.

## 8. Chat Encryption
- RSA keypair per user; private key only in `flutter_secure_storage`; AES-256 session keys; Firestore stores ciphertext only.
- Lock down Firestore rules: a user may read/write only chats they belong to; no public collections.
- Note: key backup/recovery on a new device is unsolved — document the behavior.

## 9. Data Protection and Deletion
- Soft-delete + PII scrub for account deletion; keep non-identifying records (DonationHistory, BloodRequest) intact.
- Admin Donor Management: Full Erase + Export Data (GDPR-style) must be tested.
- Retention policy: define how long OCR text, ID images and reports are kept (recommend delete after verification).
- Encrypt sensitive fields (`FIELD_ENCRYPTION_KEY`); store NID as a hash (`nid_hash`), never plaintext.

## 10. Research Ethics and Consent
- Collect real donor data only after: informed consent screen, purpose limitation, data minimization, withdrawal option, and approval from the appropriate supervisor/ethics body.
- Pilot data used in the paper must be anonymized/aggregated.
- Terms & Conditions with legal enforcement language for fake requests: have it reviewed before real launch.

## 11. Abuse and Fraud Controls
- AI trust score ≥ 60% gate; low scores go to the quarantine queue for admin review.
- FakeAccountFlag + BanUser flow; all admin actions audited.
- Throttles on broadcast, OTP and chatbot endpoints.
- Poster Generator: sanitize user-entered text; do not embed unverified patient photos publicly without consent.

## 12. Logging and Monitoring
- Log security events (failed logins, permission denials, admin actions) without PII.
- UptimeRobot on `/api/health/`; add error tracking later.
- Never log tokens, OTPs, medical text.

## 13. Mobile App Hardening
- Release builds: signing keystore stored offline and backed up securely (never in git).
- No debug banners/logs in release.
- Disable cleartext traffic in release; consider certificate pinning later.
- Review Android permissions: request only camera, location (while in use), notifications.
- Note: minify/shrink is currently disabled for native-library safety — this reduces obfuscation; accept knowingly.

## 14. Pre-Release Security Checklist
- [ ] Secret scan of full git history clean
- [ ] Repo visibility checked; Firebase keys rotated if exposed
- [ ] CORS strict, DEBUG False, ALLOWED_HOSTS set
- [ ] Every endpoint permission-tested (anon / user / other user / admin)
- [ ] `update-fcm` regression fixed and tested
- [ ] `AllowAny` endpoints justified or locked
- [ ] Firestore security rules tested
- [ ] `redact.py` test coverage in Bangla + English
- [ ] Upload size/type limits everywhere
- [ ] Account deletion + export tested
- [ ] Consent screen + ethics approval before real users
- [ ] Incident plan: who to contact, how to revoke keys, how to take the API offline
