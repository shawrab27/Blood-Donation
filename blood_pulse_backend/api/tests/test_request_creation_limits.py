# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from unittest.mock import patch
from django.core.cache import cache
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from rest_framework import status
from rest_framework.test import APIClient, APIRequestFactory

from api.models import DonorProfile
from api.throttles import RequestCreateUserThrottle, RequestCreateIpThrottle


class RequestCreationLimitsTests(TestCase):
    """
    Tests H-1 Item 2: Request creation limits:
    - Default 5/hour per user
    - Default 10/hour per IP
    - Both overridable by environment variables
    - Returns 429 with clear message and retry_after, never a silent drop
    """

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.factory = APIRequestFactory()
        self.user = User.objects.create_user(
            username='01711112233',
            email='requester@example.com',
            password='Password123!',
            first_name='Requester'
        )
        DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            district='Dhaka',
            phone_number='01711112233',
            is_available=True,
            is_profile_complete=True
        )

    def tearDown(self):
        cache.clear()

    def test_default_user_throttle_rate_is_5_per_hour(self):
        throttle = RequestCreateUserThrottle()
        self.assertEqual(throttle.get_rate(), '5/hour')

    def test_default_ip_throttle_rate_is_10_per_hour(self):
        throttle = RequestCreateIpThrottle()
        self.assertEqual(throttle.get_rate(), '10/hour')

    def test_user_rate_overridable_by_env(self):
        with patch.dict(os.environ, {'REQUEST_CREATE_USER_RATE': '2/hour'}):
            throttle = RequestCreateUserThrottle()
            self.assertEqual(throttle.get_rate(), '2/hour')

    def test_ip_rate_overridable_by_env(self):
        with patch.dict(os.environ, {'REQUEST_CREATE_IP_RATE': '20/hour'}):
            throttle = RequestCreateIpThrottle()
            self.assertEqual(throttle.get_rate(), '20/hour')

    def test_user_creation_limit_returns_429_with_message_on_excess(self):
        """User exceeds limit -> 429 Too Many Requests with retry_after and message."""
        throttle = RequestCreateUserThrottle()

        class DummyView:
            pass

        dummy_request = self.factory.post('/api/requests/')
        dummy_request.user = self.user

        for _ in range(5):
            self.assertTrue(throttle.allow_request(dummy_request, DummyView()))

        # 6th request fails with False
        self.assertFalse(throttle.allow_request(dummy_request, DummyView()))

        # Calling via custom exception handler directly produces 429
        from rest_framework.exceptions import Throttled
        from api.throttles import custom_exception_handler
        exc = Throttled(wait=throttle.wait())
        resp = custom_exception_handler(exc, {'request': dummy_request})
        self.assertEqual(resp.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn('retry_after', resp.data)
        self.assertIn('Too many requests', resp.data['message_en'])
        self.assertIn('Retry-After', resp.headers)

    def test_ip_creation_limit_throttles_excess_from_same_ip(self):
        """IP limit triggers 429 after 10 requests from same IP."""
        throttle = RequestCreateIpThrottle()

        class DummyView:
            pass

        dummy_request = self.factory.post('/api/requests/', REMOTE_ADDR='198.51.100.42')
        dummy_request.user = self.user

        for _ in range(10):
            self.assertTrue(throttle.allow_request(dummy_request, DummyView()))

        # 11th request fails with False
        self.assertFalse(throttle.allow_request(dummy_request, DummyView()))
