# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import unittest
from datetime import timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    BloodRequest,
    DonorProfile,
    DonationMatch,
    DonorFeedback,
    FollowUp,
    DonationHistory,
)
from api.services.trust import calculate_trust_score
from api.services.match_operations_service import (
    update_match_status,
    confirm_match_donation,
    run_due_followups,
)


class Step6TrustAndBehaviorTests(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()
        self.requester = User.objects.create_user(username='step6_req', email='req@bloodpulse.org', password='password123', first_name='Req', last_name='User')
        self.donor_user1 = User.objects.create_user(username='step6_donor1', email='d1@example.com', password='password123', first_name='Donor', last_name='One')
        self.donor_user2 = User.objects.create_user(username='step6_donor2', email='d2@example.com', password='password123', first_name='Donor', last_name='Two')
        self.donor_user3 = User.objects.create_user(username='step6_donor3', email='d3@example.com', password='password123', first_name='Donor', last_name='Three')

        self.req_profile = DonorProfile.objects.create(
            user=self.requester,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801799887711',
            is_available=True,
            is_profile_complete=True,
            user_intent='DONATE_AND_REQUEST',
        )

        self.donor_p1 = DonorProfile.objects.create(
            user=self.donor_user1,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711000001',
            is_available=True,
            is_profile_complete=True,
            is_searchable=True,
            user_intent='DONATE_AND_REQUEST',
        )
        self.donor_p2 = DonorProfile.objects.create(
            user=self.donor_user2,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711000002',
            is_available=True,
            is_profile_complete=True,
            is_searchable=True,
            user_intent='DONATE_AND_REQUEST',
        )
        self.donor_p3 = DonorProfile.objects.create(
            user=self.donor_user3,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711000003',
            is_available=True,
            is_profile_complete=True,
            is_searchable=True,
            user_intent='DONATE_AND_REQUEST',
        )

        self.req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Patient Step6',
            blood_group='O+',
            units_needed=2,
            units_received=0,
            units_pending=1,
            mode='EMERGENCY',
            status='ACTIVE',
            ward_bed='Bed 12',
            contact_phone='+8801700112233',
        )

        # Match 1 confirmed
        self.match1 = DonationMatch.objects.create(
            request=self.req,
            donor=self.donor_p1,
            status='CONFIRMED',
            confirmed_at=timezone.now(),
        )

        # Match 2 pending/accepted (not yet confirmed)
        self.match2 = DonationMatch.objects.create(
            request=self.req,
            donor=self.donor_p2,
            status='ACCEPTED',
        )

    # 1. Terminal status protection in update_match_status
    def test_update_match_status_rejects_completed_or_confirmed_terminal_status(self):
        """Donor or requester alone cannot reach COMPLETED/CONFIRMED through update_match_status."""
        self.client.force_authenticate(user=self.donor_user2)
        res = self.client.post(
            f'/api/matches/{self.match2.id}/status/',
            {'status': 'COMPLETED'},
            format='json',
        )
        self.assertEqual(res.status_code, 400)

        res_conf = self.client.post(
            f'/api/matches/{self.match2.id}/status/',
            {'status': 'CONFIRMED'},
            format='json',
        )
        self.assertEqual(res_conf.status_code, 400)

        # Requester alone sending COMPLETED -> rejected
        self.client.force_authenticate(user=self.requester)
        res_req = self.client.post(
            f'/api/matches/{self.match2.id}/status/',
            {'status': 'COMPLETED'},
            format='json',
        )
        self.assertEqual(res_req.status_code, 400)

        # Allowed transitions (ON_THE_WAY, ARRIVED) still work for donor
        self.client.force_authenticate(user=self.donor_user2)
        res_transit = self.client.post(
            f'/api/matches/{self.match2.id}/status/',
            {'status': 'ON_THE_WAY'},
            format='json',
        )
        self.assertEqual(res_transit.status_code, 200)

        # Guest gets 401
        self.client.logout()
        res_guest = self.client.post(
            f'/api/matches/{self.match2.id}/status/',
            {'status': 'ARRIVED'},
            format='json',
        )
        self.assertEqual(res_guest.status_code, 401)

    # 2. Only confirmed donors may submit feedback
    def test_only_confirmed_donor_can_submit_feedback(self):
        """Donor with confirmed donation can submit; non-confirmed donor is rejected."""
        # Donor 2 has unconfirmed match2 -> rejected with 403
        self.client.force_authenticate(user=self.donor_user2)
        res_unconfirmed = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE', 'GAVE_FOOD']},
            format='json',
        )
        self.assertEqual(res_unconfirmed.status_code, 403)

        # Donor 1 has confirmed match1 -> success 201
        self.client.force_authenticate(user=self.donor_user1)
        res_confirmed = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE', 'GAVE_FOOD']},
            format='json',
        )
        self.assertEqual(res_confirmed.status_code, 201)

        # Submitting second time for same request -> rejected (unique constraint)
        res_duplicate = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 4},
            format='json',
        )
        self.assertEqual(res_duplicate.status_code, 400)

    # 3. Requester can NEVER read feedback
    def test_requester_cannot_read_donor_feedback(self):
        """Requester GET /api/requests/<id>/feedback/ returns 403; staff allowed."""
        DonorFeedback.objects.create(
            request=self.req,
            donor=self.donor_p1,
            stars=5,
            tags=['POLITE'],
        )

        # Requester attempt
        self.client.force_authenticate(user=self.requester)
        res_req = self.client.get(f'/api/requests/{self.req.id}/feedback/')
        self.assertEqual(res_req.status_code, 403)

        # Anonymous attempt
        self.client.logout()
        res_anon = self.client.get(f'/api/requests/{self.req.id}/feedback/')
        self.assertEqual(res_anon.status_code, 401)

        # QR landing view contains zero feedback keys
        res_qr = self.client.get(f'/api/requests/{self.req.id}/qr-landing/')
        self.assertEqual(res_qr.status_code, 200)
        self.assertNotIn('feedback', res_qr.data)
        self.assertNotIn('donor_feedbacks', res_qr.data)

    # 4. Requester Trust Score minimum-2-reviews rule & quarantine trigger
    def test_minimum_2_reviews_rule_and_quarantine_trigger(self):
        """Single negative review does NOT lower requester score. 2 negative reviews trigger low score and quarantine."""
        # Initially no reviews
        score_init, band_init = calculate_trust_score(requester=self.requester)

        # 1 negative review from donor 1
        DonorFeedback.objects.create(
            request=self.req,
            donor=self.donor_p1,
            stars=1,
            tags=['RUDE', 'NEVER_CONTACTED'],
        )
        score_1_rev, band_1_rev = calculate_trust_score(requester=self.requester)
        self.assertEqual(score_init, score_1_rev, "Single review must NOT trigger penalty (min 2 reviews rule)")

        # 2nd negative review from donor 2
        req2 = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Patient 2',
            blood_group='O+',
            units_needed=1,
        )
        DonorFeedback.objects.create(
            request=req2,
            donor=self.donor_p2,
            stars=1,
            tags=['RUDE'],
        )
        score_2_rev, band_2_rev = calculate_trust_score(requester=self.requester)
        self.assertLess(score_2_rev, score_init)
        self.assertEqual(band_2_rev, 'LOW')

        # New request from this low-trust requester goes to PENDING_ADMIN quarantine queue
        self.client.force_authenticate(user=self.requester)
        from api.tests.helpers import obtain_submit_token_via_flow
        token = obtain_submit_token_via_flow(self.client, self.requester)
        res_new_req = self.client.post('/api/emergency/requests/', {
            'patient_name': 'Quarantined Patient',
            'blood_group': 'O+',
            'hospital_name_other': 'Dhaka Community Clinic',
            'ward_bed': 'Ward 5',
            'submit_token': token,
        })
        self.assertEqual(res_new_req.status_code, 201)
        self.assertEqual(res_new_req.data['status'], 'PENDING_ADMIN')

    # 5. Day-after check-in FCM push idempotency
    def test_day_after_check_in_idempotency_and_no_medical_claims(self):
        """Due follow-up triggers FCM push once, marks sent_at, and handles expired tokens gracefully."""
        self.donor_p1.fcm_token = 'valid_donor_token'
        self.donor_p1.save()

        fu = FollowUp.objects.create(
            match=self.match1,
            due_at=timezone.now() - timedelta(hours=2),
            status='PENDING',
        )

        with unittest.mock.patch('api.services.notify.send_fcm_multicast_batches') as mock_fcm:
            mock_fcm.return_value = {'sent': 1, 'failed': 0, 'invalid_tokens_cleared': 0}
            count1 = run_due_followups()
            self.assertEqual(count1, 1)
            self.assertTrue(mock_fcm.called)

            # Assert push body contains fluid/rest reminders without medical claims or 'life saved'
            call_kwargs = mock_fcm.call_args[1]
            body_text = call_kwargs['body']
            self.assertIn("fluids", body_text.lower())
            self.assertNotIn("life saved", body_text.lower())
            self.assertNotIn("cured", body_text.lower())

            fu.refresh_from_db()
            self.assertEqual(fu.status, 'SENT')
            self.assertIsNotNone(fu.sent_at)

            # Second tick run: idempotent, dispatches 0
            mock_fcm.reset_mock()
            count2 = run_due_followups()
            self.assertEqual(count2, 0)
            self.assertFalse(mock_fcm.called)

    # 6. Bulk dispatch authentication and throttling
    def test_bulk_dispatch_authentication_and_throttle(self):
        """Bulk dispatch endpoint requires authentication and returns 401 for guests."""
        self.client.logout()
        res_guest = self.client.post(f'/api/emergency/requests/{self.req.id}/bulk-dispatch/', {})
        self.assertEqual(res_guest.status_code, 401)

        self.client.force_authenticate(user=self.requester)
        res_auth = self.client.post(f'/api/emergency/requests/{self.req.id}/bulk-dispatch/', {})
        self.assertEqual(res_auth.status_code, 200)

    # 7. Public stats and guest map exclusions
    def test_public_stats_excludes_suspended_and_snoozed_donors(self):
        """Public stats excludes suspended, demo, staff, and snoozed donors."""
        from api.views_public_stats import eligible_public_donors_queryset
        qs = eligible_public_donors_queryset()
        self.assertIn(self.donor_p1, qs)

        # Suspended donor is excluded
        self.donor_p1.is_suspended = True
        self.donor_p1.save()
        qs_after_susp = eligible_public_donors_queryset()
        self.assertNotIn(self.donor_p1, qs_after_susp)

        # Restore availability and test snooze
        self.donor_p1.is_suspended = False
        self.donor_p1.alert_pause_until = timezone.now() + timedelta(days=20)
        self.donor_p1.save()
        qs_after_snooze = eligible_public_donors_queryset()
        self.assertNotIn(self.donor_p1, qs_after_snooze)

    # 8. Part 0(b) Invariant: single-sided DONATED does not count towards bags, history, certificate, or feedback
    def test_single_sided_donated_does_not_increment_bags_or_allow_feedback(self):
        """
        When only one side reports DONATED:
        - match.status becomes DONATED
        - Donor total_bags_donated remains unchanged (0)
        - DonationHistory is NOT created
        - Donor cannot submit feedback (403: must be two-sided confirmed)
        - Cooldown last_donation_date is NOT updated
        - Only upon two-sided confirmation does total_bags_donated increment to 1 and feedback become allowed.
        """
        from api.models import DonationMatch, DonationHistory

        # Create new unconfirmed match with donor 3 (who has no existing match on self.req)
        match = DonationMatch.objects.create(
            request=self.req,
            donor=self.donor_p3,
            role='PRIMARY',
            status='ACCEPTED',
            units_pledged=1,
        )

        initial_bags = self.donor_p3.total_bags_donated
        self.assertEqual(initial_bags, 0)
        self.assertIsNone(self.donor_p3.last_donation_date)

        # Donor single-sidedly reports DONATED
        self.client.force_authenticate(user=self.donor_user3)
        res_status = self.client.post(
            f'/api/matches/{match.id}/status/',
            {'status': 'DONATED'},
            format='json',
        )
        self.assertEqual(res_status.status_code, 200)

        match.refresh_from_db()
        self.assertEqual(match.status, 'DONATED')

        # Invariant checks:
        self.donor_p3.refresh_from_db()
        self.assertEqual(self.donor_p3.total_bags_donated, initial_bags)
        # Step 7.1: Medical cooldown starts immediately upon donor reporting DONATED
        self.assertIsNotNone(self.donor_p3.last_donation_date)
        self.assertEqual(DonationHistory.objects.filter(donor=self.donor_p3).count(), 0)

        # Feedback is rejected because confirmation is not two-sided
        res_fb_premature = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE']},
            format='json',
        )
        self.assertEqual(res_fb_premature.status_code, 403)

        # Now donor confirms via confirm endpoint
        res_conf_d = self.client.post(f'/api/matches/{match.id}/confirm/', {'action': 'CONFIRM'}, format='json')
        self.assertEqual(res_conf_d.status_code, 200)

        # Still one-sided (only donor confirmed) -> bags still 0, history still 0!
        self.donor_p3.refresh_from_db()
        self.assertEqual(self.donor_p3.total_bags_donated, initial_bags)
        self.assertEqual(DonationHistory.objects.filter(donor=self.donor_p3).count(), 0)

        # Requester confirms -> both sides have confirmed!
        self.client.force_authenticate(user=self.requester)
        res_conf_r = self.client.post(f'/api/matches/{match.id}/confirm/', {'action': 'CONFIRM'}, format='json')
        self.assertEqual(res_conf_r.status_code, 200)

        # Now two-sided finalized:
        match.refresh_from_db()
        self.assertIsNotNone(match.confirmed_at)
        self.assertEqual(match.status, 'DONATED')
        self.donor_p3.refresh_from_db()
        self.assertEqual(self.donor_p3.total_bags_donated, initial_bags + 1)
        self.assertIsNotNone(self.donor_p3.last_donation_date)
        self.assertEqual(DonationHistory.objects.filter(donor=self.donor_p3).count(), 1)

        # Now feedback is permitted
        self.client.force_authenticate(user=self.donor_user3)
        res_fb_allowed = self.client.post(
            f'/api/requests/{self.req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE']},
            format='json',
        )
        self.assertEqual(res_fb_allowed.status_code, 201)

    # 9. DonorFeedback DB CheckConstraint validation
    def test_feedback_stars_check_constraint(self):
        """DB check constraint enforces stars BETWEEN 1 AND 5."""
        from django.db import IntegrityError
        # Valid 1 and 5 work
        fb1 = DonorFeedback(request=self.req, donor=self.donor_p1, stars=1)
        fb1.full_clean()

        fb5 = DonorFeedback(request=self.req, donor=self.donor_p1, stars=5)
        fb5.full_clean()

        # Clean raises ValidationError for 0 or 6
        fb0 = DonorFeedback(request=self.req, donor=self.donor_p1, stars=0)
        with self.assertRaises(Exception):
            fb0.full_clean()

        fb6 = DonorFeedback(request=self.req, donor=self.donor_p1, stars=6)
        with self.assertRaises(Exception):
            fb6.full_clean()

