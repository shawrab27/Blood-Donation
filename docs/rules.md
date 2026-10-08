# Blood Pulse — Rules for AI Coding Sessions (Antigravity / Gemini / Claude)

Read this file before every task. These rules override convenience.

## A. Honesty and Verification
1. **No sugarcoating, no hallucinated status.** If something is not tested, say "NOT VERIFIED".
2. **Verify before reporting done.** "Done" requires evidence: command output, test results, or a device run. Show the evidence.
3. Never claim features work from reading code alone. Distinguish: *written*, *compiles*, *tests pass*, *verified on device*.
4. If a command fails or output is missing, report it as failed. Do not guess.
5. Never invent data, names, hospitals, statistics or citations. No mock/fake data in production paths.

## B. Scope Control
6. **One task at a time.** Finish, verify, report, then wait.
7. **Do not propose architecture changes.** Architecture is locked (see Architecture.md).
8. **Google Sign-In allowed (incomplete-profile gate); parked = Facebook/WhatsApp OTP** (monetization, doctor directory, Redis/load balancing, Community President RBAC, national DB tuning, Flutter Web in the mobile app).
9. Do not create unrequested files (docs, plans, READMEs, notes). If you think one is needed, ask.
10. Do not refactor unrelated code. Touch only what the task needs.
11. Minimal unnecessary explanation. Report: what changed, evidence, what is still unverified.

## C. Code Standards
12. Feature-first Clean Architecture (`presentation/domain/data`).
13. **No direct API calls in UI files.**
14. Files stay within **200–300 lines**; split when larger.
15. Use the **Service Adapter Pattern** for external services (SMS, NID, storage, etc.): abstract interface + mock now + real provider later via DI.
16. Strong typing, null safety, no dead code, no commented-out blocks left behind.
17. Every user-visible string goes through localization (Bangla + English).
18. Backend: validate all input server-side (bounds, sizes, types); never trust the client.

## D. Testing and Quality Gates
19. Before declaring any task complete, run and report:
    - `flutter analyze` (0 issues)
    - `flutter test`
    - `python manage.py check`
    - Backend test suite (`python manage.py test` / pytest)
20. Use TDD framing for bug fixes: write the failing test, then fix, then show it pass.
21. After changing permissions, re-run the full suite and re-check **every** endpoint that real users call.
22. Never weaken or delete a test to make it pass.

## E. Security Rules (see security.md)
23. **Never commit secrets** (.env, service-account JSON, API keys, DB URLs, admin keys, passwords).
24. Never log or print PII, tokens, OTPs or medical text.
25. `redact.py` must run before any data reaches the router or Gemini.
26. Default every new endpoint to authenticated; `AllowAny` needs an explicit written reason.
27. Do not run destructive migrations or DB operations without (a) a backup and (b) explicit user approval. Test migrations on a branch/copy first.
28. Never use `git push --force`, never rewrite history, never delete branches without asking.

## F. Product Rules (locked)
29. Only cooldown: **90 days, from one constant only**.
30. Wording: "Donations completed" / "Requests supported". Never "Successfully Transfused" or "Life Saved".
31. Gender: Male / Female only.
32. Blood group locked after save; admin-only edit.
33. 5-tab navbar order: **Feed, Blood Hub, Communities, Health Hub, Profile**.
34. Login has no OTP. OTP is Just-In-Time only.
35. Brand: use locked palette, fonts, logo and slogan (see design.md). No substitutions.
36. Do not make medical claims. Health content must come from verified sources.

## G. Git Discipline
37. Work on the feature branch, small commits, clear messages.
38. Back up (branch/tag) before risky changes.
39. Report `git status` and the commit hash after each task.

## H. Communication Format for Reports
```
TASK: <name>
CHANGED: <files>
EVIDENCE: <command outputs>
VERIFIED ON DEVICE: yes/no
NOT VERIFIED / RISKS: <list>
NEXT: <awaiting user>
```
