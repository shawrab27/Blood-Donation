# Blood Pulse — Design System

## 1. Brand
- **Name:** Blood Pulse (header text: "BloodPulse")
- **Slogan (locked):** "You give today , They live today."
- **Logo (locked):** Heart split into letter **B** (light blue/silver, left half) and letter **P** (deep red `#C30121`, right half) with an ECG/heartbeat line through the center; "Blood Pulse" text below in light blue/silver.
- **Logo asset:** `assets/images/Blood Pulse logo.jpg`
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

### Blood Hub
Three entry cards: Search for Donor · Emergency Blood · Blood Campaigns.
- Search: filters (blood group, campus, division, district, upazila) + list + OSM map.
- Emergency: National (poster, hospitals/camps, needs, pledges; frozen state "no emergency right now") and Personal (emergency form).
- Tracking: private two-sided live map (requester view / donor view).
- Poster Generator: Canva-like editor, urgent creative look, logo watermark, footer with website + Facebook links, editable fields; 3 templates.

### Communities
Three segments, each with its own search bar: Blood Donation Communities · Hospital Partners & Blood Banks · Personal Contacts & Local Guides (call + chat buttons).

### Health Hub
Dashboard landing + 7 segments: AI Report Analyzer · BMI/Weight Tracker · Blood Science · Compatibility matrix · Donation Guide/FAQs · Resources Hub · Recovery/Aftercare.

### Profile
Avatar with tier badge (Golden/Silver/Bronze) overlapping border · bio · locked blood group · edit modal · last-donation box · 120-day countdown widget · requests chart · posts + Add Post · donation history.

### Notifications
Tap opens a wallpaper-style overlay popup with **Call Now** (tel: intent) and **Message/Chat**.

### PulseAI
Floating entry point; calm, supportive tone; bilingual; shows guarded responses (no red-screen on failure).

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
