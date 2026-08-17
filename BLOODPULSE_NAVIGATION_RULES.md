# BLOODPULSE MANDATORY UI & NAVIGATION PATTERN SPECIFICATION

This document outlines the strict UI, Top Header, Bottom Navigation, and Color/Layout rules for the **BloodPulse** platform. **ALL STITCH UI MISTAKES ARE OVERRIDDEN BY THIS DOCUMENT.**

---

## 📌 PATTERN & ELEMENT REGISTRY

### 1. STANDARD TOP HEADER (TOP BAR RULE)
Must be rendered consistently across almost ALL app screens using `BloodPulseAppBar`.

- **Top-Left (Branding)**:
  - **Logo Asset**: `assets/images/Blood Pulse logo.jpg` (Fixed uniform height: 32px, proper aspect ratio, circular clip).
  - **Title**: `"BloodPulse"` (Georgia font, bold, Primary Deep Red `#C30121`).
- **Top-Right (Actions)**:
  - **Notification Bell Icon**: `Icons.notifications_outlined` with active unread red badge (`#C30121`).
  - **3-Dot Vertical Menu Button**: `PopupMenuButton` containing exactly 4 options:
    1. ℹ️ **Learn more** (App overview dialog)
    2. 📞 **Contact us** (Hotlines: 16263 / 999 / Emergency desk)
    3. ❓ **About us** (App version & architecture metadata)
    4. 🚪 **Log out** (Confirmation modal + redirect to `/login`)

---

### 2. STANDARD BOTTOM NAVIGATION (DOWN NAV BAR RULE)
Persistent bottom navigation bar present across the main app shell with EXACTLY these 5 tabs in order:

1. 📰 **Tab 1: Feed** (`Icons.feed_rounded`) — Community feed, story/post creation, reactions, comments, reposts.
2. 🩸 **Tab 2: Blood Hub** (`Icons.water_drop_rounded`) — Emergency blood requests, donor search, JIT verification gate.
3. 👥 **Tab 3: Communities** (`Icons.groups_rounded`) — 3-Segment community discovery (Badhan, Sandhani, Red Crescent, campus units).
4. 🏥 **Tab 4: Health Hub** (`Icons.health_and_safety_rounded`) — 7 Feature segments (AI Report Analysis, Calculators, Science of Blood, Compatibility Matrix, Donation Guide, Resources Hub, Recovery Tracker).
5. 👤 **Tab 5: Profile** (`Icons.person_rounded`) — User profile, donation history, 120-day auto check engine, request logs.

---

### 3. NOTIFICATION SCREEN SPECIFICATION (NOTIFICATION EXCEPTION RULE)
When the user clicks on the **Notification Bell Icon** in the top header:

- Opens the **Notification Center** screen.
- On the Notification Center, navigation filters / tabs MUST display:
  1. 📰 **Feed Notifications** (Post likes, comments, community updates)
  2. 🚨 **Request Alerts** (Matching blood request broadcasts nearby)
  3. 💬 **Messages** (P2P direct donor-requester chat notifications)
  4. 👤 **Profile Alerts** (Eligibility cooldown countdown, badge unlocks)

---

### 4. DESIGN SYSTEM TOKENS & ALIGNMENT
- **Primary Color**: `#C30121` (Deep Blood Red)
- **Secondary Color**: `#2B2B2B` (Dark Slate)
- **Tertiary Color**: `#0D68AA` (Medical Blue)
- **Neutral Color**: `#8E7D7F` (Warm Neutral)
- **Surface**: `#FFF8F7` / `#FDF3F3` (Warm Soft Off-White)
- **Typography**: **Georgia** for Headlines & Titles; **Inter** for Body text, Input labels, & Buttons.
- **Global Shape**: Full Capsule / Pill (`BorderRadius.circular(50)` / `9999px`) for all buttons, chips, and input fields.
- **Card Shape**: `BorderRadius.circular(16)` to `BorderRadius.circular(24)`.
- **Responsive Layout**: All views wrapped in `ResponsiveLayout` with max-width `500.0` on Web/Desktop to preserve mobile edge-to-edge aesthetics without overflow.
