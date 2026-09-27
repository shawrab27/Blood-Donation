1. SCOPE: only the assistant feature. Do not touch other features except adding the entry points named later.
2. Never assume file or class names; inspect the repo and follow its conventions.
3. The Gemini API key is used ONLY on the Django server, read from the environment variable GEMINI_API_KEY. The model name comes from GEMINI_MODEL (no hard-coded model names). No key or model secret in the Flutter app, the repo, logs or docs.
4. NO mock data. The medical Knowledge Base content is provided by me (doctor-reviewed). You must NOT write medical facts. You may draft app-how-to entries from the real screens and mark them DRAFT.
5. PRIVACY: never send names, phone numbers, emails, NID-like numbers, addresses, hospital names or medical records to Gemini. Redact before sending and before logging. Log only redacted text, only for users who consented, and delete after 30 days.
6. SAFETY: the assistant is not a doctor (no diagnosis, no medicine or dosage advice, no report interpretation). Medical and eligibility facts come only from APPROVED KB entries. Emergencies are handled by rules before any AI call.
7. i18n: every user-visible string uses the existing localization system, Bangla and English.
8. DESIGN: use existing theme tokens (primary #C30121, secondary #2B2B2B), capsule buttons, no BackdropFilter/blur, fonts with Bangla support.
9. RESPONSIVE (any phone): SafeArea; no fixed heights on text; works from 320x568 dp to tablets; text scale 1.5 must not overflow; keyboard never hides the input.
10. ERRORLESS: null-safe parsing, sealed failure types, loading/empty/error/offline states everywhere, no force unwraps, dispose controllers and timers, idempotent retries, guard async gaps.
11. SECURITY: server decides everything; rate limits on every endpoint; no migrations on Neon or any non-local database; no destructive commands; no git push.
12. DEPENDENCIES: prefer packages already in pubspec.yaml / requirements.txt; justify any new one (for the server use the official Google Gen AI Python SDK, google-genai, unless RECON shows another is already in use; check its current docs).
13. EVIDENCE: every phase ends with real command outputs (flutter analyze, flutter test, python manage.py check, python manage.py test) and a list of anything partial or skipped. Never write "done" without them.
