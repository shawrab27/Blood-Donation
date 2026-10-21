---
name: bloodpulse-project
description: Core architecture rules, mandatory UI patterns, design tokens, and nationwide Bangladesh scope for the BloodPulse project. Use when designing, building, modifying, or reviewing any frontend Flutter screen or backend Django service in BloodPulse.
metadata:
  version: "1.0.0"
---

# BloodPulse Project Rules & Architecture Decisions

Mandatory rules and patterns for the BloodPulse project across the Flutter frontend (`blood_pulse/`) and Django REST backend (`blood_pulse_backend/`).

## When to Activate

- Designing or modifying any Flutter screen or component.
- Reviewing UI layouts against Stitch design translations.
- Working on Django APIs, models, serializers, or authentication.
- Implementing nationwide donor features and location filters.

---

## 1. Top Header Pattern (Top Bar Rule)

Every top app bar in the main Flutter shell must strictly adhere to this layout:

- **Top-Left**:
  - Logo asset: `assets/images/launcher_icon_transparent.png` (height: `32px`).
  - Title text: `"BloodPulse"` in Georgia font, deep brand red (`#C30121`).
- **Top-Right**:
  1. **Notification Bell**: `Icons.notifications_outlined` with an active red unread badge (`#C30121`). Tapping opens Notification Center.
  2. **Profile Avatar**: A circular `CircleAvatar` (diameter `36px`, border: `2px solid #C30121`) displaying the user's profile image, first-letter fallback, or guest icon (`Icons.person_rounded`). Tapping navigates to `/profile`.
  - **CRITICAL RESTRICTION**: Never use a 3-dot popup menu (`PopupMenuButton`) in the top app bar.

---

## 2. Down Navigation Bar Pattern (5 Persistent Tabs)

The main persistent bottom navigation bar across the application shell must contain exactly these 5 tabs in this exact order:

1. 📰 **Feed**: Blood donation posts, donor stories, news.
2. 🩸 **Blood Hub**: Blood search, urgent request creation, donation matches.
3. 👥 **Communities**: Donor clubs, volunteering circles, organizational activities.
4. 🏥 **Health Hub**: Health tracking, blood compatibility, medical guides, hospital info.
5. 👤 **Profile**: Donor profile, donation history, achievements, settings.

---

## 3. Notification Screen Pattern (Notification Center Exception)

When the user taps the Notification Bell, the Notification Center opens with exactly 4 categorized tabs:

1. 📰 **Feed**: Updates from followed donors, posts, and clubs.
2. 🚨 **Request**: Urgent blood requests, donation requests matched with the user's blood group.
3. 💬 **Messages**: Chat notifications and direct communication.
4. 👤 **Profile**: Account alerts, badges earned, donation milestone notifications.

---

## 4. Design Tokens & Styling Rules

- **Color Palette**:
  - **Primary**: Deep Red `#C30121` (actions, highlights, active tabs, brand icons).
  - **Secondary**: Charcoal `#2B2B2B` (body text, high contrast headers).
  - **Tertiary**: Slate Blue `#0D68AA` (informational accents, badges).
  - **Surface / Background**: Soft Warm Pink `#FDF3F3` / `#FFF8F7`.
- **Typography**:
  - **Headlines & Brand Titles**: Georgia font family (authoritative, medical-editorial).
  - **Body, Inputs & Buttons**: Inter font family (clean, high legibility).
- **Component Geometry**:
  - All actionable buttons and text input fields must use full capsule/pill shape (`BorderRadius.circular(50)`).
- **Responsive Enclosure**:
  - Every screen must be wrapped in `ResponsiveLayout` to guarantee compatibility across varied screen sizes and desktop/mobile form factors.

---

## 5. Target Scope & Nationwide Bangladesh Feature Logic

- **Geographic Scope**: Nationwide Bangladesh (64 districts).
- **Independence from Single Institutions**:
  - Never hardcode or assume any single university, hospital, or college in UI copy, defaults, dropdowns, or backend logic.
  - The "Student Institution" field is a general optional profile attribute, not a platform-defining constraint.
- **District Mapping**: All location dropdowns, donor queries, and hospital relations must accommodate all 64 districts of Bangladesh.

---

## 6. Directory Layout Reference

```
Blood donation/
├── blood_pulse/              # Flutter mobile/web client
│   ├── lib/
│   │   ├── core/            # Theme, constants, ResponsiveLayout, tokens
│   │   ├── features/        # Feature modules (feed, blood_hub, community, health, profile)
│   │   └── main.dart        # App entry point
│   └── test/                # Unit, widget, and integration tests
├── blood_pulse_backend/      # Django REST backend
│   ├── api/                 # DRF ViewSets, serializers, routers
│   ├── blood_pulse_backend/ # Settings, wsgi, asgi, urls
│   └── manage.py
└── .agents/                  # Agent configurations and skills
```
