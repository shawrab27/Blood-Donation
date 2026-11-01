# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit tests for S-2a Authz Fixes:
1. Profile update IDOR protection (User A cannot modify User B's DonorProfile).
2. Emergency wave tick and maintenance tick fail-safe token authorization.
"""

import os
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from unittest.mock import patch

from api.models import DonorProfile


class S2aAuthzTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # User A
        self.user_a = User.objects.create_user(
            username='user_a', password='password123', email='user_a@example.com'
        )
        self.profile_a = DonorProfile.objects.create(
            user=self.user_a,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111101',
            is_profile_complete=True,
            bio='Original Bio A',
        )

        # User B
        self.user_b = User.objects.create_user(
            username='user_b', password='password123', email='user_b@example.com'
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.user_b,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801811111102',
            is_profile_complete=True,
            bio='Original Bio B',
        )

    def test_user_cannot_update_other_user_profile(self):
        """User A attempts to update User B's profile -> 403 Forbidden."""
        self.client.force_authenticate(user=self.user_a)
        resp = self.client.patch(
            f'/api/donors/{self.profile_b.id}/',
            {'bio': 'Hacked Bio'},
            format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.profile_b.refresh_from_db()
        self.assertEqual(self.profile_b.bio, 'Original Bio B')

    def test_user_can_update_own_profile(self):
        """User A updates own profile -> 200 OK."""
        self.client.force_authenticate(user=self.user_a)
        resp = self.client.patch(
            f'/api/donors/{self.profile_a.id}/',
            {'bio': 'Updated Bio A'},
            format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.profile_a.refresh_from_db()
        self.assertEqual(self.profile_a.bio, 'Updated Bio A')

    def test_tick_endpoints_reject_when_no_token_configured_or_passed(self):
        """Tick endpoints return 403 when Authorization header or token is invalid/missing."""
        with patch.dict(os.environ, {'EMERGENCY_TICK_TOKEN': ''}, clear=False):
            resp1 = self.client.post('/api/emergency/tick/')
            self.assertEqual(resp1.status_code, status.HTTP_403_FORBIDDEN)

            resp2 = self.client.post('/api/emergency/maintenance-tick/')
            self.assertEqual(resp2.status_code, status.HTTP_403_FORBIDDEN)

    def test_tick_endpoints_accept_with_valid_bearer_token(self):
        """Tick endpoints succeed when correct Bearer token is provided."""
        valid_token = 'secret-test-token-xyz'
        with patch.dict(os.environ, {'EMERGENCY_TICK_TOKEN': valid_token}, clear=False):
            with patch('api.views_bloodhub.process_wave_tick', return_value={'status': 'ok'}):
                resp = self.client.post(
                    '/api/emergency/tick/',
                    HTTP_AUTHORIZATION=f'Bearer {valid_token}'
                )
                self.assertEqual(resp.status_code, status.HTTP_200_OK)
