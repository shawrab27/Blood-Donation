# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from api.models import DonorProfile


class PublicProfileSecurityTests(TestCase):
    """
    Test suite for Gap #13 Security Hotfix:
    Validates that public donor profile endpoints strictly return PublicDonorProfileSerializer
    and NEVER leak sensitive PII, phone numbers, NID hashes, exact/fuzzed coordinates,
    weight, email, address, or FCM tokens to other users or anonymous visitors.
    """

    def setUp(self):
        self.client = APIClient()

        # Target donor user
        self.donor_user = User.objects.create_user(
            username='donor_target',
            email='target_donor@bloodpulse.org',
            password='Password123!',
            first_name='Rahim',
            last_name='Chowdhury'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801712345678',
            nid_hash='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            bio='Lifelong voluntary blood donor in Dhaka.',
            total_bags_donated=6,
            rating_avg=4.95,
            rating_count=12,
            latitude=23.8103,
            longitude=90.4125,
            public_lat=23.8155,
            public_lng=90.4175,
            weight_kg=68,
            address='123 Mirpur Road, Dhaka',
            fcm_token='mock_fcm_token_private',
            is_available=True,
            is_searchable=True,
        )

        # Another normal user (non-owner, non-staff)
        self.other_user = User.objects.create_user(
            username='other_visitor',
            email='visitor@bloodpulse.org',
            password='Password123!',
            first_name='Karim',
            last_name='Khan'
        )

    def test_anonymous_user_cannot_see_sensitive_fields(self):
        """Anonymous callers querying public profile must NEVER receive sensitive PII."""
        # Unauthenticated client
        self.client.force_authenticate(user=None)

        for endpoint in [f'/api/donors/{self.donor_profile.id}/', f'/api/profile/{self.donor_profile.id}/']:
            resp = self.client.get(endpoint)
            self.assertEqual(resp.status_code, status.HTTP_200_OK, f"Failed at endpoint {endpoint}")
            data = resp.data

            # 1. Verify required public fields ARE present
            self.assertEqual(data['id'], self.donor_profile.id)
            self.assertEqual(data['name'], 'Rahim Chowdhury')
            self.assertEqual(data['bio'], 'Lifelong voluntary blood donor in Dhaka.')
            self.assertEqual(data['blood_group'], 'O+')
            self.assertEqual(data['tier'], 'Platinum Donor')
            self.assertEqual(data['bags'], 6)
            self.assertEqual(data['rating_avg'], 4.95)
            self.assertEqual(data['rating_count'], 12)

            # 2. Verify all sensitive fields are strictly ABSENT
            self.assertNotIn('phone_number', data)
            self.assertNotIn('nid_hash', data)
            self.assertNotIn('latitude', data)
            self.assertNotIn('longitude', data)
            self.assertNotIn('lat', data)
            self.assertNotIn('lng', data)
            self.assertNotIn('public_lat', data)
            self.assertNotIn('public_lng', data)
            self.assertNotIn('weight', data)
            self.assertNotIn('weight_kg', data)
            self.assertNotIn('email', data)
            self.assertNotIn('address', data)
            self.assertNotIn('fcm_token', data)
            self.assertNotIn('password', data)

    def test_other_authenticated_user_cannot_see_sensitive_fields(self):
        """Non-owner authenticated users querying public profile must NEVER receive sensitive PII."""
        self.client.force_authenticate(user=self.other_user)

        for endpoint in [f'/api/donors/{self.donor_profile.id}/', f'/api/profile/{self.donor_profile.id}/']:
            resp = self.client.get(endpoint)
            self.assertEqual(resp.status_code, status.HTTP_200_OK, f"Failed at endpoint {endpoint}")
            data = resp.data

            # Allowed public fields
            self.assertEqual(data['id'], self.donor_profile.id)
            self.assertEqual(data['name'], 'Rahim Chowdhury')
            self.assertEqual(data['blood_group'], 'O+')

            # Strictly stripped sensitive fields
            self.assertNotIn('phone_number', data)
            self.assertNotIn('nid_hash', data)
            self.assertNotIn('latitude', data)
            self.assertNotIn('longitude', data)
            self.assertNotIn('public_lat', data)
            self.assertNotIn('public_lng', data)
            self.assertNotIn('weight_kg', data)
            self.assertNotIn('email', data)
            self.assertNotIn('address', data)
            self.assertNotIn('fcm_token', data)

    def test_owner_can_see_own_private_fields(self):
        """Profile owner viewing their profile CAN access their own private fields."""
        self.client.force_authenticate(user=self.donor_user)

        # Owner accesses via /api/profile/me/
        resp = self.client.get('/api/profile/me/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.data

        self.assertIn('phone_number', data)
        self.assertEqual(data['phone_number'], '+8801712345678')
        self.assertIn('email', data)
        self.assertEqual(data['email'], 'target_donor@bloodpulse.org')
        self.assertIn('address', data)
        self.assertEqual(data['weight_kg'], 68)
