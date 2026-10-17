# BloodPulse Two-Device End-to-End QA Checklist (#27)

This document provides a comprehensive, field-ready QA guide to manually verify the complete real-time lifecycle between two live endpoints:
- **Device A (Requester / Attendant)**: Physical Android device or primary emulator.
- **Device B (Donor)**: Android Emulator (Google Play System Image) or secondary phone with mock GPS.
- **Device C (Standby Candidate)**: Optional secondary profile to verify auto-standby promotion.

---

## 1. Hardware & Environment Setup

### A. Network & Backend
- [ ] Backend running on accessible local network:
  ```powershell
  python manage.py runserver 0.0.0.0:8000
  ```
- [ ] Determine host machine IP on local Wi-Fi (e.g., `192.168.1.100` via `ipconfig`).
- [ ] Ensure Flutter app connects to host IP:
  - For physical device: `http://192.168.1.100:8000/api`
  - For Android emulator: `http://10.0.2.2:8000/api`

### B. Device Configuration
- [ ] **Device A (Physical Phone)**:
  - Android 10+ with Wi-Fi connected to same LAN.
  - USB Debugging enabled if inspecting with `flutter logs` or Chrome DevTools.
  - Notifications enabled (`POST_NOTIFICATIONS` granted).
- [ ] **Device B (Android Emulator)**:
  - AVD created with **Google Play** system image (API 33 or 34).
  - GPS Extended Controls accessible (or ADB Telnet port active).
  - Notifications and Location permissions granted.

---

## 2. GPS Simulation Setup on Device B (Emulator)

To simulate donor movement from Banani/Gulshan to NICVD Hospital (Dhaka):

### Method 1: Android Studio Extended Controls
1. Open Emulator window -> Click `...` (Extended Controls).
2. Navigate to **Location** tab.
3. Waypoint 1 (Donor Origin): `23.7937, 90.4066` (Banani).
4. Waypoint 2 (Midway transit): `23.7750, 90.3850` (Farmgate / Bijoy Sarani).
5. Waypoint 3 (Destination): `23.7700, 90.3700` (NICVD, Sher-e-Bangla Nagar).

### Method 2: ADB Command Line
```bash
# Waypoint 1: Donor Start Location
adb -s emulator-5554 emu geo fix 90.4066 23.7937

# Waypoint 2: Moving along route
adb -s emulator-5554 emu geo fix 90.3850 23.7750

# Waypoint 3: Arrived at Hospital
adb -s emulator-5554 emu geo fix 90.3700 23.7700
```
*(Note: ADB geo fix takes `<longitude> <latitude>` format).*

---

## 3. End-to-End QA Test Matrix

### Phase 1: Accounts & Pre-flight
- [ ] **Device A**: Log in as Requester (`requester_qa` / `+8801711111111`).
- [ ] **Device B**: Log in as Donor (`donor_kamal` / `+8801822222222`, Blood Group `O+`, Dhaka, Available: Yes).
- [ ] Verify both devices have valid FCM tokens registered in backend (`UserDevice` table).

---

### Phase 2: Urgent Requisition & Wave Notification
1. **Device A**:
   - [ ] Navigate to **Blood Hub** -> Tap **Request Blood**.
   - [ ] Fill details:
     - Patient Name: `Emergency Cardiac Patient`
     - Blood Group: `O+`
     - Hospital: `National Institute of Cardiovascular Diseases (NICVD)`
     - Urgency: `Emergency` (Within 2 Hours)
     - Units: `1 Bag`
   - [ ] Submit requisition.
   - [ ] Confirm request status is `ACTIVE` / `URGENT`.
2. **Device B**:
   - [ ] Verify instant push notification arrives on channel `bloodpulse_urgent_alerts`.
   - [ ] Verify notification text: *"Urgent: O+ Blood Needed at NICVD"*.
   - [ ] Verify unread badge count increments on Notification Center icon.
   - [ ] Tap notification -> Verify app navigates directly to Request Details screen.

---

### Phase 3: Acceptance & Real-time Handshake
1. **Device B (Donor)**:
   - [ ] Tap **"I Can Donate"** / **Accept Requisition**.
   - [ ] Confirm prompt.
   - [ ] Screen transitions to **Live Journey Tracking Screen**.
2. **Device A (Requester)**:
   - [ ] Verify Request Status updates from `OPEN` to `MATCHED` / `ACCEPTED`.
   - [ ] Verify Donor Name and phone call button appear (PII masked for outsiders).
   - [ ] Tap **Track Donor** button to enter tracking screen.

---

### Phase 4: Live GPS Tracking & ETA Updates
1. **Device B**:
   - [ ] Tap **"I'm On The Way"**.
   - [ ] Inject Waypoint 1 (`23.7937, 90.4066`).
2. **Device A**:
   - [ ] Verify live donor marker appears on OpenStreetMap canvas.
   - [ ] Verify destination marker appears at NICVD hospital.
   - [ ] Verify distance reads ~5-6 km, and ETA displays ~20-25 mins.
3. **Device B**:
   - [ ] Inject Waypoint 2 (`23.7750, 90.3850`).
4. **Device A**:
   - [ ] Within 5-10 seconds, verify marker animates smoothly towards destination.
   - [ ] Verify distance decreases and ETA drops accordingly.
5. **Security Check**:
   - [ ] In Postman / cURL, attempt to query `/api/journeys/<id>/location/` with an unauthorized user token.
   - [ ] Verify response is strictly `403 Forbidden`.

---

### Phase 5: In-App Chat & Voice Messaging
1. **Device A**:
   - [ ] Tap **Chat** icon on the journey screen.
   - [ ] Send text message: *"Please come to 3rd floor ICU entrance"*.
2. **Device B**:
   - [ ] Verify message appears within polling interval (<= 2 seconds active).
   - [ ] Verify read receipt tick updates on Device A once Device B opens chat.
3. **Device B**:
   - [ ] Press and hold microphone button to record a voice note (5-10 seconds).
   - [ ] Release or tap send.
   - [ ] Verify voice message bubble renders with audio waveform / progress bar.
4. **Device A**:
   - [ ] Verify voice note appears with play/pause button and duration badge.
   - [ ] Tap **Play** -> Verify audio plays clearly without crash or stutter.

---

### Phase 6: Arrival & Two-Sided Completion
1. **Device B**:
   - [ ] Inject Waypoint 3 (`23.7700, 90.3700`).
   - [ ] Tap **"I Have Arrived"** -> Status updates to `ARRIVED`.
   - [ ] After donation procedure, tap **"Donation Completed"** (`DONATED`).
2. **Device A**:
   - [ ] Status updates to `DONATED`.
   - [ ] Requester taps **"Confirm Blood Received"**.
3. **Two-Sided Confirmation**:
   - [ ] Verify backend `DonationMatch.confirmed_at` is populated.
   - [ ] Verify Request status moves to `FULFILLED`.
   - [ ] Verify Donor's donation counter increments and 90-day cooldown commences.

---

### Phase 7: Private Feedback & Rating Protection
1. **Device B (Donor)**:
   - [ ] Feedback prompt appears: *"Rate your experience with the requester"*.
   - [ ] Select `5 Stars` + Tags `POLITE`, `GAVE_FOOD`.
   - [ ] Submit feedback.
2. **Device A (Requester)**:
   - [ ] Verify requester has no UI button or API endpoint to read the donor's rating (PII & harassment shield).
   - [ ] Verify attempt to GET `/api/requests/<id>/feedback/` yields `403 Forbidden`.

---

### Phase 8: Standby Fallback Scenario (Edge Case)
1. **Device A**: Create a new urgent blood request.
2. **Device B (Primary Donor)**: Accept requisition.
3. **Device B**: Encounter cancellation (e.g., tap *"Unable to Donate"* -> select *"Vehicle Breakdown"*).
4. **Device C (Standby Donor)**:
   - [ ] Verify Standby offer notification arrives within 5 seconds.
   - [ ] Tap notification -> Tap **"Accept Standby Offer"**.
   - [ ] Verify Device C seamlessly replaces Device B as the active journey donor.
5. **Device A**:
   - [ ] Receives push notification: *"Standby donor connected"*.
   - [ ] Tracking screen automatically updates to show Device C's live location.

---

## 4. Acceptance Criteria Checklist

| Test Item | Expected Result | Pass / Fail |
|---|---|---|
| Requisition Dispatch | Wave engine reaches compatible donor in < 3s | [ ] PASS |
| Push Notification | High-priority heads-up banner with custom sound | [ ] PASS |
| Location Throttling | Client pings throttled to max 1 per 10s | [ ] PASS |
| Route Privacy | Location tracking inaccessible to third parties | [ ] PASS |
| Voice Note Recording | Capped at 60s, max 5MB, plays smoothly | [ ] PASS |
| Two-Sided Handshake | Both sides must confirm before badges/cooldown update | [ ] PASS |
| Standby Promotion | Auto-activates backup candidate upon cancellation | [ ] PASS |
| Private Feedback | Donor ratings strictly shielded from requester | [ ] PASS |
