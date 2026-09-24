# BloodPulse Blood Hub — API Specification (API.md)

This document specifies the backend REST API endpoints for Blood Hub v2, supporting donor search, cluster map, authentic hospital autocomplete, multi-wave emergency requests, mutual acceptances, and fraud protection.

---

## 1. Authentication & Privacy Principles

1. **Deterministic Coordinate Fuzzing**: Public donor positions (`/api/donors/map/`) are deterministically fuzzed by approximately 500 meters (`COORDINATE_FUZZ_DEGREE = 0.0045`). Exact GPS is never transmitted over public endpoints.
2. **Contact Masking**: Donor and requester phone numbers are masked in search results and public request listings (e.g. `+880 17****1234`).
3. **Mutual Unmasking**: Full phone numbers and hospital bed details are revealed **only** when a verified donor accepts the request (`/api/emergency/requests/<id>/accept/`) or to the requester themselves.
4. **Metadata Sanitization**: Uploaded requisition slips and patient photos are stripped of EXIF, camera, and GPS metadata server-side via Pillow prior to storage.
5. **Idempotency**: Request creation supports `client_request_id` (UUID) to prevent duplicate submissions on flaky networks.

---

## 2. Endpoints

### 2.1 Search Donors
`GET /api/donors/search/`

Search available donors with component compatibility filtering and cursor pagination.

#### Query Parameters
- `blood_group` (optional): `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` (or normalized codes like `A_POS`).
- `component` (optional, default `WHOLE`): `WHOLE`, `RBC`, `PLATELETS`, `PLASMA`. Automatically expands query to compatible blood groups.
- `campus` (optional): University or college name filter.
- `district` (optional): District name filter.
- `limit` (optional, default `20`, max `50`): Result page size.
- `offset` (optional, default `0`): Pagination offset.

#### Response `200 OK`
```json
{
  "total": 12,
  "offset": 0,
  "limit": 20,
  "results": [
    {
      "id": 101,
      "username": "tariq_ahmed",
      "full_name": "Tariq Ahmed",
      "blood_group": "O+",
      "district": "Dhaka",
      "campus": "Dhaka University",
      "phone_masked": "+880 17****5678",
      "total_bags_donated": 6,
      "badge": "Platinum Donor",
      "rating_avg": 4.9,
      "rating_count": 8,
      "is_verified": true,
      "profile_picture": "http://.../profile.jpg",
      "last_donation_date": "2024-01-10",
      "is_eligible": true,
      "cooldown_days_remaining": 0
    }
  ]
}
```

---

### 2.2 Donor Map Pins
`GET /api/donors/map/`

Returns fuzzed donor pins for map viewports. Excludes non-searchable donors.

#### Query Parameters
- `blood_group` (optional): Target blood group.
- `component` (optional, default `WHOLE`): Target component.
- `district` (optional): District filter.

#### Response `200 OK`
```json
{
  "count": 48,
  "donors": [
    {
      "id": 101,
      "blood_group": "O+",
      "lat": 23.8142,
      "lng": 90.4158,
      "rating_avg": 4.9,
      "badge": "Platinum Donor",
      "is_verified": true,
      "campus": "Dhaka University"
    }
  ]
}
```

---

### 2.3 Hospital Directory
`GET /api/hospitals/directory/`

Autocomplete endpoint for authentic hospitals in Bangladesh.

#### Query Parameters
- `q` (optional): Search query matching English, Bengali, or colloquial names.
- `district` (optional): District filter.

#### Response `200 OK`
```json
[
  {
    "id": 1,
    "name": "Dhaka Medical College Hospital",
    "name_en": "Dhaka Medical College Hospital",
    "name_bn": "ঢাকা মেডিকেল কলেজ হাসপাতাল",
    "district": "Dhaka",
    "division": 1,
    "upazila": null,
    "address": "Secretariat Rd, Dhaka 1000",
    "lat": 23.7259,
    "lng": 90.3976,
    "phone": "+880255165088",
    "is_verified": true,
    "is_referral_center": true
  }
]
```

---

### 2.4 Emergency Blood Requests
`GET /api/emergency/requests/`
`POST /api/emergency/requests/`

#### GET Query Parameters
- `blood_group`, `urgency`, `district`, `status` (`ACTIVE`, `FULFILLED`, `EXPIRED`).

#### POST Request Payload (multipart/form-data or application/json)
```json
{
  "client_request_id": "7b63f58e-0cf5-4e78-bc4a-bf9695d62b9a",
  "patient_name": "Shamsur Rahman",
  "blood_group": "B+",
  "component": "WHOLE",
  "units_needed": 2,
  "urgency": "CRITICAL_2H",
  "condition_category": "SURGERY",
  "condition_note": "Emergency bypass surgery scheduled for 11 AM",
  "scope": "DISTRICT",
  "hospital_id": 1,
  "hospital_name_other": "",
  "ward_bed": "Cardio OT, Bed 3",
  "attendant_name": "Farhana Rahman",
  "contact_phone": "+8801711223344",
  "lat": 23.7259,
  "lng": 90.3976,
  "is_drill": false
}
```

#### POST Response `201 Created`
```json
{
  "id": 42,
  "requester_id": 5,
  "is_requester": true,
  "patient_name": "Shamsur Rahman",
  "blood_group": "B+",
  "component": "WHOLE",
  "units_needed": 2,
  "urgency": "CRITICAL_2H",
  "condition_category": "SURGERY",
  "condition_note": "Emergency bypass surgery scheduled for 11 AM",
  "scope": "DISTRICT",
  "effective_scope": "DISTRICT",
  "hospital_details": {
    "id": 1,
    "name": "Dhaka Medical College Hospital",
    "district": "Dhaka"
  },
  "ward_bed_display": "Cardio OT, Bed 3",
  "attendant_name": "Farhana Rahman",
  "contact_phone_display": "+8801711223344",
  "trust_score": 85,
  "trust_band": "HIGH",
  "status": "ACTIVE",
  "current_wave": 1,
  "next_wave_at": "2026-09-24T06:50:00Z",
  "expires_at": "2026-09-25T06:35:00Z",
  "active_acceptances_count": 0,
  "has_accepted": false,
  "created_at": "2026-09-24T06:35:00Z"
}
```

---

### 2.5 Request Details & Role-Based Masking
`GET /api/emergency/requests/<id>/`

Returns request details. If caller is an unauthenticated user or unrelated donor, `contact_phone_display` is masked and `ward_bed_display` is `"Protected"`. If caller is the requester or accepted donor, values are fully unmasked.

---

### 2.6 Accept Emergency Request
`POST /api/emergency/requests/<id>/accept/` *(Authenticated)*

Donor accepts the request.

#### Response `201 Created`
```json
{
  "message": "Request successfully accepted. Contact details unmasked.",
  "acceptance": {
    "id": 88,
    "request_id": 42,
    "donor_id": 101,
    "donor_name": "tariq_ahmed",
    "donor_blood_group": "B+",
    "donor_phone": "+8801712345678",
    "status": "ACCEPTED",
    "is_standby": false,
    "started_at": "2026-09-24T06:37:00Z"
  },
  "requester_phone": "+8801711223344",
  "ward_bed": "Cardio OT, Bed 3"
}
```

---

### 2.7 Report Fake Request
`POST /api/emergency/requests/<id>/report/` *(Authenticated)*

Flags suspect or fraudulent requests. 3+ community reports automatically quarantines request to `PENDING_ADMIN`.

#### Payload
```json
{
  "reason": "Hospital stated patient was discharged last week."
}
```

#### Response `201 Created`
```json
{
  "message": "Report submitted for administrator review.",
  "report_id": 15
}
```

---

### 2.8 Wave Tick Engine
`POST /api/emergency/tick/`

Advances wave cohorts and expires timed-out requests.

#### Response `200 OK`
```json
{
  "advanced": 2,
  "expired": 0,
  "escalated": 1
}
```

---

### 2.9 Journey Live Tracking (HTTP Polling Fallback)
`POST /api/journeys/<id>/location/` *(Authenticated Donor)*
`GET /api/journeys/<id>/location/` *(Authenticated Requester / Donor)*

#### POST Payload (Donor publishes GPS)
```json
{
  "lat": 23.8103,
  "lng": 90.4125
}
```

#### GET / POST Response `200 OK`
```json
{
  "acceptance_id": 88,
  "status": "ON_THE_WAY",
  "donor_lat": 23.8103,
  "donor_lng": 90.4125,
  "distance_km": 9.42,
  "eta_minutes": 40,
  "last_location_update": "2026-09-24T06:40:00Z",
  "destination": {
    "hospital_name": "Dhaka Medical College Hospital",
    "lat": 23.7259,
    "lng": 90.3976
  }
}
```

---

### 2.10 Journey Status Milestones
`POST /api/journeys/<id>/status/` *(Authenticated)*

Transitions journey state: `ON_THE_WAY`, `ARRIVED`, `DONATED`, `CANCELLED`.
When `DONATED`, automatically fulfills `BloodRequest`, records `DonationHistory`, and updates donor statistics.

#### Payload
```json
{
  "status": "DONATED"
}
```

---

### 2.11 Report Donation Issue & Standby Trigger
`POST /api/journeys/<id>/issue/` *(Authenticated)*

Reports an issue during donation (`MEDICAL_REJECTION`, `DONOR_NO_SHOW`, `LOGISTICS_DELAY`, `OTHER`).
If `MEDICAL_REJECTION`, records a 90-day medical deferral on the donor, fails the journey, and triggers a `StandbyOffer` to the best candidate backup donor.

#### Payload
```json
{
  "issue_type": "MEDICAL_REJECTION",
  "description": "Hemoglobin 11.2 g/dL below donation minimum."
}
```

#### Response `201 Created`
```json
{
  "message": "Issue reported successfully.",
  "issue": {
    "id": 5,
    "issue_type": "MEDICAL_REJECTION",
    "description": "Hemoglobin 11.2 g/dL below donation minimum."
  },
  "standby_triggered": true,
  "standby_offer_id": 14
}
```

---

### 2.12 Standby Backup Offers
`GET /api/standby/<offerId>/` *(Authenticated Standby Donor)*
`POST /api/standby/<offerId>/respond/` *(Authenticated Standby Donor)*

#### GET Response `200 OK`
```json
{
  "id": 14,
  "request_id": 42,
  "patient_name": "Shamsur Rahman",
  "blood_group": "B+",
  "hospital_name": "Dhaka Medical College Hospital",
  "district": "Dhaka",
  "status": "PENDING",
  "seconds_remaining": 540
}
```

#### POST Payload (`ACCEPT` or `DECLINE`)
```json
{
  "action": "ACCEPT"
}
```

#### POST Response `200 OK`
```json
{
  "message": "Standby offer accepted. You are now the primary active donor.",
  "acceptance_id": 92,
  "requester_phone": "+8801711223344",
  "ward_bed": "Cardio OT, Bed 3"
}
```

---

### 2.13 Brevo HTTPS Email OTP (Rule 8)
`POST /api/auth/otp/send/`
`POST /api/auth/otp/verify/`

Complies with Render's blocked SMTP ports (25, 465, 587) by routing all email traffic through Brevo's HTTPS REST API.
Enforces 60-second resend cooldown, maximum 3 requests per hour per email, and auto-locks after 5 failed attempts.
Plaintext codes are never stored in the database; HMAC-SHA256 hashes are verified in constant time.

#### Send OTP Payload
```json
{
  "email": "donor@example.com"
}
```

#### Verify OTP Payload
```json
{
  "email": "donor@example.com",
  "code": "729401"
}
```

#### Verify Response `200 OK`
```json
{
  "message": "Email address verified successfully.",
  "email": "donor@example.com",
  "email_verified": true
}
```

