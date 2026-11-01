# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Attack and verification tests for s2c authz:
1. journey_issue_report_view: caller must be participant (donor or requester), else 404.
2. SocialPostViewSet and BloodRequestViewSet: update/destroy must be owner or staff only.
3. BloodRequest public read: verify serialization and privacy masking (no PII, fuzzed coords).
4. Tick endpoints: fail-closed auth with hmac.compare_digest.
"""

import os
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from unittest.mock import patch

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    SocialPost,
)


class S2cAuthz2AttackTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # User A (Owner / Requester)
        self.user_a = User.objects.create_user(
            username='user_a', password='password123', email='a@example.com'
        )
        self.profile_a = DonorProfile.objects.create(
            user=self.user_a,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111101',
            is_profile_complete=True,
            email_verified=True,
        )

        # User B (Attacker / Different User)
        self.user_b = User.objects.create_user(
            username='user_b', password='password123', email='b@example.com'
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.user_b,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801811111102',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor for Journey
        self.donor_user = User.objects.create_user(
            username='donor_user', password='password123', email='donor@example.com'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801722222201',
            is_profile_complete=True,
            email_verified=True,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

        # Blood Request owned by User A
        self.blood_req = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient Rahim Khan',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            lat=23.7259,
            lng=90.3976,
            status='ACTIVE',
        )

        # Journey Acceptance (User A is requester, Donor is donor)
        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            is_standby=False,
        )

        # Social Post owned by User A
        self.post = SocialPost.objects.create(
            author=self.profile_a,
            text_content='Original Post by User A',
        )

    def test_1_attack_unrelated_user_cannot_report_journey_issue(self):
        """Item 1 Attack: Attacker User B tries to report medical rejection on User A's journey."""
        self.client.force_authenticate(user=self.user_b)
        resp = self.client.post(
            f'/api/journeys/{self.acceptance.id}/issue/',
            {'issue_type': 'MEDICAL_REJECTION', 'description': 'Malicious report'},
            format='json'
        )
        # Must return 404 for non-participants (no confirmation of journey existence)
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_2_attack_unrelated_user_cannot_patch_or_delete_social_post(self):
        """Item 2 Attack: Attacker User B tries to PATCH and DELETE User A's SocialPost."""
        self.client.force_authenticate(user=self.user_b)

        # Try PATCH
        patch_resp = self.client.patch(
            f'/api/posts/{self.post.id}/',
            {'text_content': 'Hacked Post Content'},
            format='json'
        )
        self.assertEqual(patch_resp.status_code, status.HTTP_403_FORBIDDEN)
        self.post.refresh_from_db()
        self.assertEqual(self.post.text_content, 'Original Post by User A')

        # Try DELETE
        del_resp = self.client.delete(f'/api/posts/{self.post.id}/')
        self.assertEqual(del_resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(SocialPost.objects.filter(id=self.post.id).exists())

    def test_2_attack_unrelated_user_cannot_patch_or_delete_blood_request(self):
        """Item 2 Attack: Attacker User B tries to PATCH and DELETE User A's BloodRequest."""
        self.client.force_authenticate(user=self.user_b)

        # Try PATCH
        patch_resp = self.client.patch(
            f'/api/requests/{self.blood_req.id}/',
            {'patient_name': 'Hacked Patient'},
            format='json'
        )
        self.assertEqual(patch_resp.status_code, status.HTTP_403_FORBIDDEN)

        # Try DELETE
        del_resp = self.client.delete(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(del_resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(BloodRequest.objects.filter(id=self.blood_req.id).exists())

    def test_3_blood_request_public_read_fields(self):
        """Item 3: Show fields received by anonymous and unrelated user. Confirm PII and exact GPS masked."""
        # Unrelated authenticated user reading emergency request detail
        self.client.force_authenticate(user=self.user_b)
        resp_auth = self.client.get(f'/api/emergency/requests/{self.blood_req.id}/')
        self.assertEqual(resp_auth.status_code, status.HTTP_200_OK)
        data_auth = resp_auth.json()

        # Confirm contact phone is masked
        phone_display = data_auth.get('contact_phone_display') or data_auth.get('contact_phone_masked', '')
        self.assertNotEqual(phone_display, '+8801811111101')

        # Confirm patient name is masked (not full raw name)
        patient_name = data_auth.get('patient_name', '')
        self.assertNotEqual(patient_name, 'Patient Rahim Khan')

        # Confirm exact lat/lng are not identical to raw DB coords (fuzzed)
        if data_auth.get('lat') is not None:
            self.assertNotEqual((data_auth['lat'], data_auth['lng']), (23.7259, 90.3976))

    def test_4_tick_endpoints_auth(self):
        """Item 4: Tick endpoints auth: unset token=reject, wrong token=403, correct token=200."""
        # 1. Unset token
        with patch.dict(os.environ, {'EMERGENCY_TICK_TOKEN': ''}, clear=False):
            resp = self.client.post('/api/emergency/tick/')
            self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Wrong token
        with patch.dict(os.environ, {'EMERGENCY_TICK_TOKEN': 'secret-correct-token'}, clear=False):
            resp = self.client.post(
                '/api/emergency/tick/',
                HTTP_AUTHORIZATION='Bearer wrong-token-123'
            )
            self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Correct token
        with patch.dict(os.environ, {'EMERGENCY_TICK_TOKEN': 'secret-correct-token'}, clear=False):
            with patch('api.views_bloodhub.process_wave_tick', return_value={'status': 'ok'}):
                resp = self.client.post(
                    '/api/emergency/tick/',
                    HTTP_AUTHORIZATION='Bearer secret-correct-token'
                )
                self.assertEqual(resp.status_code, status.HTTP_200_OK)
