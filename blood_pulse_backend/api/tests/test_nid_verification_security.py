# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase, RequestFactory
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework import status
from api.models import DonorProfile
from api.admin import DonorProfileAdmin

User = get_user_model()


class NIDVerificationSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user_a = User.objects.create_user(username='user_a', password='password123')
        self.user_b = User.objects.create_user(username='user_b', password='password123')
        self.staff_user = User.objects.create_superuser(username='admin_staff', password='password123', email='admin@example.com')

        self.profile_a = DonorProfile.objects.create(
            user=self.user_a,
            phone_number='01711111111',
            blood_group='A+',
            is_verified=False,
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.user_b,
            phone_number='01722222222',
            blood_group='B+',
            is_verified=False,
        )

        self.dummy_nid = SimpleUploadedFile(
            "nid_card.jpg",
            b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB",
            content_type="image/jpeg",
        )

    def test_anonymous_request_rejected_with_401(self):
        """Item 1: Anonymous requests must return HTTP 401 Unauthorized."""
        response = self.client.post(
            '/api/verify-nid/',
            {'image': self.dummy_nid},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.profile_a.refresh_from_db()
        self.assertFalse(self.profile_a.is_verified)

    def test_user_a_cannot_affect_user_b_idor_defense(self):
        """Item 1: Supplying a foreign user_id in the payload cannot affect another user's profile."""
        self.client.force_authenticate(user=self.user_a)

        response = self.client.post(
            '/api/verify-nid/',
            {
                'image': self.dummy_nid,
                'user_id': self.user_b.id,  # Malicious attempt to affect User B
            },
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.profile_b.refresh_from_db()
        # User B's profile must remain completely untouched
        self.assertFalse(self.profile_b.is_verified)

        self.profile_a.refresh_from_db()
        # User A's profile is also not verified (pending admin review)
        self.assertFalse(self.profile_a.is_verified)

    def test_self_verify_not_possible_submission_is_pending_only(self):
        """Item 1: A user submitting NID receives pending status and cannot self-verify."""
        self.client.force_authenticate(user=self.user_a)

        response = self.client.post(
            '/api/verify-nid/',
            {'image': self.dummy_nid},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data.get('status'), 'pending')
        self.assertFalse(data.get('is_verified'))

        self.profile_a.refresh_from_db()
        self.assertFalse(self.profile_a.is_verified)

    def test_staff_can_approve_verification_via_admin_action(self):
        """Item 1: Verification can only be approved by staff/admin through the admin action."""
        self.client.force_login(self.staff_user)
        response = self.client.post('/admin/api/donorprofile/', {
            'action': 'approve_verification',
            '_selected_action': [self.profile_a.pk],
        })
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)

        self.profile_a.refresh_from_db()
        self.assertTrue(self.profile_a.is_verified)
