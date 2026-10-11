# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date, timedelta
from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    DonorProfile,
    BloodRequest,
    DonationMatch,
    DonationHistory,
    FollowUp,
    DonorFeedback,
)
from api.services.blood_hub_lifecycle_service import accept_request, update_match_status, confirm_match_donation
from api.services.eligibility import evaluate_donor_eligibility

User = get_user_model()


class CooldownAndConfirmationInvariantTests(TestCase):
    """
    Step 7.1 / Step 7b Carry-Over Invariant:
    1. Single-sided DONATED (donor alone reporting completion):
       - Safely starts the donor's 90-day medical cooldown (updates last_donation_date to today).
       - Immediately makes the donor ineligible for subsequent requests during the cooldown window.
       - STRICTLY PREVENTS gaming: does NOT increment total_bags_donated, does NOT create DonationHistory,
         does NOT generate FollowUp, does NOT permit submitting DonorFeedback, and does NOT generate certificates.
    2. Two-sided confirmation (both donor and requester confirm):
       - Fully satisfies all requirements: total_bags_donated increments, DonationHistory is recorded,
         FollowUp is queued, and DonorFeedback is allowed.
    """

    def setUp(self):
        self.client = APIClient()
        self.donor_user = User.objects.create_user(
            username='donor_invariant',
            email='donor_invariant@bloodpulse.org',
            password='testpassword123',
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            is_available=True,
            total_bags_donated=0,
            district='Dhaka',
            is_profile_complete=True,
        )

        self.requester_user = User.objects.create_user(
            username='requester_invariant',
            email='requester_invariant@bloodpulse.org',
            password='testpassword123',
        )

        self.req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Invariant',
            blood_group='O+',
            units_needed=1,
            district='Dhaka',
            status='OPEN',
        )

    def test_single_sided_donated_starts_cooldown_without_crediting_stats(self):
        # 1. Accept request
        match = accept_request(self.req.id, self.donor_user)
        self.assertEqual(match.status, 'ACCEPTED')

        # Move request to ARRIVED so transition to DONATED is valid
        self.req.status = 'ARRIVED'
        self.req.save(update_fields=['status'])

        # Verify donor is currently eligible before donation
        elig_before = evaluate_donor_eligibility(self.donor_profile)
        self.assertTrue(elig_before['is_eligible'])

        # 2. Donor single-sided status update to DONATED
        self.client.force_authenticate(user=self.donor_user)
        res_donated = self.client.post(
            f'/api/matches/{match.id}/status/',
            {'status': 'DONATED'},
            format='json',
        )
        self.assertEqual(res_donated.status_code, status.HTTP_200_OK)

        # Verify match progress updated
        match.refresh_from_db()
        self.assertEqual(match.status, 'DONATED')
        self.assertIsNotNone(match.donor_confirmed_at)
        self.assertIsNone(match.confirmed_at)

        # A. MEDICAL COOLDOWN SAFETY VERIFICATION:
        self.donor_profile.refresh_from_db()
        today = timezone.now().date()
        self.assertEqual(self.donor_profile.last_donation_date, today)

        # Verify donor is now INELIGIBLE due to the 90-day cooldown
        elig_after = evaluate_donor_eligibility(self.donor_profile)
        self.assertFalse(elig_after['is_eligible'])
        self.assertIn('cooldown', elig_after['reason'].lower())

        # B. ANTI-GAMING / UNCONFIRMED INVARIANTS:
        # total_bags_donated MUST NOT increment
        self.assertEqual(self.donor_profile.total_bags_donated, 0)

        # DonationHistory MUST NOT be created
        self.assertEqual(DonationHistory.objects.filter(donor=self.donor_profile).count(), 0)

        # FollowUp MUST NOT be created
        self.assertEqual(FollowUp.objects.filter(match=match).count(), 0)

        # Feedback MUST be rejected with 403 Forbidden
        res_fb = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE']},
            format='json',
        )
        self.assertEqual(res_fb.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(DonorFeedback.objects.filter(donor=self.donor_profile).count(), 0)

        # 3. Requester confirms -> two-sided confirmation achieved
        self.client.force_authenticate(user=self.requester_user)
        res_req_conf = self.client.post(
            f'/api/matches/{match.id}/confirm/',
            {'action': 'CONFIRM'},
            format='json',
        )
        self.assertEqual(res_req_conf.status_code, status.HTTP_200_OK)

        # C. POST-CONFIRMATION INVARIANTS:
        match.refresh_from_db()
        self.assertIsNotNone(match.confirmed_at)

        # total_bags_donated incremented
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.total_bags_donated, 1)

        # FollowUp created
        self.assertEqual(FollowUp.objects.filter(match=match).count(), 1)

        # Now donor feedback is permitted
        self.client.force_authenticate(user=self.donor_user)
        res_fb_ok = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE']},
            format='json',
        )
        self.assertEqual(res_fb_ok.status_code, status.HTTP_201_CREATED)
        self.assertEqual(DonorFeedback.objects.filter(donor=self.donor_profile).count(), 1)
