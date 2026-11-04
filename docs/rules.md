# Blood Pulse — Rules for AI Coding Sessions (Antigravity / Gemini / Claude)

Read this file before every task. These rules override convenience.
.agents/ (ECC) is reference only; docs/rules.md always overrides it.

## A. Honesty and Verification
1. **No sugarcoating, no hallucinated status.** If something is not tested, say "NOT VERIFIED".
2. **Verify before reporting done.** "Done" requires evidence: command output, test results, or a device run. Show the evidence.
3. Never claim features work from reading code alone. Distinguish: *written*, *compiles*, *tests pass*, *verified on device*.
4. If a command fails or output is missing, report it as failed. Do not guess.
5. Never invent data, names, hospitals, statistics or citations. No mock/fake data in production paths.

## B. Scope Control
6. **Architecture is locked** (see Architecture.md). Do not propose architecture changes.
7. **Google Sign-In allowed (incomplete-profile gate); parked = Facebook/WhatsApp OTP** (monetization, doctor directory, Redis/load balancing, Community President RBAC, national DB tuning, Flutter Web in the mobile app).
8. .md files are allowed when really needed (this file, docs/decisions.md, runbooks); keep them short; say why in the report.
9. **Product scope is nationwide Bangladesh (64 districts).** Do not reference or hard-code any single institution in product copy, defaults or logic. The Student institution field is a normal data feature.

## C. Code Standards
10. **No direct API calls in UI files.**
11. Files stay within **200–300 lines**; split when larger.
12. Use the **Service Adapter Pattern** for external services (SMS, NID, storage, etc.): abstract interface + mock now + real provider later via DI.
13. Strong typing, null safety.
14. Every user-visible string goes through localization (Bangla + English).

## D. Testing and Quality Gates
15. Before declaring any task complete, run and report:
    - `flutter analyze` (0 issues)
    - `flutter test`
    - `python manage.py check`
    - Backend test suite (`python manage.py test` / pytest)
16. After changing permissions, re-run the full suite and re-check **every** endpoint that real users call.
17. Never weaken or delete a test to make it pass.

## E. Security Rules (see security.md)
18. **Never commit secrets** (.env, service-account JSON, API keys, DB URLs, admin keys, passwords).
19. `redact.py` must run before any data reaches the router or Gemini.
20. Never use `git push --force`, never rewrite history, never delete branches without asking.

## F. Product Rules (locked)
21. Only cooldown: **90 days, from one constant only**.
22. Wording: "Donations completed" / "Requests supported". Never "Successfully Transfused" or "Life Saved".
23. Gender: Male / Female only.
24. Blood group locked after save; admin-only edit.
25. 5-tab navbar order: **Feed, Blood Hub, Communities, Health Hub, Profile**.
26. Top Header Pattern: Logo `assets/images/launcher_icon_transparent.png` (height 32px) + `"BloodPulse"` title (Georgia, `#C30121`). Top-right: Notification Bell with active red unread badge (`#C30121`) + Profile Avatar (`CircleAvatar` 36px, circular red border `#C30121`, tap navigates to `/profile`). Do NOT use a 3-dot PopupMenuButton.
27. Notification Screen Tabs: Clicking Notification Bell opens Notification Center with 4 tabs: Feed, Request, Messages, Profile.
28. Design Tokens & Shapes: Primary `#C30121`, Secondary `#2B2B2B`, Tertiary `#0D68AA`, Surface `#FDF3F3` / `#FFF8F7`. Headlines in Georgia; Body/Inputs/Buttons in Inter. Full capsule / pill shape (`BorderRadius.circular(50)`) for buttons and input fields. Wrap all screens in `ResponsiveLayout`.
29. Login has no OTP. OTP is Just-In-Time only.
30. Brand: use locked palette, fonts, logo and slogan (see design.md). No substitutions.
31. Do not make medical claims. Health content must come from verified sources.

## G. Communication Format for Reports
```
TASK: <name>
CHANGED: <files>
EVIDENCE: <command outputs>
VERIFIED ON DEVICE: yes/no
NOT VERIFIED / RISKS: <list>
NEXT: <awaiting user>
```

## ENGINEERING STANDARDS v1
0. ROLE: every task starts with a ROLE line (DevOps/SRE, backend, frontend, QA, security, DB, AI). Work as the best practitioner of that role and state the role in the report.
1. SCOPE: change only what the task lists. If something else must change, or the task cannot be done, STOP and report. Never assume; mark UNVERIFIED.
2. CODE: clean, minimal, idiomatic; no filler comments or boilerplate, no dead code, no copy-paste duplication; comments only for a non-obvious why.
3. PERFORMANCE: suitable algorithms and data structures, state complexity for hot paths; no N+1 queries; index what is queried; paginate; cache where safe; small Flutter rebuilds and web payload; design for 2G/3G and low-end Android.
4. ARCHITECTURE: separate layers (Flutter UI/state/data; Django views/services/models); logic server-side; additive migrations; backward-compatible API changes; new behavior behind a server-side flag, default OFF.
5. NO REGRESSION: before touching shared code list its dependents; if the old behavior has no test, add one first; run the critical-flow tests (launch, request, accept, tracking, chat).
6. TESTS: only tests that protect real flows or the new logic (attack test first for security fixes); no extra tests; stop when acceptance passes.
7. RELEASE: CI green, tag before-<task>, small commits, rollback path stated, deploy only on request; report commit, tests, deploy, UNVERIFIED.

## FEATURE GUARDRAILS v1
- New features: Stitch draft first (max 2 screens per call) approved by me; ONE entry point on the most suitable existing page; no new tab, FAB, header icon or top-level card; Bangla + English strings; no mock data; launch flow untouched.
- Server-side flag default OFF with a kill switch; additive migrations only; never touch the production DB; tell me before a migration deploy.
- Every endpoint: explicit permission class, throttle, owner/participant check (404, not 403), attack test written first and shown failing; no phone/NID/exact location/medical data in public responses; no PII or secrets in logs or push; no free-text medical values.
- Risk rules: public status links = no names/hospital/phone, unguessable token, expiry, noindex; scam/broker lists = flag + admin review, at least 2 independent reports, neutral wording, appeal path, never auto-ban; offline donation log = proof, unverified until reviewed; family data = consent, no phone; sensitive filters opt-in; medical images private/signed; invite links = expiry + usage cap + admin approval; leaderboards = verified counts only.
- Web deploy only; never build an APK unless I say "build APK".
