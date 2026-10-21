# BloodPulse Post-Accept Journey: Two-Device Verification Guide

This guide details the step-by-step verification instructions between two physical devices running against the production/live backend (`https://bloodpulse-backend.onrender.com`):
- **Device A (Requester)**: iPhone 13 running Safari PWA installed to Home Screen (or browser).
- **Device B (Donor)**: Android Vivo Y20 running the production release APK (`blood_pulse/build/app/outputs/flutter-apk/app-release.apk`).

---

## 1. Prerequisites & Demo Seeding

To verify all post-accept screens immediately without waiting for hospital emergencies or geo-matches, use the staff management command on the backend environment:

```bash
# Set environment flag to allow demo seeding (safety guard)
export ALLOW_TEST_SEED=true

# Seed a demo journey between existing users (e.g. Requester: 01711111111, Donor: 01822222222)
python manage.py seed_journey_demo --requester 01711111111 --donor 01822222222 --state ACCEPTED
```

Allowed states: `ACCEPTED`, `DONOR_ON_THE_WAY`, `ARRIVED`, `DONATED`, `COMPLETED`, `STANDBY_SEARCHING`.

To remove the demo data once testing is finished:
```bash
python manage.py cleanup_journey_demo --request-id <REQUEST_ID>
```

---

## 2. Test Flow 1: State Machine & Entry Points (Parts 1 & 2)

### Step 1.1: Requester View (iPhone 13 Safari PWA)
1. Log in to `https://bloodpulse-backend.onrender.com` as Requester (`01711111111`).
2. Navigate to **Blood Hub** tab -> Tap **"My Requests"**.
3. Tap the active request.
4. Verify:
   - Status Progress Stepper indicates **"Accepted"** (`ACCEPTED`).
   - Timeline shows creation and donor acceptance events.
   - Accepted Donor Card is displayed showing donor name, blood group, distance/ETA, and status.
   - Action buttons visible: **Open Chat**, **Track Donor**, **Cancel Request**.
   - Donor's phone number is unmasked with direct **Call** (`tel:`) button.

### Step 1.2: Donor View (Android Vivo Y20 Release APK)
1. Launch BloodPulse release APK on Vivo Y20 and log in as Donor (`01822222222`).
2. Navigate to **Blood Hub** tab -> Tap **"My Accepted"**.
3. Tap the accepted request item.
4. Verify:
   - Request info and destination hospital are displayed.
   - Action buttons: **Start Going** (starts GPS tracking), **Open Chat**, **I Can't Donate**, **Mark Arrived**.
   - Requester's phone number is unmasked with direct **Call** (`tel:`) button.

---

## 3. Test Flow 2: Live In-App Chat & Voice Notes (Part 3)

### Step 2.1: Chat Access & Message Exchange
1. Requester taps **Open Chat** on iPhone 13; Donor taps **Open Chat** on Vivo Y20.
2. Requester types `"Please hurry, patient is waiting"` and taps Send.
3. Verify message delivers in real time to Vivo Y20 with single/double checkmark status.
4. Donor taps and holds microphone icon to record a voice note (up to 60s), then releases/sends.
5. Verify voice note bubble renders on iPhone 13 with duration and playable audio.
6. Verify third-party users cannot access the chat endpoint (guarded with 403 Forbidden).

---

## 4. Test Flow 3: Live Donor Tracking on OpenStreetMap (Part 4)

### Step 3.1: Start Tracking
1. On Android Vivo Y20, tap **Start Going**.
2. Verify status transitions to `DONOR_ON_THE_WAY`.
3. Verify foreground persistent banner appears: *"Sharing location with requester"* with a **Stop** button.
4. Location is transmitted securely every 5–10s to `/api/blood-requests/<id>/location/`.

### Step 3.2: Tracking Map on Requester Device
1. On iPhone 13, tap **Track Donor**.
2. Verify OpenStreetMap displays:
   - Donor moving marker pin with pulsing indicator.
   - Destination hospital marker pin.
   - Calculated driving route polyline (or straight-line Haversine if route proxy is offline).
   - Dynamic Distance and ETA banner.
   - When stationary for >60s, label updates to *"Last seen X ago"*.

---

## 5. Test Flow 4: Standby Donor Escalation (Part 5)

### Step 4.1: Cancellation / Handover Trigger
1. On Android Vivo Y20, tap **"I Can't Donate"** and confirm.
2. Verify state immediately updates to `STANDBY_SEARCHING`.
3. Tracking stops immediately and location data is purged.

### Step 4.2: Automated Ladder Dispatch
1. The backend triggers the standby wave escalation engine (5 km -> 25 km -> 100 km -> 1000 km).
2. The next nearest eligible donor receives an in-app urgent notification + push.
3. Tapping the notification opens the **Standby Offer Screen** (`/standby-offer?requestId=...`).
4. Standby donor sees 5-minute countdown timer with **Accept Offer** and **Decline** options.
5. Upon acceptance, the request re-binds to `ACCEPTED` under the new donor, and the previous donor receives a neutral reassignment message.

---

## 6. Test Flow 5: Arrival, Donation & Completion (Part 6)

### Step 5.1: Arrival & Donation
1. Donor taps **Mark Arrived** (or geofence auto-detects within 100m) -> state: `ARRIVED`.
2. After donation procedure, donor taps **Mark Donated** -> state: `DONATED`.
3. Requester sees status update to `DONATED` and is prompted to confirm receipt.

### Step 5.2: Completion & Two-Sided Thanks Letter
1. Requester taps **Confirm Blood Received**.
2. State transitions to `COMPLETED`.
3. Verify both devices are redirected to the **Thank You Letter** screen (`/journey/thanks`).
4. Both devices are prompted for private donor/requester rating and feedback.
5. Chat room transitions to read-only with top banner: *"This request is closed. Messaging is disabled."*
6. Donor profile updates with +1 completed donation and initiates 90-day cooldown countdown.

---

## 7. Test Flow 6: Deep Links & Notification Routing (Part 2 & Part 10)

1. When app is in background or closed, send a test push or trigger a state event.
2. Tap the system push notification:
   - Verify `DeepLinkResolver` resolves `request_id` directly to `JourneyDetailScreen` or `ChatScreen`.
3. Tap Notification Bell icon in header:
   - Notification Center items display exact event titles.
   - Tapping an item opens the exact request without routing to generic `/blood-hub`.
