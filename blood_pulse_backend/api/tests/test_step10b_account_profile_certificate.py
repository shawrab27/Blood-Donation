# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date, timedelta
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from api.models import (
    DonorProfile, BloodRequest, SocialPost, AuditLog, Certificate
)


class Step10BBackendTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='donor_test',
            email='donor_test@bloodpulse.org',
            password='Password123!',
            first_name='Rahim',
            last_name='Uddin'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000001',
            total_bags_donated=2,
            last_donation_date=date.today() - timedelta(days=40),
            public_profile=False,
            fcm_token='mock_fcm_token_123'
        )
        refresh = RefreshToken.for_user(self.user)
        self.access_token = str(refresh.access_token)
        self.refresh_token = str(refresh)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.access_token}')

    # --- B4: Logout ---
    def test_logout_blacklists_refresh_token_and_unregisters_push_token(self):
        resp = self.client.post('/api/auth/logout/', {'refresh': self.refresh_token})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        # Profile FCM token cleared
        self.profile.refresh_from_db()
        self.assertIsNone(self.profile.fcm_token)

        # Subsequent refresh with blacklisted token MUST fail
        refresh_resp = self.client.post('/api/token/refresh/', {'refresh': self.refresh_token})
        self.assertEqual(refresh_resp.status_code, status.HTTP_401_UNAUTHORIZED)

    # --- B5: Account Lifecycle (Summary & Store-Compliant Deletion) ---
    def test_account_summary_returns_real_counts(self):
        BloodRequest.objects.create(
            requester=self.user,
            patient_name='Patient A',
            blood_group='O+',
            hospital_location='Dhaka Medical'
        )
        SocialPost.objects.create(
            author=self.profile,
            text_content='Urgent blood needed'
        )

        resp = self.client.get('/api/account/summary/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['donations_count'], 2)
        self.assertEqual(resp.data['requests_count'], 1)
        self.assertEqual(resp.data['posts_count'], 1)

    def test_delete_account_anonymizes_requests_scrubs_pii_and_blocks_login(self):
        req = BloodRequest.objects.create(
            requester=self.user,
            patient_name='Patient B',
            attendant_name='Brother Rahim',
            contact_number='+8801700000001',
            blood_group='O+',
            hospital_location='Dhaka Medical'
        )
        post = SocialPost.objects.create(
            author=self.profile,
            text_content='My donation post'
        )

        # Deletion requires re-auth password
        resp = self.client.delete('/api/account/', {'password': 'Password123!'})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        # 1. Post is deleted
        self.assertFalse(SocialPost.objects.filter(id=post.id).exists())

        # 2. Blood request is anonymized, NOT destroyed (so other users' history is intact)
        req.refresh_from_db()
        self.assertIsNone(req.requester)
        self.assertEqual(req.attendant_name, 'Deleted user')
        self.assertEqual(req.contact_number, '')

        # 3. User account is deactivated and cannot log in
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_active)
        self.assertFalse(self.user.check_password('Password123!'))

        # 4. PII is scrubbed from profile
        self.profile.refresh_from_db()
        self.assertIsNone(self.profile.fcm_token)
        self.assertFalse(self.profile.is_searchable)
        self.assertIn('+8800000', self.profile.phone_number)

        # 5. Audit log created without PII
        audit = AuditLog.objects.filter(action='ACCOUNT_DELETION').last()
        self.assertIsNotNone(audit)
        self.assertIsNone(audit.user)

    # --- B6: Profile Fixes (Cooldown, Rank, Consent) ---
    def test_cooldown_computation_and_future_date_rejection(self):
        # Null donation date -> eligible now (0 days remaining)
        self.profile.last_donation_date = None
        self.profile.save()
        self.assertEqual(self.profile.days_until_eligible, 0)

        # 30 days ago -> 60 days remaining
        self.profile.last_donation_date = date.today() - timedelta(days=30)
        self.profile.save()
        self.assertEqual(self.profile.days_until_eligible, 60)

        # 90 days ago -> 0 days remaining (eligible now)
        self.profile.last_donation_date = date.today() - timedelta(days=90)
        self.profile.save()
        self.assertEqual(self.profile.days_until_eligible, 0)

        # Future date rejected in serializer
        patch_resp = self.client.patch('/api/profile/me/', {
            'last_donation_date': (date.today() + timedelta(days=5)).isoformat()
        })
        self.assertEqual(patch_resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('future', str(patch_resp.data))

    def test_real_leaderboard_respects_privacy_consent(self):
        # Default: public_profile=False -> Anonymous Hero
        resp = self.client.get('/api/leaderboard/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        top = resp.data['top_donors']
        self.assertTrue(len(top) >= 1)
        self.assertEqual(top[0]['name'], 'Anonymous Hero')

        # When public_profile=True -> FirstName L.
        self.profile.public_profile = True
        self.profile.save()
        # Invalidate cache
        from django.core.cache import cache
        cache.clear()

        resp2 = self.client.get('/api/leaderboard/')
        top2 = resp2.data['top_donors']
        self.assertEqual(top2[0]['name'], 'Rahim U.')

    def test_unranked_for_zero_donations(self):
        zero_user = User.objects.create_user(username='zero_donor', password='Password123!')
        zero_profile = DonorProfile.objects.create(
            user=zero_user,
            blood_group='A+',
            district='Chittagong',
            phone_number='+8801700000009',
            total_bags_donated=0
        )
        self.assertIsNone(zero_profile.global_rank)

        client2 = APIClient()
        token = str(RefreshToken.for_user(zero_user).access_token)
        client2.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        resp = client2.get('/api/leaderboard/')
        self.assertEqual(resp.data['my_rank'], 'Unranked')

    # --- B7: Verified Donation Certificate ---
    def test_certificate_generation_and_public_verification(self):
        # User has 2 donations -> eligible
        resp = self.client.post('/api/certificates/')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        cert_id = resp.data['id']
        self.assertEqual(resp.data['donation_count_snapshot'], 2)
        self.assertEqual(resp.data['donor_name'], 'Rahim Uddin')

        # Public verification endpoint (AllowAny, no PII)
        anon_client = APIClient()
        verify_resp = anon_client.get(f'/verify/{cert_id}/')
        self.assertEqual(verify_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(verify_resp.data['valid'])
        self.assertEqual(verify_resp.data['donor_initials'], 'R. U.')
        self.assertEqual(verify_resp.data['donations_count'], 2)
        # Ensure no phone or email in public payload
        self.assertNotIn('phone', verify_resp.data)
        self.assertNotIn('email', verify_resp.data)

    def test_certificate_ineligible_for_zero_donations(self):
        zero_user = User.objects.create_user(username='newbie', password='Password123!')
        DonorProfile.objects.create(
            user=zero_user,
            blood_group='B+',
            district='Sylhet',
            phone_number='+8801700000099',
            total_bags_donated=0
        )
        client = APIClient()
        token = str(RefreshToken.for_user(zero_user).access_token)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        resp = client.post('/api/certificates/')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(resp.data['eligible'])
