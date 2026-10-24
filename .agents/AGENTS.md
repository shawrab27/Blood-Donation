# BLOODPULSE MANDATORY AGENT RULES & PATTERN REGISTRY

Before executing any prompt or command, strictly enforce these mandatory BloodPulse UI alignment rules (which fix and override Stitch UI mistakes):

### 1. TOP HEADER PATTERN (TOP BAR RULE)
- **Top-Left**: Logo asset `assets/images/launcher_icon_transparent.png` (height: 32px) + `"BloodPulse"` title (Georgia font, deep red `#C30121`).
- **Top-Right**:
  1. Notification Bell icon (`Icons.notifications_outlined`) with active red unread badge (`#C30121`).
  2. **Profile Avatar** — a `CircleAvatar` (36px, circular, red border `#C30121`) showing the logged-in user's profile picture, a first-letter fallback, or a guest icon (`Icons.person_rounded`). Tapping navigates to the Profile screen (`/profile`). **Do NOT use a 3-dot PopupMenuButton.**

### 2. DOWN NAV BAR PATTERN (5 PERSISTENT TABS)
- Standard persistent bottom navigation bar across main app shell:
  1. 📰 **Feed**
  2. 🩸 **Blood Hub**
  3. 👥 **Communities**
  4. 🏥 **Health Hub**
  5. 👤 **Profile**

### 3. NOTIFICATION SCREEN TABS (NOTIFICATION EXCEPTION)
- Clicking the Notification Bell opens Notification Center with 4 items:
  1. 📰 **Feed**
  2. 🚨 **Request**
  3. 💬 **Messages**
  4. 👤 **Profile**

### 4. DESIGN TOKENS
- Primary `#C30121`, Secondary `#2B2B2B`, Tertiary `#0D68AA`, Surface `#FDF3F3` / `#FFF8F7`.
- Headlines in Georgia; Body/Inputs/Buttons in Inter.
- Full capsule / pill shape (`BorderRadius.circular(50)`) for buttons and input fields.
- Wrap all screens in `ResponsiveLayout`.

### 5. TARGET SCOPE & INSTITUTION
- Product scope is nationwide Bangladesh (64 districts). Do not reference or hard-code any single institution in product copy, defaults or logic. The Student institution field is a normal data feature.

### 6. SHARED CORE WIDGETS & PATTERNS (USER RULES)
- **S1 (PrimaryButton)**: Label never clips or wraps at 320dp/360dp with textScale 1.3 (Flexible + FittedBox, min height 48). Arrow icon strictly AFTER button text. Press-zoom scale 0.97. Loading shows ONLY white ECG loader on red; other buttons use IgnorePointer without changing appearance.
- **S2 (PressableScale)**: Scale 0.97 over 120ms with Curves.easeOutCubic on press for all tappable cards, tiles, and boxes.
- **S3 (AppError)**: Every API error mapped to one short human sentence. Never show raw JSON, ApiException, status codes, or model field names.
- **S4 (PulseAI FAB Allowlist)**: Floating button visible strictly on allowlist: Feed, Blood Hub, Communities, Health Hub, Profile main tabs. Hidden everywhere else (chat, OTP, auth, registration, poster, emergency request, splash).
- **S5 (PulseMotion)**: Standard durations (fast 120ms, normal 300ms, slow 600ms) and curves in `PulseMotion`; honors `MediaQuery.disableAnimations`; custom painters wrapped in `RepaintBoundary`.

### 7. PHASE E BUILT-IN ANIMATION TOKENS
- **E1 (EcgLoader)**: White ECG heartbeat wave on #C30121 red. Spinners and circular progress indicators forbidden in primary buttons.
- **E2 (SuccessPulse)**: Button morphs, draws continuous ECG line, resolves to checkmark (duration <= 900ms, non-blocking).
- **E3 (HeroRevealLogo)**: Single-run ECG lead line drawing into BloodPulse logo on Login screen (duration <= 1.2s).
- **E4 (CountUpText)**: Smooth 600ms numerical counter for profile donation counts, rank, and hydration tracker.
- **E5 (ProcessDrawLine)**: Horizontal and vertical active timeline connectors drawing as journey status advances.
- **E6 (BentoStagger)**: 40ms stagger offset, 300ms fade-and-slide duration for Health Hub tools grid.
- **E7 (PingRipple)**: Double-wave radial ECG ripple behind live donation alert banners (2 repeats, 600ms).

### 8. BECOME A GUIDE (PHASE F)
- Available strictly to complete, verified donor profiles. Gated accounts view a prompt to complete profile.
- 4 Button States via S1 PrimaryButton: Apply Now / Pending review / Approved (Manage) / Rejected (Apply again on <date>).
- Rejection locks re-application for 14 days from review date.
