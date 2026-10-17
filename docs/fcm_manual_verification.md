# BloodPulse FCM Manual Real-Device Verification Checklist (#36)

This document provides the step-by-step manual test checklist for verifying end-to-end push notifications on physical devices (Android 13+ and iOS).

---

## 1. Environment & Credentials Pre-Flight
- [ ] Backend environment has `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_PATH` set (read from environment, never committed or printed).
- [ ] Backend is running on a reachable network host (e.g., local LAN or staging server).
- [ ] Physical device has Google Play Services active and is connected to the internet.

---

## 2. Notification Permissions (Android 13+ & iOS)
- [ ] Launch BloodPulse app on physical device.
- [ ] On first launch / login, verify the runtime notification permission dialog appears (`POST_NOTIFICATIONS` on Android 13+).
- [ ] Tap **Allow**. Verify permission status is recorded as granted.

---

## 3. Device Token Registration & Refresh
- [ ] In app logs / DevTools console, confirm:
  ```
  🔥 [BLOODPULSE FCM DEVICE TOKEN]
  🔑 Token: <fcm_token>
  ```
- [ ] Verify HTTP `POST /api/users/update-fcm/` returned `200 OK` with `device_id`.
- [ ] Check backend Django DB: `UserDevice` has `fcm_token` set, `platform='android'`, and `fcm_updated_at` populated.
- [ ] If user is a donor, verify `DonorProfile.fcm_token` is synced.

---

## 4. Test Push Command Verification
1. **Dry-Run (Default)**:
   ```bash
   python manage.py send_test_push --user <donor_username_or_phone>
   ```
   - [ ] Verify output starts with `[DRY RUN]`.
   - [ ] Verify the token is masked (e.g. `eXampl...8877`) and never leaked in full.
   - [ ] Verify no message was dispatched to Firebase.

2. **Real Push Dispatch**:
   ```bash
   python manage.py send_test_push --user <donor_username_or_phone> --confirm
   ```
   - [ ] Verify output shows `[EXECUTED] send_test_push Dispatched` with `Sent successfully: 1`.

---

## 5. Lifecycle Delivery States

### A. Foreground State
- [ ] Keep BloodPulse app open on the home feed or profile.
- [ ] Trigger an emergency request or send a test push.
- [ ] Verify a high-priority heads-up notification banner appears at the top of the screen on notification channel `bloodpulse_urgent_alerts`.
- [ ] Verify sound and vibration play.

### B. Background State
- [ ] Press Home to send BloodPulse to the background.
- [ ] Send test push via `send_test_push --confirm`.
- [ ] Verify notification appears in the Android system tray with BloodPulse logo and red accent.
- [ ] Tap notification: verify app resumes and opens the relevant target (Blood Hub or Chat).

### C. Terminated State (Deep Link)
- [ ] Swipe BloodPulse away from Android Recent Apps / App Switcher.
- [ ] Send an emergency wave notification or chat message push.
- [ ] Verify notification arrives in the system tray.
- [ ] Tap notification: verify app cold-boots and deep links directly to `/blood-hub` (for emergency) or `/chat` (for direct message).

---

## 6. Invalid Token Auto-Cleanup
- [ ] Clear app data or uninstall app on device.
- [ ] Run `python manage.py send_test_push --user <user> --confirm`.
- [ ] Observe FCM response returning `UNREGISTERED` or `NOT_FOUND`.
- [ ] Verify backend automatically nullifies `fcm_token` on `UserDevice` and `DonorProfile` without crashing the dispatch loop.
