# Blood Pulse — Design System

## 1. Brand
- **Name:** Blood Pulse (header text: "BloodPulse")
- **Slogan (locked):** "You give today , They live today."
- **Logo (locked):** Heart split into letter **B** (light blue/silver, left half) and letter **P** (deep red `#C30121`, right half) with an ECG/heartbeat line through the center; "Blood Pulse" text below in light blue/silver.
- **Logo asset:** `assets/images/launcher_icon_transparent.png`
- **Logo size:** uniform across all screens (32 px header height).

## 2. Color Palette (locked)
| Role | Hex |
|---|---|
| Primary | `#C30121` |
| Secondary | `#2B2B2B` |
| Tertiary | `#0D68AA` |
| Neutral | `#8E7D7F` |
| Surface | `#FDF3F3` |

Usage: Primary for CTAs, active states and urgent elements; Tertiary for informational accents/links; Surface for backgrounds; Secondary for body text and dark UI.

## 3. Typography
- **Headlines:** Georgia
- **Body / UI:** Inter
- Keep a clear scale (display / title / body / caption); support Bangla glyphs with a compatible fallback font.

## 4. Shape and Components
- **All buttons and inputs are capsule/pill shaped.**
- Cards: soft rounded corners, light elevation on Surface background.
- Chat bubbles: sent = light red tint, received = white, with timestamps and double-tick read receipts.
- Smooth transitions between screens; no abrupt jumps; no red-screen errors.
- Must be responsive on any phone size (test small and large screens).

## 5. Global Layout
### Header (standard, locked)
- Top-left: logo + "BloodPulse".
- Top-right: notification bell (active badge; tap refreshes) + 3-dot menu (Learn more, Contact us, About us, Log out).

### Bottom Navigation (5 tabs, locked order)
1. **Feed**
2. **Blood Hub**
3. **Communities**
4. **Health Hub**
5. **Profile**

## 6. Screen Specifications
### Onboarding
Splash (centered logo + slogan + capsule "Let's Start") → Language select (EN/BN) → Login (phone + password) → Registration.

### Registration
Optional avatar (camera/library) · email · primary phone (mandatory) · secondary phone (optional) · password + confirm · age · gender (Male/Female) · blood group + confirm · Student vs Civilian toggle with relevant fields · last donation date or "never donated".

### Feed
Story/post creator at top (Image / Text / Feeling / Check-in). Posts: React (count), Comment, Repost (loop/recycle arrow icon).

### Blood Hub (Phase 1A Implemented)
Three primary cards layout wired strictly to live Riverpod services:
1. **Search for Donor**:
   - Routed via `/blood-hub/search` with top mode toggle (`Search as Donor` vs `Request for Blood`).
   - Filter chips: Blood Group bottom sheet, Division & Zila selectors, Advanced map toggle.
   - OSM map (`flutter_map`) with fuzzed geohashes (500m precision).
   - Real donor result cards (`DonorCard`) with verified badge, relative donation cooldown, and direct request CTA.
   - Group dispatch: "Request to All" floating button for filtered group broadcast.
2. **Emergency Blood**:
   - Entry point to Priority Blood Requisition form (`/blood-hub/request/direct`).
   - 3-card structure: Patient Details, Location & Urgency (with live hospital autocomplete & Normal/Urgent/Custom time pickers), Medical Verification (camera/file upload).
   - Validation & zero hardcoded fallbacks.
3. **Blood Campaigns**:
   - Real active campaign counter and live snippet; tap routes to Feed tab pre-filtered by `#BloodCampaign`.
- **Top Header**: Logo asset + "BloodPulse" title (Georgia `#C30121`), notification bell with unread badge, profile avatar.
- **Responsive Layout**: Validated against 360dp and 412dp form factors with 0 overflow errors.
- **Phases 1B & 1C**: Poster Editor (4:5 Clean Alert, 4:5 Full Story, 9:16 Story Alert), Emergency Hub (National/Personal), Live Dispatch, Failure Report, and QR landing.

### Communities
Three segments, each with its own search bar: Blood Donation Communities · Hospital Partners & Blood Banks · Personal Contacts & Local Guides (call + chat buttons).

### Health Hub
Dashboard landing + 7 segments: AI Report Analyzer · BMI/Weight Tracker · Blood Science · Compatibility matrix · Donation Guide/FAQs · Resources Hub · Recovery/Aftercare.

### Profile
Avatar with tier badge (Golden/Silver/Bronze) overlapping border · bio · locked blood group · edit modal · last-donation box · 90-day countdown widget · requests chart · posts + Add Post · donation history.

### Notifications
Tap opens a wallpaper-style overlay popup with **Call Now** (tel: intent) and **Message/Chat**.

### PulseAI
Floating entry point; FAB: #C30121 circle, #FF6B7A blood drop + ECG, 1600ms pulse, hidden on auth screens, 4-action sheet; calm, supportive tone; bilingual; shows guarded responses (no red-screen on failure).

## 7. Content and Copy Rules
- Use "Donations completed" / "Requests supported". Never "Successfully Transfused" or "Life Saved".
- Urgent screens: short, clear, action-first copy.
- No fake names or fake hospitals anywhere in UI.
- Bangla and English must both be complete; no untranslated strings.

## 8. Accessibility and UX
- Minimum touch target 44 px; sufficient contrast (check Primary on Surface).
- Clear loading, empty and error states for every list/screen (Render cold-start delays are expected — show a friendly loader).
- Never rely on color alone for urgency; pair with icon/label.

## 9. Design Tooling
- UI generation via Google Stitch connected to Antigravity (MCP). Stitch can crash on large multi-screen prompts or local image attachments — send one screen at a time, use hosted assets.
- Admin panel (web dashboard) pages: Wave Engine Control, Role & Permission Editor, Trust & Fraud Engine, System Health & Ops, Donor Management.
