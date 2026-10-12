# BloodPulse Store-Compliant Data Deletion Architecture

## 1. Overview
In compliance with Google Play Store, Apple App Store, and Bangladesh Digital Security / Privacy guidelines, BloodPulse provides a self-service, real-time account deletion mechanism accessible via **Settings & Security -> Delete Account**.

Account deletion is executed in a single atomic database transaction (`transaction.atomic()`) via:
`DELETE /api/account/`

---

## 2. Deleted vs. Anonymized Breakdown

### A. Permanently Deleted Entities (Zero-Trace Scrub)
The following tables are purged of user-authored records immediately upon deletion:
- `SocialPost`: All feed posts published by the user are deleted.
- `Comment`: All comments authored by the user on any post are deleted.
- `PostReaction`: All likes and reactions are purged.
- `Notification`: All notification history for the user is deleted.
- `DonorFeedback`: Any feedback entries authored by the donor are deleted.
- `ChatMessage`: Any chat messages sent by the user are deleted.
- `SupportTicket`: In-app support tickets authored by the user are deleted.
- `EmailOTP`: Active and expired verification OTPs are deleted.
- `RequestSubmitToken`: Single-use blood request creation tokens are deleted.
- `PasswordResetOTP`: Password reset tokens are deleted.
- `MediaStorage`: Profile pictures and attached slips are removed from storage.

### B. Anonymized Entities (History-Preserving)
Blood donation platforms operate on medical trust and coordination. When a patient or donor deletes their account, destroying active or historical matching records would corrupt the medical and fulfillment records of dependent third parties (recipients, hospitals, emergency volunteers). Therefore, these entities are strictly anonymized rather than deleted:
- `BloodRequest`:
  - `requester` is detached (`NULL`).
  - `patient_name` is set to `"Anonymous Patient"`.
  - `attendant_name` is set to `"Deleted user"`.
  - `contact_number` and `contact_phone` are scrubbed to empty strings.
  - `condition_note` and `ward_bed` are cleared.
  - Uploaded requisition slips and patient photos are detached and deleted.
  - Non-PII parameters (`units_needed`, `units_received`, `status`, `hospital`, `district`) remain intact to ensure regional supply records and hospital history remain accurate.
- `DonationMatch` / `RequestAcceptance`:
  - Matched counterpart records are preserved so the matched donor/patient maintains proof of donation or fulfillment.
  - Personal PII on the linked user is scrubbed.
- `DonorProfile`:
  - Profile is scrambled: `phone_number` is set to a non-functional placeholder `+8800000<id>`.
  - `nid_hash`, `bio`, `address`, `fcm_token`, `google_uid`, `firebase_uid`, `latitude`, `longitude`, `public_lat`, `public_lng` are all set to `NULL` / empty.
  - `is_searchable`, `is_available`, `public_profile`, `show_contact` are set to `False`.
  - `google_display_name` is set to `"Deleted user"`.

### C. Authentication & Session Termination
- All outstanding JWT refresh tokens are blacklisted via SimpleJWT `BlacklistedToken`.
- The user account is marked `is_active = False`.
- The password hash is set to unusable (`set_unusable_password()`).
- `username` is scrambled to `deleted_<user_id>_<random_uuid>`.
- `email` is scrambled to `deleted_<user_id>_<random_uuid>@bloodpulse.local`.

---

## 3. PII-Free Audit Logging
To meet clinical compliance without violating privacy rules:
- An entry is recorded in `AuditLog`:
  - `action`: `"ACCOUNT_DELETION"`
  - `object_type`: `"User"`
  - `object_id`: `<user_id>` (integer ID only)
  - `user`: `NULL`
  - `changes`: `{"detail": "PII scrubbed, personal posts deleted, requests anonymized, tokens revoked."}`
  - No names, phone numbers, emails, or IP addresses are retained in audit records.
