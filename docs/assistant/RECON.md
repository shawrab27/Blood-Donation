# BloodPulse AI Assistant - Reconnaissance Report

### 1. Gemini Integration Status
- **Where it's called:** Server-side only, inside `api/views.py` (specifically `GeminiReportAnalyzeView`).
- **Package:** Uses the official `google-genai` Python package.
- **Key Storage:** The key is stored securely in the server environment as `GEMINI_API_KEY` and is accessed via `os.environ.get("GEMINI_API_KEY")`.
- **App-side Usage:** **No actual key usage or AI logic exists in the Flutter app.** The file `nid_verification_screen.dart` contains a comment (`// Simulate Gemini OCR extraction`), but there are no imports or API calls bypassing the server.

### 2. Reusable Features
- **UI (Chat):** `ChatScreen` (`chat_screen.dart`) already exists for 1-on-1 human chat. It uses a capsule input bar, real-time message bubbles, WhatsApp-style read receipts, and is integrated with Riverpod. This UI structure is ideal to be repurposed or subclassed for the AI assistant chatbot.
- **Donor Profile:** `DonorProfile` (in `api/models.py`) tracks useful fields like `last_donation_date`, `total_bags_donated`, `blood_group`, `district`, `is_verified`. These fields can be safely fed (after redaction of PII) to the Gemini context to personalize responses.
- **Request Status Endpoints:** `api/views_bloodhub.py` contains endpoints tracking milestones (`journey_status_transition_view`: `ACCEPTED`, `ON_THE_WAY`, `ARRIVED`, `DONATED`). We can leverage these models to allow the Assistant to summarize a user's active requests.
- **Admin & Throttle:** Django admin utilizes `IsSuperAdminOrGroup` permissions, an `AdminAuditLogMixin`, and `AdminAction`. Rate limiting is already robustly implemented using Django Rest Framework throttles (e.g., `OTPAnonThrottle`, `DonorsUserThrottle`, `RequestsThrottle`). A dedicated `AssistantThrottle` can easily be plugged into the existing throttle pipeline.

### 3. Database Constraints
- **pg_trgm on Neon:** The backend uses Neon PostgreSQL. Neon supports all standard Postgres extensions, meaning `pg_trgm` can be safely enabled via a Django migration in the future for fuzzy searching if needed. It is not currently enabled in the repo.

### 4. Localization, Theming, Router, and Cache Setup
- **Localization:** The Flutter app relies on `AppLocalizations.of(context)` with an `.arb`-based setup (e.g., `l10n?.regBloodGroup`).
- **Theme Tokens:** The `AppColors` class (`lib/core/theme/app_colors.dart`) contains all necessary brand tokens (`primary`, `secondary`, `surface`, `error`).
- **Router:** The app relies on `go_router`, allowing us to smoothly register new routes (e.g., `/assistant`) inside the existing configuration.
- **Hive Setup:** Hive and `hive_flutter` are fully initialized (`await Hive.initFlutter()`). A `notifications_box` is already active; we can safely open an `assistant_box` to cache conversation history or input drafts.

### 5. Gaps, Risks, and Proposed Model List

**Gaps & Risks:**
- **Medical Hallucinations:** The highest risk is the AI attempting to provide medical diagnosis or advice. **Mitigation:** Strictly ground the prompt in an authoritative, doctor-reviewed Knowledge Base (KB) and use strict system instructions to refuse out-of-scope medical queries.
- **Data Privacy & PII Leakage:** Real names, phone numbers, NID hashes, and exact GPS coords must not be passed to the Gemini API. **Mitigation:** Implement strict server-side PII redaction *before* the payload is sent to Gemini (enforcing Rule 5).
- **Latency & UX:** AI text generation takes time. **Mitigation:** The Flutter UI must handle the "typing..." state gracefully, and server-side timeouts must be enforced to prevent locking up the app.

**Proposed Model List:**
- **Django Backend:**
  - `AssistantKnowledgeArticle` (Model for the doctor-approved knowledge base).
  - `AssistantLog` (Temporary table to log redacted conversations for auditing; wiped after 30 days).
- **Flutter App (Riverpod):**
  - `AssistantScreen` (UI replicating the design language of `ChatScreen`).
  - `AssistantMessageModel` (Data class for chatbot bubbles).
  - `AssistantController` / `AssistantService` (To handle HTTP requests to the Django backend and manage local Hive cache).
