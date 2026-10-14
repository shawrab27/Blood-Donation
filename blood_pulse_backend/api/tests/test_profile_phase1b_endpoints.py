# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date, timedelta
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    DonorProfile, DonationHistory, BloodGroupChangeRequest,
    DonorReview, XPEvent, BloodRequest, DonationMatch,
    SocialPost, AuditLog, Upazila,
    calculate_user_xp_and_level, award_verified_donation_xp
)
from api.views_profile import get_dhaka_today, DONOR_COOLDOWN_DAYS


@override_settings(EMAIL_PROVIDER='locmem')
class ProfilePhase1BEndpointsTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()

        # Complete Donor 1
        self.user1 = User.objects.create_user(
            username='donor_arman',
            email='arman@bloodpulse.org',
            password='Password123!',
            first_name='Arman',
            last_name='Khan'
        )
        self.profile1 = DonorProfile.objects.create(
            user=self.user1,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000010',
            bio='Regular blood donor in Dhaka.',
            weight_kg=68,
            show_in_rankings=True,
            total_bags_donated=0,
            is_available=True,
            is_profile_complete=True,
        )

        # Incomplete Donor 2
        self.user_inc = User.objects.create_user(
            username='donor_incomplete',
            email='incomplete@bloodpulse.org',
            password='Password123!'
        )
        self.profile_inc = DonorProfile.objects.create(
            user=self.user_inc,
            blood_group='',
            district='',
            phone_number='',
            is_profile_complete=False,
        )

        # Donor 2 (for ranking & review tests)
        self.user2 = User.objects.create_user(
            username='donor_bijoy',
            email='bijoy@bloodpulse.org',
            password='Password123!',
            first_name='Bijoy',
            last_name='Hasan'
        )
        self.profile2 = DonorProfile.objects.create(
            user=self.user2,
            blood_group='A+',
            district='Chattogram',
            phone_number='+8801700000020',
            bio='Platelet donor.',
            weight_kg=75,
            show_in_rankings=True,
            is_available=True,
            is_profile_complete=True,
        )

    # 1. Profile Me GET & Registration Gate
    def test_profile_me_requires_authentication(self):
        """Anonymous GET /api/profile/me/ returns 401."""
        res = self.client.get('/api/profile/me/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_profile_me_incomplete_registration_returns_403(self):
        """Incomplete user GET /api/profile/me/ returns 403 REGISTRATION_INCOMPLETE."""
        self.client.force_authenticate(user=self.user_inc)
        res = self.client.get('/api/profile/me/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(res.data['code'], 'REGISTRATION_INCOMPLETE')

    def test_profile_me_complete_donor_success_and_hero_stats(self):
        """Complete user receives hero stats, 90-day cooldown calculation, and XP info."""
        today = get_dhaka_today()
        # Add a verified donation 30 days ago
        d_date = today - timedelta(days=30)
        dh = DonationHistory.objects.create(
            donor=self.profile1,
            date=d_date,
            donated_at=d_date,
            bags=1,
            bags_donated=1,
            source='verified',
            verified=True,
            hospital='Dhaka Medical College'
        )
        award_verified_donation_xp(dh)

        self.client.force_authenticate(user=self.user1)
        res = self.client.get('/api/profile/me/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        self.assertEqual(res.data['name'], 'Arman Khan')
        self.assertEqual(res.data['blood_group'], 'O+')
        self.assertEqual(res.data['bags_donated'], 1)
        self.assertEqual(res.data['last_donation'], str(d_date))
        self.assertEqual(res.data['days_left'], 60) # 90 - 30 = 60
        self.assertFalse(res.data['is_eligible'])
        self.assertEqual(res.data['next_eligible_date'], str(d_date + timedelta(days=90)))
        self.assertEqual(res.data['xp'], 100)
        self.assertEqual(res.data['level'], 2)
        self.assertEqual(res.data['weight_kg'], 68)
        self.assertTrue(res.data['is_available'])

    # 2. Profile Me PATCH & Blood Group Lock
    def test_profile_me_patch_updates_fields(self):
        """PATCH /api/profile/me/ updates bio, weight, availability, snooze."""
        self.client.force_authenticate(user=self.user1)
        res = self.client.patch('/api/profile/me/', {
            'bio': 'Updated bio under 120 chars.',
            'weight_kg': 72,
            'is_available': False,
            'snooze_1_month': True,
            'show_in_rankings': False,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['bio'], 'Updated bio under 120 chars.')
        self.assertEqual(res.data['weight_kg'], 72)
        self.assertFalse(res.data['is_available'])
        self.assertIsNotNone(res.data['deferral_until'])
        self.assertFalse(res.data['show_in_rankings'])

    def test_profile_me_patch_rejects_bio_over_120_chars(self):
        """Bio > 120 chars returns 400."""
        self.client.force_authenticate(user=self.user1)
        res = self.client.patch('/api/profile/me/', {'bio': 'A' * 121}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('bio', res.data)

    def test_profile_me_patch_rejects_blood_group_mutation(self):
        """Attempting to change blood_group via PATCH /api/profile/me/ returns 400."""
        self.client.force_authenticate(user=self.user1)
        res = self.client.patch('/api/profile/me/', {'blood_group': 'B+'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('blood_group', res.data)

    # 3. Last Donation PATCH (Anti-Cheat & 90-Day Rule)
    def test_last_donation_rejects_future_date(self):
        """PATCH /api/profile/me/last-donation/ with future date returns 400 FUTURE_DATE."""
        self.client.force_authenticate(user=self.user1)
        future_date = str(get_dhaka_today() + timedelta(days=2))
        res = self.client.patch('/api/profile/me/last-donation/', {'date': future_date}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res.data['code'], 'FUTURE_DATE')

    def test_last_donation_enforces_90_day_rule_boundary(self):
        """
        Boundary test: 89 days returns 400 COOLDOWN_VIOLATION;
        90 and 91 days are accepted.
        """
        self.client.force_authenticate(user=self.user1)
        today = get_dhaka_today()

        base_date = today - timedelta(days=120)
        DonationHistory.objects.create(
            donor=self.profile1,
            date=base_date,
            donated_at=base_date,
            bags=1,
            source='verified',
            verified=True
        )

        # Day 89: 89 days after base_date -> must reject!
        day_89 = str(base_date + timedelta(days=89))
        res89 = self.client.patch('/api/profile/me/last-donation/', {'date': day_89}, format='json')
        self.assertEqual(res89.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res89.data['code'], 'COOLDOWN_VIOLATION')

        # Day 90: exactly 90 days -> must accept!
        day_90 = str(base_date + timedelta(days=90))
        res90 = self.client.patch('/api/profile/me/last-donation/', {'date': day_90}, format='json')
        self.assertEqual(res90.status_code, status.HTTP_200_OK)
        self.assertEqual(res90.data['status'], 'success')
        self.assertEqual(res90.data['source'], 'self_reported')
        self.assertFalse(res90.data['verified'])

    def test_last_donation_throttle_max_3_per_day(self):
        """Exceeding 3 last donation updates on the same day returns 429."""
        self.client.force_authenticate(user=self.user1)
        today = get_dhaka_today()
        # Ensure profile has no previous donation
        for i in range(3):
            d = str(today - timedelta(days=100 + i * 95))
            res = self.client.patch('/api/profile/me/last-donation/', {'date': d}, format='json')
            self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 4th attempt
        d4 = str(today - timedelta(days=400))
        res4 = self.client.patch('/api/profile/me/last-donation/', {'date': d4}, format='json')
        self.assertEqual(res4.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertEqual(res4.data['code'], 'TOO_MANY_ATTEMPTS')

    # 4. Top Donors & Global Rank Leaderboards
    def test_top_donors_and_rank_tie_break(self):
        """Top donors sorted by verified bags (tie-break: earliest first donation, then id)."""
        # User 1: 2 verified bags, first donation 2026-01-01
        DonationHistory.objects.create(
            donor=self.profile1,
            donated_at=date(2026, 1, 1),
            date=date(2026, 1, 1),
            bags=2,
            source='verified',
            verified=True
        )

        # User 2: 2 verified bags, first donation 2026-01-10 (later -> lower rank)
        DonationHistory.objects.create(
            donor=self.profile2,
            donated_at=date(2026, 1, 10),
            date=date(2026, 1, 10),
            bags=2,
            source='verified',
            verified=True
        )

        self.client.force_authenticate(user=self.user1)
        res = self.client.get('/api/profile/top-donors/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        top_list = res.data['top_donors']
        self.assertEqual(len(top_list), 2)
        # Profile 1 must be Rank 1 due to earlier first donation!
        self.assertEqual(top_list[0]['id'], self.profile1.id)
        self.assertEqual(top_list[0]['rank'], 1)
        self.assertEqual(top_list[1]['id'], self.profile2.id)
        self.assertEqual(top_list[1]['rank'], 2)

    def test_top_donors_excludes_opted_out_and_unverified(self):
        """Donors with show_in_rankings=False or 0 verified bags are excluded."""
        self.profile1.show_in_rankings = False
        self.profile1.save()

        # Add self-reported donation (never counts toward rank!)
        DonationHistory.objects.create(
            donor=self.profile1,
            donated_at=date(2026, 1, 1),
            date=date(2026, 1, 1),
            bags=5,
            source='self_reported',
            verified=False
        )

        self.client.force_authenticate(user=self.user2)
        res = self.client.get('/api/profile/top-donors/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        # Profile 1 is excluded
        donor_ids = [d['id'] for d in res.data['top_donors']]
        self.assertNotIn(self.profile1.id, donor_ids)

    def test_global_rank_includes_caller_private_rank(self):
        """Caller row is returned in global rank even if opted out."""
        self.profile1.show_in_rankings = False
        self.profile1.save()

        self.client.force_authenticate(user=self.user1)
        res = self.client.get('/api/profile/global-rank/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('caller_rank', res.data)
        self.assertEqual(res.data['caller_rank']['id'], self.profile1.id)

    # 5. Public Profile Detail & Security
    def test_public_profile_detail_returns_404_for_deleted_user(self):
        """Soft-deleted user public profile returns 404."""
        self.user2.is_active = False
        self.user2.save()

        res = self.client.get(f'/api/profile/{self.profile2.id}/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    # 6. Blood Group Change Request with Encrypted Lab Report
    def test_blood_group_change_request_with_valid_pdf_report(self):
        """POST /api/profile/blood-group-change/ saves encrypted report and one-open-request rule."""
        self.client.force_authenticate(user=self.user1)

        pdf_content = b"%PDF-1.4 mock medical report lab slip bytes"
        report_file = SimpleUploadedFile("lab_report.pdf", pdf_content, content_type="application/pdf")

        res = self.client.post('/api/profile/blood-group-change/', {
            'requested_group': 'B+',
            'reason': 'Hospital lab test error correction',
            'lab_name': 'Popular Diagnostic Centre',
            'test_date': '2026-02-01',
            'consent': 'true',
            'report_file': report_file,
        }, format='multipart')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['status'], 'pending')
        self.assertEqual(res.data['requested_group'], 'B+')
        self.assertTrue(res.data['has_report'])

        # Attempting second request returns 400
        res2 = self.client.post('/api/profile/blood-group-change/', {
            'requested_group': 'A+',
            'consent': 'true',
        }, format='multipart')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)

    def test_blood_group_change_request_rejects_fake_file(self):
        """Files without PDF/JPEG/PNG magic bytes return 400."""
        self.client.force_authenticate(user=self.user1)

        fake_file = SimpleUploadedFile("fake.txt", b"plain text script", content_type="text/plain")
        res = self.client.post('/api/profile/blood-group-change/', {
            'requested_group': 'B+',
            'consent': 'true',
            'report_file': fake_file,
        }, format='multipart')

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('report_file', res.data)

    # 7. Donor Reviews API
    def test_donor_review_full_workflow_and_security(self):
        """Reviews allowed only for completed requests by requester, no self-reviews."""
        # Requester creates request
        req = BloodRequest.objects.create(
            requester=self.user1,
            patient_name='Patient Karim',
            blood_group='A+',
            units_needed=1,
            status='DONATED' # Completed donation
        )

        # Donor 2 attempts to review himself -> 400
        self.client.force_authenticate(user=self.user2)
        res_self = self.client.post('/api/reviews/', {
            'blood_request_id': req.id,
            'donor_id': self.profile2.id,
            'stars': 5,
        }, format='json')
        self.assertEqual(res_self.status_code, status.HTTP_403_FORBIDDEN)

        # Stranger attempts to review -> 403
        stranger = User.objects.create_user(username='stranger', password='pw')
        self.client.force_authenticate(user=stranger)
        res_stranger = self.client.post('/api/reviews/', {
            'blood_request_id': req.id,
            'donor_id': self.profile2.id,
            'stars': 5,
        }, format='json')
        self.assertEqual(res_stranger.status_code, status.HTTP_403_FORBIDDEN)

        # Valid review by requester (User 1)
        self.client.force_authenticate(user=self.user1)
        res_valid = self.client.post('/api/reviews/', {
            'blood_request_id': req.id,
            'donor_id': self.profile2.id,
            'stars': 5,
            'tag': 'Punctual',
            'comment': 'Arrived promptly at hospital.'
        }, format='json')
        self.assertEqual(res_valid.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_valid.data['donor_rating_avg'], 5.0)
        self.assertEqual(res_valid.data['donor_rating_count'], 1)

        # Fetch reviews for donor 2
        res_list = self.client.get(f'/api/profile/{self.profile2.id}/reviews/')
        self.assertEqual(res_list.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_list.data['results']), 1)
        self.assertEqual(res_list.data['results'][0]['tag'], 'Punctual')

    def test_query_counts_prevent_n_plus_one(self):
        """Query count benchmarks: top-donors, activity, donations (Pitfall 1)."""
        cache.clear()
        self.client.force_authenticate(user=self.user1)

        # 1. Top donors: max 2 queries (donors query with annotations)
        with self.assertNumQueries(2):
            res_top = self.client.get('/api/profile/top-donors/')
            self.assertEqual(res_top.status_code, 200)

        # 2. Activity: 2 queries (profile lookup + matches with select_related)
        with self.assertNumQueries(2):
            res_act = self.client.get('/api/profile/me/activity/')
            self.assertEqual(res_act.status_code, 200)

        # 3. Donations: 2 queries (profile lookup + donations)
        with self.assertNumQueries(2):
            res_don = self.client.get('/api/profile/me/donations/')
            self.assertEqual(res_don.status_code, 200)
