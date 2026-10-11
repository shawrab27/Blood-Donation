"""
Step 3: Blood Request Lifecycle comprehensive test suite.
Covers Parts 0, A, B, C, D, E, F, H.
"""

import hashlib
from datetime import timedelta
from django.contrib import admin
from django.contrib.auth.models import User
from django.core.cache import cache
from django.core.management import call_command
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from api.conf import DONOR_COOLDOWN_DAYS
from api.models import (
    BloodRequest,
    BrokerReport,
    DonationMatch,
    DonorProfile,
    RequestAcceptance,
    RequestSubmitToken,
)
from blood_pulse_backend.safe_settings import verify_postgres_test_db_guard


class Step3RequestLifecycleTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()

        self.requester = User.objects.create_user(
            username="requester_step3",
            email="requester_step3@example.com",
            password="Password123!",
            first_name="Rahim",
        )
        DonorProfile.objects.create(
            user=self.requester,
            blood_group="A+",
            phone_number="+8801700000001",
            district="Dhaka",
            is_available=True,
            is_profile_complete=True,
        )

        self.donor1 = User.objects.create_user(
            username="donor1_step3",
            email="donor1_step3@example.com",
            password="Password123!",
            first_name="Karim",
        )
        self.profile1 = DonorProfile.objects.create(
            user=self.donor1,
            blood_group="A+",
            phone_number="+8801700000002",
            district="Dhaka",
            is_available=True,
            is_profile_complete=True,
            user_intent="DONATE_AND_REQUEST",
        )

        self.donor2 = User.objects.create_user(
            username="donor2_step3",
            email="donor2_step3@example.com",
            password="Password123!",
            first_name="Salma",
        )
        self.profile2 = DonorProfile.objects.create(
            user=self.donor2,
            blood_group="A+",
            phone_number="+8801700000003",
            district="Dhaka",
            is_available=True,
            is_profile_complete=True,
            user_intent="DONATE_AND_REQUEST",
        )

        self.donor3 = User.objects.create_user(
            username="donor3_step3",
            email="donor3_step3@example.com",
            password="Password123!",
            first_name="Nadia",
        )
        self.profile3 = DonorProfile.objects.create(
            user=self.donor3,
            blood_group="A+",
            phone_number="+8801700000004",
            district="Dhaka",
            is_available=True,
            is_profile_complete=True,
            user_intent="DONATE_AND_REQUEST",
        )

    def _issue_submit_token(self, user):
        token_str = f"tok_{timezone.now().timestamp()}_{user.id}_{RequestSubmitToken.objects.count()}"
        token_hash = hashlib.sha256(token_str.encode("utf-8")).hexdigest()
        RequestSubmitToken.objects.create(
            user=user,
            token_hash=token_hash,
            purpose="blood_request_submit",
            expires_at=timezone.now() + timedelta(minutes=15),
        )
        return token_str

    # ── PART 0: Postgres safety guard ─────────────────────────────────────
    def test_part0_postgres_safety_guard_rules(self):
        with self.assertRaisesMessage(RuntimeError, "DATABASE_URL_TEST is missing"):
            verify_postgres_test_db_guard("", "postgres://user:pw@prod.neon.tech/neondb")

        with self.assertRaisesMessage(RuntimeError, "identical to DATABASE_URL"):
            verify_postgres_test_db_guard(
                "postgres://user:pw@prod.neon.tech/neondb",
                "postgres://user:pw@prod.neon.tech/neondb",
            )

        with self.assertRaisesMessage(RuntimeError, "matches the production host"):
            verify_postgres_test_db_guard(
                "postgres://user:pw@prod.neon.tech/testdb",
                "postgres://user:pw@prod.neon.tech/neondb",
            )

        with self.assertRaisesMessage(RuntimeError, "must be a PostgreSQL URL"):
            verify_postgres_test_db_guard(
                "sqlite:///:memory:",
                "postgres://user:pw@prod.neon.tech/neondb",
            )

        # Safe distinct PostgreSQL test host passes
        self.assertTrue(
            verify_postgres_test_db_guard(
                "postgresql://postgres:postgres@localhost:5432/bloodpulse_test",
                "postgres://user:pw@prod.neon.tech/neondb",
            )
        )

    # ── PART A: Request model, units invariant, SELF vs PROXY ────────────
    def test_partA_request_mode_self_and_proxy_and_units_bounds(self):
        self.client.force_authenticate(user=self.requester)

        # Create PROXY request with 2 units
        tok1 = self._issue_submit_token(self.requester)
        res_proxy = self.client.post(
            "/api/requests/",
            {
                "submit_token": tok1,
                "patient_name": "Patient One",
                "blood_group": "A+",
                "units_needed": 2,
                "request_mode": "PROXY",
                "hospital_name_other": "Dhaka Medical College Hospital",
                "district": "Dhaka",
                "contact_phone": "+8801700000001",
            },
            format="json",
        )
        self.assertEqual(res_proxy.status_code, 201)
        self.assertEqual(res_proxy.data["request_mode"], "PROXY")
        self.assertEqual(res_proxy.data["units_needed"], 2)
        self.assertEqual(res_proxy.data["units_received"], 0)
        self.assertEqual(res_proxy.data["units_pending"], 0)

        # Create SELF request
        tok2 = self._issue_submit_token(self.requester)
        res_self = self.client.post(
            "/api/requests/",
            {
                "submit_token": tok2,
                "patient_name": "Rahim Self",
                "blood_group": "A+",
                "units_needed": 1,
                "request_mode": "SELF",
                "hospital_name_other": "Square Hospital",
                "district": "Dhaka",
                "contact_phone": "+8801700000001",
            },
            format="json",
        )
        self.assertEqual(res_self.status_code, 201)
        self.assertEqual(res_self.data["request_mode"], "SELF")

        # Units > 5 rejected per decisions.md (1..5 bags max) and submit_token is NOT burned
        tok3 = self._issue_submit_token(self.requester)
        tok3_hash = hashlib.sha256(tok3.encode("utf-8")).hexdigest()
        res_over = self.client.post(
            "/api/requests/",
            {
                "submit_token": tok3,
                "patient_name": "Too Many Units",
                "blood_group": "A+",
                "units_needed": 6,
                "request_mode": "PROXY",
                "hospital_name_other": "Square Hospital",
            },
            format="json",
        )
        self.assertEqual(res_over.status_code, 400)
        self.assertFalse(RequestSubmitToken.objects.get(token_hash=tok3_hash).is_used)

        # Locked units_needed after request is posted
        req_id = res_proxy.data["id"]
        patch_res = self.client.patch(
            f"/api/requests/{req_id}/",
            {"units_needed": 4},
            format="json",
        )
        self.assertEqual(patch_res.status_code, 400)

    def test_partA_slot_invariant_prevents_overfilling_last_slot(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Slot Patient",
            blood_group="A+",
            units_needed=2,
            request_mode="PROXY",
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )

        # Donor 1 pledges 1 unit -> 0 received, 1 pending
        self.client.force_authenticate(user=self.donor1)
        r1 = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(r1.status_code, 201)
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 1)
        self.assertEqual(req.units_received, 0)

        # Donor 2 tries to pledge 2 units when only 1 slot remains -> rejected (409 ConflictError)
        self.client.force_authenticate(user=self.donor2)
        r2_over = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 2},
            format="json",
        )
        self.assertIn(r2_over.status_code, (400, 409))

        # Donor 2 pledges 1 unit -> 0 received, 2 pending (full)
        r2_ok = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "VOLUNTARY_ONLY", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(r2_ok.status_code, 201)
        self.assertEqual(r2_ok.data["support_status"], "VOLUNTARY_ONLY")
        self.assertEqual(r2_ok.data["support_status_label"], "Voluntary Only / Charity")

        # Donor 3 tries to pledge 1 unit when 0 slots remain -> rejected
        self.client.force_authenticate(user=self.donor3)
        r3 = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertIn(r3.status_code, (400, 409))
        req.refresh_from_db()
        self.assertEqual(req.units_received + req.units_pending, 2)

    # ── PART B: Donor Support Status, Withdraw, Unique Constraint, Eligibility ──
    def test_partB_duplicate_donor_response_blocked_and_db_unique_constraint(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Dup Patient",
            blood_group="A+",
            units_needed=3,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)
        first = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(first.status_code, 201)

        # Second API response from same donor is cleanly rejected
        second = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertIn(second.status_code, (400, 409))
        self.assertIn("already responded", str(second.data).lower())

        # Direct DB insert also fails due to unique_request_donor_acceptance constraint
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                RequestAcceptance.objects.create(
                    request=req,
                    donor=self.profile1,
                    status="ACCEPTED",
                )

    def test_partB_withdraw_before_confirmation_releases_pending_units_atomically(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Withdraw Patient",
            blood_group="A+",
            units_needed=1,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)
        accept_res = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(accept_res.status_code, 201)
        match_id = accept_res.data["id"]
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 1)

        # Withdraw before confirmation
        withdraw_res = self.client.post(
            f"/api/matches/{match_id}/withdraw/",
            {"reason": "Emergency came up"},
            format="json",
        )
        self.assertEqual(withdraw_res.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 0)
        self.assertEqual(req.units_received, 0)
        self.assertEqual(req.status, "OPEN")

        # Now donor2 can take the released slot
        self.client.force_authenticate(user=self.donor2)
        accept2 = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "VOLUNTARY_ONLY", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(accept2.status_code, 201)
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 1)

    def test_partB_eligibility_cooldown_snooze_suspended_available_and_intent(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Elig Patient",
            blood_group="A+",
            units_needed=2,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)

        # 1. Cooldown check using DONOR_COOLDOWN_DAYS from api/conf.py
        self.profile1.last_donation_date = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS - 5)
        self.profile1.save()
        r_cooldown = self.client.post(f"/api/requests/{req.id}/accept/", {}, format="json")
        self.assertIn(r_cooldown.status_code, (400, 409))
        self.assertIn("cooldown", str(r_cooldown.data).lower())

        # Reset cooldown, test snooze (alert_pause_until)
        self.profile1.last_donation_date = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS + 1)
        self.profile1.alert_pause_until = timezone.now() + timedelta(days=2)
        self.profile1.save()
        r_snooze = self.client.post(f"/api/requests/{req.id}/accept/", {}, format="json")
        self.assertIn(r_snooze.status_code, (400, 409))
        self.assertTrue(
            "paused" in str(r_snooze.data).lower() or "snooze" in str(r_snooze.data).lower()
        )

        # Reset snooze, test is_suspended
        self.profile1.alert_pause_until = None
        self.profile1.is_suspended = True
        self.profile1.save()
        r_susp = self.client.post(f"/api/requests/{req.id}/accept/", {}, format="json")
        self.assertIn(r_susp.status_code, (400, 409))
        self.assertIn("suspended", str(r_susp.data).lower())

        # Reset suspended, test user_intent = ONLY_REQUEST
        self.profile1.is_suspended = False
        self.profile1.user_intent = "ONLY_REQUEST"
        self.profile1.save()
        r_intent = self.client.post(f"/api/requests/{req.id}/accept/", {}, format="json")
        self.assertIn(r_intent.status_code, (400, 409))

        # Reset user_intent, test is_available = False
        self.profile1.user_intent = "DONATE_AND_REQUEST"
        self.profile1.is_available = False
        self.profile1.save()
        r_avail = self.client.post(f"/api/requests/{req.id}/accept/", {}, format="json")
        self.assertIn(r_avail.status_code, (400, 409))

    # ── PART C & E: Two-sided confirmation, idempotency, disagreement, auto-close ──
    def test_partC_and_partE_two_sided_confirmation_idempotency_and_auto_close(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Confirm Patient",
            blood_group="A+",
            units_needed=1,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )

        # Donor 1 accepts 1 unit
        self.client.force_authenticate(user=self.donor1)
        acc = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(acc.status_code, 201)
        match_id = acc.data["id"]

        # Step 1: Donor confirms "I donated" -> one-sided confirmation keeps unit in pending
        c_donor = self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        self.assertEqual(c_donor.status_code, 200)
        self.assertIsNotNone(c_donor.data["donor_confirmed_at"])
        self.assertIsNone(c_donor.data["requester_confirmed_at"])
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 1)
        self.assertEqual(req.units_received, 0)
        self.assertNotIn(req.status, ("CLOSED", "FULFILLED"))

        # Repeat donor confirmation is idempotent
        c_donor_repeat = self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        self.assertEqual(c_donor_repeat.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 1)
        self.assertEqual(req.units_received, 0)

        # Step 2: Requester confirms "I received" -> both confirmed!
        # Decrements units_pending, increments units_received, and auto-closes inside the same transaction
        self.client.force_authenticate(user=self.requester)
        c_req = self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        self.assertEqual(c_req.status_code, 200)
        self.assertIsNotNone(c_req.data["confirmed_at"])
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 0)
        self.assertEqual(req.units_received, 1)
        self.assertIn(req.status, ("CLOSED", "FULFILLED"))
        self.assertIsNotNone(req.closed_at)
        self.assertIn(req.close_reason, ("FULFILLED", "UNITS_FULFILLED"))

        # Repeat requester confirmation is idempotent (does not double-increment units_received)
        c_req_repeat = self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        self.assertEqual(c_req_repeat.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.units_received, 1)
        self.assertEqual(req.units_pending, 0)

        # Closed request remains readable for closed QR page, with "No longer needed — thank you"
        qr_detail = self.client.get(f"/api/requests/{req.id}/qr-landing/")
        self.assertEqual(qr_detail.status_code, 200)
        self.assertTrue(qr_detail.data["is_closed"])
        self.assertEqual(qr_detail.data["closed_banner_message"], "No longer needed — thank you")

        # Closed request rejects any new donor responses
        self.client.force_authenticate(user=self.donor2)
        reject_closed = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertIn(reject_closed.status_code, (400, 409))

    def test_partC_dispute_releases_pending_units_without_incrementing_received(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Dispute Patient",
            blood_group="A+",
            units_needed=2,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)
        acc = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(acc.status_code, 201)
        match_id = acc.data["id"]
        # Donor claims donated
        self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        # Requester disputes (says not received)
        self.client.force_authenticate(user=self.requester)
        disp = self.client.post(
            f"/api/matches/{match_id}/confirm/",
            {"action": "DISPUTE", "note": "Donor did not arrive at hospital"},
            format="json",
        )
        self.assertEqual(disp.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.units_pending, 0)
        self.assertEqual(req.units_received, 0)
        self.assertEqual(req.status, "OPEN")

    # ── PART D: Report Broker ─────────────────────────────────────────────
    def test_partD_report_broker_creates_queue_item_and_hides_reporter_pii(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Report Patient",
            blood_group="A+",
            units_needed=1,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)
        res = self.client.post(
            "/api/reports/broker/",
            {
                "request": req.id,
                "reported_user": self.requester.id,
                "target_type": "BROKER",
                "reason": "MONEY_DEMANDED",
                "details": "Caller asked for 2000 BDT processing fee.",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["status"], "PENDING")
        # Ensure reporter phone, email, and exact location are NOT in the serialized response
        self.assertNotIn("phone", str(res.data).lower())
        self.assertNotIn("email", str(res.data).lower())
        self.assertNotIn(self.profile1.phone_number, str(res.data))
        self.assertNotIn(self.donor1.email, str(res.data))

        # Verify record exists in DB and is registered in Django Admin
        self.assertEqual(BrokerReport.objects.count(), 1)
        self.assertIn(BrokerReport, admin.site._registry)

    # ── PART E: Auto-close on expiry management command idempotency ──────
    def test_partE_expire_stale_requests_command_is_idempotent(self):
        expired_req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Expired Patient",
            blood_group="A+",
            units_needed=2,
            units_pending=1,
            status="OPEN",
            expires_at=timezone.now() - timedelta(minutes=5),
        )
        call_command("expire_stale_requests")
        expired_req.refresh_from_db()
        self.assertEqual(expired_req.status, "EXPIRED")
        self.assertEqual(expired_req.units_pending, 0)
        self.assertEqual(expired_req.close_reason, "EXPIRED")
        first_closed_at = expired_req.closed_at
        self.assertIsNotNone(first_closed_at)

        # Running a second time is safe and idempotent
        call_command("expire_stale_requests")
        expired_req.refresh_from_db()
        self.assertEqual(expired_req.status, "EXPIRED")
        self.assertEqual(expired_req.closed_at, first_closed_at)

    # ── PART F: Rate limit with retry_after ──────────────────────────────
    def test_partF_rate_limit_429_includes_retry_after_and_bilingual_message(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Throttle Patient",
            blood_group="A+",
            units_needed=2,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.client.force_authenticate(user=self.donor1)
        acc = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(acc.status_code, 201)
        match_id = acc.data["id"]

        # Hit confirm endpoint repeatedly to trigger DonationConfirmThrottle (40/hour)
        throttled_response = None
        for _ in range(45):
            r = self.client.post(
                f"/api/matches/{match_id}/confirm/",
                {"action": "CONFIRM"},
                format="json",
            )
            if r.status_code == 429:
                throttled_response = r
                break

        self.assertIsNotNone(throttled_response, "Expected HTTP 429 after exceeding throttle rate")
        self.assertEqual(throttled_response.status_code, 429)
        self.assertIn("retry_after", throttled_response.data)
        self.assertGreaterEqual(int(throttled_response.data["retry_after"]), 1)
        self.assertIn("Retry-After", throttled_response.headers)
        self.assertIn("message_en", throttled_response.data)
        self.assertIn("message_bn", throttled_response.data)

    # ── PART H: Phone masking until matched/authorized ───────────────────
    def test_partH_phone_masked_for_unmatched_caller_and_visible_when_matched(self):
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Privacy Patient",
            blood_group="A+",
            units_needed=2,
            contact_phone="+8801711223344",
            contact_number="+8801711223344",
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        # Unmatched donor3 views request -> phone is masked
        self.client.force_authenticate(user=self.donor3)
        unmatched_res = self.client.get(f"/api/requests/{req.id}/")
        self.assertEqual(unmatched_res.status_code, 200)
        self.assertNotEqual(unmatched_res.data["contact_phone_display"], "+8801711223344")
        self.assertIn("*", unmatched_res.data["contact_phone_display"])

        # Donor1 accepts request -> Donor1 is now matched and sees full contact_phone_display
        self.client.force_authenticate(user=self.donor1)
        self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        matched_res = self.client.get(f"/api/requests/{req.id}/")
        self.assertEqual(matched_res.status_code, 200)
        self.assertEqual(matched_res.data["contact_phone_display"], "+8801711223344")

    # ── Missing Tests: Guest 401 & Migration 0041 pre-check ───────────────
    def test_guest_gets_401_on_all_new_step3_endpoints(self):
        """Guests (unauthenticated callers) receive HTTP 401 on all new Step 3 stateful endpoints."""
        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Guest Test Patient",
            blood_group="A+",
            units_needed=2,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )
        match = DonationMatch.objects.create(
            request=req,
            donor=self.profile1,
            status="ACCEPTED",
            units_pledged=1,
        )

        self.client.logout()

        # 1. Accept request
        r1 = self.client.post(
            f"/api/requests/{req.id}/accept/",
            {"support_status": "CAN_SUPPORT", "units_pledged": 1},
            format="json",
        )
        self.assertEqual(r1.status_code, 401, f"Expected 401 for guest accept, got {r1.status_code}")

        # 2. Confirm donation
        r2 = self.client.post(
            f"/api/matches/{match.id}/confirm/",
            {"action": "CONFIRM"},
            format="json",
        )
        self.assertEqual(r2.status_code, 401, f"Expected 401 for guest confirm, got {r2.status_code}")

        # 3. Withdraw donation
        r3 = self.client.post(
            f"/api/matches/{match.id}/withdraw/",
            {"reason": "Guest withdrawal attempt"},
            format="json",
        )
        self.assertEqual(r3.status_code, 401, f"Expected 401 for guest withdraw, got {r3.status_code}")

        # 4. Report broker generic
        r4 = self.client.post(
            "/api/reports/broker/",
            {"reason": "Broker demand", "details": "Guest trying to report"},
            format="json",
        )
        self.assertEqual(r4.status_code, 401, f"Expected 401 for guest report broker, got {r4.status_code}")

        # 5. Report broker specific to request
        r5 = self.client.post(
            f"/api/requests/{req.id}/report-broker/",
            {"reason": "Broker demand"},
            format="json",
        )
        self.assertEqual(r5.status_code, 401, f"Expected 401 for guest request report-broker, got {r5.status_code}")

    def test_partB_migration_0041_duplicate_pre_check_raises_clean_error(self):
        """Migration 0041 RunPython pre-check detects duplicates and raises RuntimeError listing counts only."""
        from django.apps import apps
        import importlib
        mig_0041 = importlib.import_module("api.migrations.0041_step3_request_lifecycle")
        check_no_duplicate_request_acceptances = mig_0041.check_no_duplicate_request_acceptances

        req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name="Precheck Patient",
            blood_group="A+",
            units_needed=2,
            status="OPEN",
            expires_at=timezone.now() + timedelta(hours=12),
        )

        # In current state, unique constraint is active. If duplicate existed prior to constraint,
        # the pre-check function must raise a clear RuntimeError.
        # We test the function directly:
        import unittest
        with unittest.mock.patch("django.db.models.query.QuerySet.count", return_value=2), \
             unittest.mock.patch("django.db.models.query.QuerySet.__iter__", return_value=iter([{"count": 2}, {"count": 3}])):
            with self.assertRaises(RuntimeError) as ctx:
                check_no_duplicate_request_acceptances(apps, None)
            err_msg = str(ctx.exception)
            self.assertIn("Cannot apply UNIQUE(request, donor) constraint", err_msg)
            self.assertIn("found 2 (request, donor) pair(s)", err_msg)
            self.assertIn("5 total rows", err_msg)
            # Assert no phone numbers or personal names appear in error message
            self.assertNotIn("+880", err_msg)
            self.assertNotIn(self.requester.username, err_msg)

