# Blood Pulse — Anomaly & Defect Tracker

This document tracks all 40 baseline anomalies and issues across the Blood Pulse mobile and backend systems. Every issue is cataloged for strict phase traceability and evidence-backed resolution.

| ID | Description | Phase | Status | Evidence |
|---|---|---|---|---|
| 1 | Forgot-password OTP send -> 500 | Phase 1 | OPEN | |
| 2 | Login by phone -> 401 "No active account" (login phone 01601239009 vs profile phone 01601239023: confirm same account) | Phase 1 | OPEN | |
| 3 | Guest map offline/0 donors | Phase 1 | DONE | Extended timeout from 6s to 55s for Render free-tier cold start; added auto-retry countdown banner with manual Retry connection button; removed 6 fake mock pins fallback (zero fake data policy); added blurred circular cluster overlays for coarse geohash precision-4 cells; verified via guest_map_cold_start_test.dart |
| 4 | Profile tab ECG indicator line awkward | Phase 1 | DONE | Redesigned HeartbeatTabIndicator with clamped spike height (2.0 to 6.5) and wave geometry to prevent vertical text overlap; wrapped TabBar in rounded container strip (#FFF8F7, radius 16, border #F3E5E5); verified via profile_ecg_and_button_fit_test.dart |
| 5 | Buttons clipped/hidden (Request Blood Group Change, Download Verified Certificate) | Phase 1 | DONE | Replaced fixed 38px/56px heights with ConstrainedBox minHeight 44/52 and full-width constraints; wrapped title and badge in Wrap/Expanded with text ellipsis to prevent 154px/104px overflow under 360dp width and textScale 1.3; verified via profile_ecg_and_button_fit_test.dart |
| 6 | Pause Emergency Alerts broken; move below Impact; bigger button; days/months snooze | Phase 1 | DONE | Added emergency_alerts_paused_until field (migration 0057) synced with alert_pause_until; updated donor_snooze_view to support 1d, 3d, 7d, 30d, 90d snooze durations and return both fields; updated eligibility wave queries; moved snooze card below Impact stats in user_profile_screen.dart with prominent 'Resume Alerts Now' button and scrollable duration picker sheet; verified via emergency_alerts_snooze_test.dart |
| 7 | No donation => no rank/no Active Donor/Lvl; remove fake Verified/5.0/BP-D000000 | Phase 1 | DONE | Added get_donor_title hierarchy (0=None, 1=Newcomer, 2-4=Regular, 5-9=Lifesaver, 10+=Hero); for 0 donations: suppress rank or show 'New Member', rating displays '--' with 'No reviews yet' and 5 unfilled drops, XP displays '0 XP' with empty bar and 'Unranked • New Member', donor ID in Activity tab displays 'Not yet issued'; verified via profile_zero_donation_clean_test.dart |
| 8 | Your Stories load error | Phase 1 | DONE | Updated ProfileStoriesView to return author_name, author_photo, location, image_url, likes_count, and reactions_count; added structured error-with-retry state and clean empty state in ProfileTabsSection with retry callback to refetch stories; verified via profile_stories_tab_test.dart |
| 9 | Accessories empty: demo data (Tier 1-4, price, link) admin-editable | Phase 1 | OPEN | |
| 10 | Communities detail empty | Phase 1 | OPEN | |
| 11 | Connect with Organization cut off and no real action | Phase 1 | OPEN | |
| 12 | Donor list: small cards, 2 per row, tap -> popup | Phase 1 | OPEN | |
| 13 | Replace Platinum badge with "position" (meaning TBD) | Phase 1 | DONE | Added additive occupation field to DonorProfile (migration 0058); exposed position_display and occupation across serializers; ProfileHeroCard renders position_display/occupation and donorTitle chips under user name instead of hardcoded Platinum badge; verified via profile_zero_donation_clean_test.dart |
| 14 | Blood Campaigns card: remove list (scope TBD) | Phase 1 | OPEN | |
| 15 | PulseAI: remove location icon | Phase 3 | OPEN | |
| 16 | PulseAI speech-to-text (error_speech_timeout) | Phase 3 | OPEN | |
| 17 | blood report summary | Phase 3 | OPEN | |
| 18 | slow heartbeat bg animation | Phase 1 | OPEN | |
| 19 | eligibility from profile data | Phase 1 | OPEN | |
| 20 | Bangla/Banglish/English | Phase 3 | OPEN | |
| 21 | Bangla voice | Phase 3 | OPEN | |
| 22 | distance + vehicle fare dataset | Phase 4 | OPEN | |
| 23 | decorated input bar | Phase 1 | OPEN | |
| 24 | phone back button | Phase 1 | OPEN | |
| 25 | persistent login | Phase 1 | OPEN | |
| 26 | OTP not sent | Phase 1 | OPEN | |
| 27 | two-device test | Phase 1 | OPEN | |
| 28 | free open-source map API | Phase 1 | OPEN | |
| 29 | notification/tracking/standby untested | Phase 4 | OPEN | |
| 30 | National Emergency page missing | Phase 4 | OPEN | |
| 31 | tracking/standby real-world logic + backend + DB | Phase 4 | OPEN | |
| 32 | scalability (Redis) | Phase 4 | OPEN | |
| 33 | security checklist (19 points) | Batch 2 | RESOLVED | Hardened settings, CSP/headers middleware, media upload whitelist, admin path/throttle, PII logs masked, DRF rate throttles, auth tests |
| 34 | PulseAI jailbreak | Phase 3 | OPEN | |
| 35 | session mgmt/device tracking/revocation | Batch 2 | RESOLVED | UserDevice model (migration 0056), JWT token blacklist, device list/revoke/logout-all APIs, Flutter Devices & Sessions screen |
| 36 | FCM never verified | Phase 1 | OPEN | |
| 37 | realtime chat | Phase 4 | OPEN | |
| 38 | location-based feed (scope TBD) | Phase 4 | OPEN | |
| 39 | voice message/call (type TBD) | Phase 4 | OPEN | |
| 40 | web app, PWA, admin panel, live link | Phase 4 | OPEN | |

---

## Decisions and Open Questions

1. **Anomaly #2 (Account identity confirmation)**: Does `01601239009` belong to the same user record as `01601239023`, or are these two distinct accounts in the auth/profile tables? Need database verification without exposing PII.
2. **Anomaly #13 (Meaning of "position")**: Resolved via `ANOMALIES_AUDIT_AND_MASTER_PLAN.md` Item 25. "Position" refers to the user's professional designation/occupation (e.g. "Software Engineer", "Doctor", "Student") to be displayed alongside donor name in profile header, feed posts, and certificates, replacing the hardcoded "Platinum" tier badge.
3. **Anomaly #14 (Blood Campaigns card scope)**: Should the campaign list card be removed entirely or converted to a static CTA/banner linking to an upcoming event schedule?
4. **Anomaly #38 (Location-based feed scope)**: What are the geographic radius boundaries for feed posts (division vs. district vs. nationwide), and should guests see national-only feeds?
5. **Anomaly #39 (Voice message / call)**: Is the intended feature direct PSTN calling (`url_launcher` with `tel:`) or in-app recorded voice clips via object storage?
