# BAUST Pilot Deployment & Feature Plan

This report corrects the generic deployment plan, aligning with the real state of the repository, fixing the missing/broken components, and outlining the strict roadmap for the BAUST pilot.

## 1. Verified Project Reality Check

| Area | Verified Status & Required Action |
| :--- | :--- |
| **Backend Tests** | Tests passing on SQLite locally. **Action:** Must migrate to Neon (PostgreSQL) immediately, as race-condition and PostGIS location tests are invalid on SQLite. |
| **Phone App 127.0.0.1 Bug** | App API base URL was hardcoded to local IP. **Action:** A release build with the production Render URL is required. Not a backend bug. |
| **Router Bug (Language/Auth)** | The `go_router` redirect logic in `router_notifier.dart` is mishandling unauthenticated edge cases for paths like `/language`, `/forgot-password`, and `/verify-otp`. **Action:** Fix the GoRouter `redirectLogic` to safely bypass these routes. |
| **Deleted Folders** | `chat`, `admin`, and `integration_test` folders were removed by `git clean`. **Action:** Verify if any chat/admin screens in the remaining Flutter tree still compile, or rebuild them if they were fully located in those deleted folders. |
| **PulseAI Chatbot** | Production endpoint 404s. Knowledge-base row counts are out of sync (33 vs 42 vs 46). **Action:** Needs a backend rebuild (Track A only) and database sync. |
| **Firebase Keys** | Keys are untracked but unrotated. **Action:** If the repo has ever been public, keys must be rotated immediately before the pilot. |
| **Wave / Trust / GDPR / Role Engines** | Found some Wave Engine backend code (`views_wave_engine.py`), but the others (Trust Engine, Role Editor, GDPR erase) lack verified backend integrations and are mostly HTML/UI. **Action:** Build the missing Django endpoints. |

---

## 2. Terminology & Core Rules Settled

*   **Wording:** We will strictly use **"Donations completed"** and **"Requests supported"**. All instances of "Successfully Transfused", "Life Saved", or "Lives Saved" will be purged to prevent unprovable claims.
*   **Cooldown Interval:** We are standardizing entirely on the **90-day** cooldown (from one constant only). Any stray references to a 120-day deferral in the code or the paper will be updated to 90 days.

---

## 3. Implementation Roadmap: What Goes In and What Waits

The deployment separates the BAUST pilot requirements from paper extras and future scope.

### Phase 1: Must Do First (Core BAUST Pilot & Paper Claims)
*   **Wave Engine (Backend + Force Next Wave):** Do first. This is the main paper claim.
*   **Trust & Fraud Engine:** Do. Explicitly label it "rule-based" (not ML) to avoid paper rejection.
*   **Role & Permission Editor:** Do. Small scope, necessary for admin management.
*   **GDPR Erase / Anonymize:** Do. Critical for a strong privacy section in the paper.
*   **PulseAI Rebuild (Track A only):** Do. Second main section of the paper.
*   **Thanks Letter / Certificate:** Do. Small effort, good UX.
*   **Impact Metrics:** Do. Using the strict wording ("Donations completed", "Requests supported").

### Phase 2: Do After the App is Stable
*   **Auto Poster (Flutter-side, one widget):** Cheap and useful for social amplification.
*   **Passive-donor XP + tier badge (no leaderboard):** Donor engagement without gamification distortions.

### Phase 3: Later (Post-Pilot / Future Scope)
*   **Multi-bag progress bars:** Pushed to later (requires per-donor tracking).
*   **IMEI ban, Support button:** Pushed to after the pilot (low value for the paper, adds risk).
*   **In-app VoIP, Fast-Track QR, hospital 90-day portal, stock ping:** Future work (requires hospital cooperation).
*   **Panic-syntax NLP, retention ML, epidemiology map:** Future work (requires real data gathering first).

---

## Immediate Next Steps
1. **Fix `router_notifier.dart`** so that the Language, Forgot Password, and OTP pages are accessible.
2. **Configure Neon (PostgreSQL)** in the backend `.env` for accurate testing.
3. **Build the Wave Engine Django endpoints** to support the primary paper claim.
