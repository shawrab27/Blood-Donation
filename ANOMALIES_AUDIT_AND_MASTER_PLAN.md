# BloodPulse Comprehensive Anomalies & Architecture Specification

Generated on: 2026-10-12
Roles: Senior Lead QA, Full-Stack Engineer, DevOps / Cloud Architect

---

## Part 0: User-Defined 30-Problem Matrix & Resolution Directives (বাংলা বিশ্লেষণ)

| # | সমস্যা | সম্ভাব্য কারণ | সমাধান |
|---|---|---|---|
| **1, 8, 9** | Google login, donor list, map, PulseAI সব জায়গায় 404 HTML | App ভুল base URL বা `/api/` path এ request পাঠাচ্ছে। চারটা আলাদা সমস্যা হলে এভাবে একসাথে ভাঙত না | একটাই `ApiConfig`, কখনো raw HTML না দেখানো, backend সবসময় JSON error দেবে |
| **2** | OTP email / SMS | Brevo free প্ল্যানে “Sent with Brevo” লোগো থাকে, সরানো যায় না। সরাতে ~$9-12/মাস | Firebase Phone Auth (10k free SMS/mo, 0 watermark) অথবা Gmail App Password SMTP (বিনামূল্যে) |
| **3, 4** | Feed ছবি আপলোড, location feed | Render free-এর disk ক্ষণস্থায়ী, তাই সার্ভারে ছবি রাখা যাবে না। feed-এ district index নেই | Cloudinary free, ছবি compress করে শুধু URL DB-তে, district-ভিত্তিক keyset pagination |
| **5, 6, 7** | Logo বদলে গেছে, splash video চলছে না, PulseAI আইকন ঝামেলা করছে | Asset বদলেছে, video path বা codec ঠিক নেই, পুরো বাটন নড়ছে | Original logo ফিরিয়ে lock করা, video fallback, শুধু heartbeat লাইন নড়বে (বাটন স্থির থাকবে) |
| **9, 10, 11** | PulseAI উত্তর দেয় না, মেনু bottom sheet, background static | API বা key সমস্যা, retry-তে duplicate message | Fallback উত্তর, speed-dial pill মেনু, চলমান dynamic ECG heartbeat background |
| **12, 13, 17, 20** | Spinner, overflow, বাটন কাটা, UI বড় | Fixed width, SafeArea নেই, FAB ঢেকে দিচ্ছে | Heartbeat loader, `ResponsiveRow`, `StickyBottomBar`, overflow sweep test |
| **15, 16, 18, 19** | Poster template, save, size, image change | Template শুধু UI, save ফল্স সাকসেস দেখায়, ratio logic নেই | সত্যিকারের ৪টা template, `gal` দিয়ে save ও গ্যালারি যাচাই |
| **21, 22** | Become Local Donor, Register Club | Route বা screen নেই | Stitch design অনুযায়ী পেজ + admin approval workflow |
| **23, 24-28** | Sidebar, settings, delete, 43d, rank, certificate | পেজ নেই, `last_donation` default ভুল, fake leaderboard | `AppShell`, real delete account CRUD, real rank logic, code-generated ornate digital certificate |
| **29, 30** | Health Hub overflow, accessories জায়গা ভুল | Row-তে fixed width | Accessories শুধু ২য় ট্যাবে থাকবে, admin CRUD |
| **14** | PWA & Web App continuity | Logic ও platform code মিশে আছে | Interface দিয়ে আলাদা করা, web readiness audit |

---

## Part 1: Comprehensive Anomaly Audit & Root Cause Analysis

### Group 1: Authentication, Backend Connectivity & APIs
1. **Google Sign-In 404 Failure (`ApiGoogle login failed [404]`)**
   - **Root Cause**: Mobile client hits a missing or misconfigured endpoint (`/auth/google` returning `404 Not Found` HTML page instead of API JSON). Client OAuth tokens are not handled or the reverse proxy route is unmapped.
   - **Fix**: Wire real Firebase Auth Google credential exchange or configure backend `/api/v1/auth/google` with Google ID token verification.

2. **Backend 404 API Crashes on Multiple Screens (`ApiDonor`, `ApiLiveMap`, etc.)**
   - **Root Cause**: Frontend hardcodes mismatched API URL paths or backend Express/Nest router does not have endpoints registered for `/donors`, `/donors/map`, `/blood-clubs`, `/emergency-requests`.
   - **Fix**: Centralize API base routes, implement unified mock/offline fallback, and stand up explicit CRUD controllers for all models.

3. **OTP & SMS Provider Uncertainty (Bravo / Brevo vs. Firebase OTP vs. Local)**
   - **Root Cause**: Brevo (formerly Sendinblue) is transactional email/SMS with branding and paid SMS tiers. Firebase Phone Auth has 10k free SMS/month on Spark/Blaze plan.
   - **Fix**: Adopt Firebase Phone Authentication (100% free tier up to 10k/mo, zero watermarks) for OTP verification.

---

### Group 2: Feed, Geo-Routing & Multi-User Testing
4. **Photo Upload Not Working in Feed**
   - **Root Cause**: `ImagePicker` path not integrated with multipart upload or local storage cache. Post creation ignores image file attachment.
   - **Fix**: Implement client image picker with compression (`flutter_image_compress`), upload to Cloudinary (free 25GB) or Firebase Storage / Supabase Storage free tier, attach public URL to feed payload.

5. **Location-Based Feed Caching & Dynamic Sorting (Dhaka -> Rangpur relocation)**
   - **Root Cause**: Feed query lacks geo-coordinates or district partitioning.
   - **Fix**: Store district (`district_id`/`district_name`) and lat/long coordinates on posts. On user location change or profile district change, query posts matching current user district first, followed by national posts.

6. **Free Cloud Asset Storage for Production & Testing (5–7 Real Users Testing)**
   - **Root Cause**: No remote asset CDN or image bucket configured.
   - **Fix**: Setup Cloudinary free tier or Supabase/Firebase Storage. Provide internal test APK / Web build via Firebase App Distribution or GitHub Releases for 5-7 test devices.

---

### Group 3: Branding, Floating AI & Motion Design
7. **BloodPulse Logo Accidental Mutation**
   - **Root Cause**: Asset path overridden or replaced with wrong icon variant.
   - **Fix**: Lock asset to `assets/images/Blood Pulse logo.jpg` in circular clip with 32px height across all headers.

8. **Splash Screen Video Not Playing**
   - **Root Cause**: `video_player` controller not properly initialized in splash screen lifecycle or missing asset bundle declaration in `pubspec.yaml`.
   - **Fix**: Add splash video asset, preload controller, fallback gracefully to animated heartbeat vector if codec or hardware fails.

9. **PulseAI Floating Action Button (FAB) Motion & Heartbeat Asset**
   - **Root Cause**: Generic bouncing or annoying displacement animation instead of an accurate, static/subtle heartbeat pulse in place.
   - **Fix**: Convert official Heartbeat SVG/Path into a custom Flutter `CustomPainter` / Rive animation with subtle ECG rhythm pulsing in-place without moving screen position.

10. **PulseAI Speed Dial Menu UI (Current Bottom Sheet vs. Floating Pills)**
    - **Root Cause**: Clicking FAB currently opens a modal bottom sheet. User requires a floating vertical stack of pill buttons expanding upward from the FAB (Speed Dial style: "Chat with PulseAI", "Analyse blood report", "Find donors nearby", "Hide PulseAI").
    - **Fix**: Replace bottom sheet with animated staggered vertical floating pill cards aligned right above the FAB.

11. **PulseAI Chatbot Timeout & Unresponsiveness ("PulseAI is busy")**
    - **Root Cause**: Chatbot client hitting dead local endpoint or failing API key for Gemini.
    - **Fix**: Connect Gemini 1.5/2.0 Flash directly via official Google GenAI SDK or lightweight Cloud Function proxy with streaming and medical triage prompt.

12. **Background Heartbeat Canvas inside PulseAI Chat**
    - **Root Cause**: Heartbeat watermarked background missing or clipped out.
    - **Fix**: Render low-opacity SVG/CustomPainter ECG wave in background stack of chat view.

13. **Universal Loading Indicator Replacement**
    - **Root Cause**: Standard circular progress indicators (`CircularProgressIndicator`) used everywhere.
    - **Fix**: Build reusable `BloodPulseHeartbeatLoader` widget rendering smooth ECG/heartbeat animation for all screen and button loading states.

---

### Group 4: Poster Studio, Emergency Flow & Responsiveness
14. **Bottom Button Inaccessibility & Cut-off across Devices**
    - **Root Cause**: Hardcoded heights or lack of `SafeArea` + `SingleChildScrollView` causing bottom buttons to get pushed off-screen or hidden behind navigation bar.
    - **Fix**: Wrap views in `ResponsiveLayout`, set persistent bottom action bars in `bottomNavigationBar` scaffold slot or scrollable padding with dynamic view insets.

15. **Poster Studio Templates Broken**
    - **Root Cause**: Preset templates (1:1, 4:5, 9:16) do not trigger canvas re-render or layout recalculation.
    - **Fix**: Wire AspectRatio canvas containers that update width/height and re-bind typography based on selected ratio and theme.

16. **Poster Gallery Save Fails (Toast shows "Saved" but not in gallery)**
    - **Root Cause**: Using internal app sandbox path (`getTemporaryDirectory`) without exporting to public MediaStore via `image_gallery_saver` or `gal` with write permissions.
    - **Fix**: Use `RenderRepaintBoundary` to capture PNG bytes, write to external gallery using `gal` package with Android 13+ granular media permissions.

17. **Poster Image Replacement Button Unresponsive**
    - **Root Cause**: Tap handler unattached or state not updated with picked image.
    - **Fix**: Wire `image_picker` to state, preview selected image on canvas immediately.

18. **Poster Studio Button & Form Oversizing**
    - **Root Cause**: Non-compact button padding and oversized pill inputs filling excessive vertical space.
    - **Fix**: Streamline form into compact tabs/chips with 44px pill heights and responsive grid.

19. **Local Blood Clubs & "Become a Local Donor" Dead Navigation**
    - **Root Cause**: Missing route bindings for club registration modal and donor registration flow.
    - **Fix**: Hook route transitions to Donor Registration modal and Blood Club submission form.

---

### Group 5: Profile, Top Bar, Drawer & Certificate
20. **Top-Right Profile Tap Behavior: Missing Animated Profile Slide Drawer**
    - **Root Cause**: Clicking profile avatar navigates directly to a basic profile page or popup menu rather than opening the specified Profile Slidebar/Drawer.
    - **Fix**: Wire Top-Right Avatar to open animated side drawer / custom sliding panel containing user details, theme switcher, settings, donation guide, PulseAI toggle, and Logout.

21. **Missing Account Operations (Settings, Logout, Delete Account with Confirmation)**
    - **Root Cause**: Settings and security screens unlinked. CRUD operations for account deletion not implemented.
    - **Fix**: Implement dedicated Settings screen, confirmation popups for Logout and Delete Account with database purge / soft-delete API.

22. **Donation Calculation Bug: "Never Donated" shows "Next Donation: 43d"**
    - **Root Cause**: Calculation default falls back to a non-zero interval or dummy date when `last_donation_date` is null.
    - **Fix**: Strict logic: If `total_donations == 0` or `last_donation_date == null`, display "Eligible Now" / 0d countdown, enable instant donor eligibility badge.

23. **Profile Picture Upload Sheet Position & Options**
    - **Root Cause**: Sheet opens at bottom instead of a clean modal dialog with Camera, Gallery, and File options.
    - **Fix**: Create clean modal offering Camera, Gallery, and File pickers.

24. **Dynamic Global Rank Calculation**
    - **Root Cause**: Hardcoded static rank ("Global Rank #3") shown for all users.
    - **Fix**: Calculate rank based on total verified donation points and bag count relative to active donors in district/country.

25. **User Role/Position Tagging (e.g., "Software Engineer")**
    - **Root Cause**: Profession/Designation field missing from user model and header badges.
    - **Fix**: Add `designation` / `position` to User profile, display alongside user name in posts, profile header, and certificates.

26. **Digital Certificate Engine & Generation**
    - **Root Cause**: Certificate button triggers dummy action without PDF or image compilation.
    - **Fix**: Implement vector certificate canvas matching user sample with ornate border, dynamic donor name, blood group, bags, role, verification signature, and one-click PDF/PNG download.

---

### Group 6: Responsive Layout & RenderFlex Overflows
27. **Right Overflow Yellow-Black Stripe Errors Across Health Hub & Trackers**
    - **Root Cause**: Hardcoded row element widths without `Expanded`, `Flexible`, or `Wrap` in Hydration Tracker and Biological Recovery cards (`overflowed by 21 pixels`, `42 pixels`).
    - **Fix**: Refactor all health tracker cards to use `Expanded` text labels and auto-wrapping responsive layouts.

28. **PWA & Cross-Platform Web Architecture Continuity**
    - **Root Cause**: Flutter codebase lacks responsive constraints and web-safe abstractions for seamless PWA deployment.
    - **Fix**: Ensure zero native-only bottlenecks, provide clean responsive breakpoints (`ResponsiveLayout`), and ensure web compilation with PWA manifest and service worker.

29. **Health Hub Accessories Duplicate Banner Placement**
    - **Root Cause**: Accessories promotional banner is hardcoded at top of every single sub-tab in Health Hub.
    - **Fix**: Restrict Accessories display strictly to Tab 2 ("Accessories") of Health Hub.

30. **Dynamic Accessories Admin CRUD System**
    - **Root Cause**: Static mock list of medical accessories.
    - **Fix**: Create Firestore/Postgres backed accessories collection with admin dashboard to add/edit/delete product cards, prices, and affiliate/store links.

---

## Part 2: Architectural Master Plan & Execution Plan

### 1. Database Schema Specifications
- **Users**: `id`, `name`, `phone`, `email`, `blood_group`, `district`, `last_donation_date`, `total_donations`, `designation`, `role`, `avatar_url`, `created_at`
- **Posts**: `id`, `user_id`, `content`, `image_url`, `district`, `post_type` (feed, emergency, campaign), `created_at`
- **Accessories**: `id`, `title`, `price_bdt`, `image_url`, `affiliate_url`, `tier`, `rating`, `in_stock`, `category`
- **Certificates**: `id`, `user_id`, `issue_date`, `bags_count`, `serial_number`, `pdf_url`

### 2. Free Stack Recommendations
- **Authentication & OTP**: Firebase Phone Auth (10,000 free SMS/month, 0 branding watermarks).
- **Database & Realtime**: Firebase Firestore or Supabase PostgreSQL (free 500MB DB, realtime listeners).
- **Media Storage**: Cloudinary (25GB free CDN bandwidth) or Supabase Storage (1GB free).
- **AI Engine**: Gemini 2.0 Flash via Google GenAI SDK (generous free tier, fast streaming).
- **Hosting & PWA**: Firebase Hosting / Cloudflare Pages (100% free with automated SSL).
