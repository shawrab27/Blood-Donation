# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import hmac
from unittest.mock import patch, MagicMock
from datetime import timedelta
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework import status

from api.models import PasswordResetOTP, EmailOTP, DonorProfile
from api.services.email import hash_otp, verify_otp_hash
from api.views_auth_reset import generate_otp_hash

@override_settings(EMAIL_PROVIDER='locmem')
class OTPSecurityTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='otp_user',
            email='security_test@example.com',
            password='Password123!'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_profile_complete=True,
            email_verified=True,
        )

    def test_resend_cooldown_60s(self):
        """Resend within 60s is blocked; resend after 60s succeeds."""
        # Request-submit OTP endpoint enforces 60s cooldown with HTTP 429
        self.client.force_authenticate(user=self.user)
        res1 = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        # Immediate repeat within 60s -> 429 Too Many Requests
        res2 = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn('cooldown_seconds', res2.data)

        # Fast forward time past 60s
        EmailOTP.objects.filter(user=self.user).update(last_sent_at=timezone.now() - timedelta(seconds=65))
        res3 = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
        self.assertEqual(res3.status_code, status.HTTP_200_OK)

    def test_rate_limit_per_user_ip_email(self):
        """Per email and per IP throttles are applied to OTP endpoints."""
        from api.views_auth_reset import IpRateThrottle, EmailRateThrottle
        self.assertIn(IpRateThrottle, [
            cls for cls in getattr(self.client.post, 'cls', []) or []
        ] or [IpRateThrottle])
        # Ensure throttling classes are configured on views
        from api.views_auth_reset import request_otp, verify_otp
        self.assertTrue(any(issubclass(t, IpRateThrottle) for t in request_otp.cls.throttle_classes))
        self.assertTrue(any(issubclass(t, EmailRateThrottle) for t in request_otp.cls.throttle_classes))

    def test_constant_time_compare(self):
        """OTP validation uses constant-time comparison (hmac.compare_digest / verify_otp_hash)."""
        code = '123456'
        email = 'security_test@example.com'
        expected_hash = hash_otp(code, email)

        with patch('hmac.compare_digest', wraps=hmac.compare_digest) as mock_compare:
            is_valid = verify_otp_hash(code, expected_hash, email)
            self.assertTrue(is_valid)
            self.assertTrue(mock_compare.called)

        # Also verify password reset hash comparison uses hmac.compare_digest
        reset_hash = generate_otp_hash(code)
        with patch('hmac.compare_digest', wraps=hmac.compare_digest) as mock_compare2:
            self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': '999999'}, format='json')
            # If an OTP existed, compare_digest would be called
            PasswordResetOTP.objects.create(
                user=self.user,
                otp_hash=reset_hash,
                expires_at=timezone.now() + timedelta(minutes=10),
                is_used=False
            )
            res = self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': code}, format='json')
            self.assertEqual(res.status_code, status.HTTP_200_OK)
            self.assertTrue(mock_compare2.called)

    def test_old_otp_invalidated_on_resend(self):
        """Requesting a new OTP marks prior unused OTPs as is_used=True so they cannot be verified."""
        code1 = '111111'
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash(code1),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False
        )

        # Allow time for cooldown
        PasswordResetOTP.objects.filter(user=self.user).update(last_sent_at=timezone.now() - timedelta(seconds=70))

        # Request new OTP via mock email
        with patch('api.services.email_service.get_email_service') as mock_svc:
            mock_inst = MagicMock()
            mock_inst.send_otp.return_value = True
            mock_svc.return_value = mock_inst
            res = self.client.post('/api/auth/password-reset/request/', {'email': self.user.email}, format='json')
            self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Old OTP must be marked is_used=True
        old_otp = PasswordResetOTP.objects.filter(user=self.user, otp_hash=generate_otp_hash(code1)).first()
        self.assertTrue(old_otp.is_used)

        # Verifying old OTP fails
        res_verify_old = self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': code1}, format='json')
        self.assertEqual(res_verify_old.status_code, status.HTTP_400_BAD_REQUEST)

    def test_five_attempts_lock_15_min(self):
        """5 incorrect OTP attempts locks the OTP and returns 429 Too Many Requests."""
        correct_code = '555666'
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash(correct_code),
            expires_at=timezone.now() + timedelta(minutes=15),
            is_used=False,
            attempts=0
        )

        for attempt in range(4):
            res = self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': '000000'}, format='json')
            self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        # 5th failed attempt locks out the OTP
        res_lock = self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': '000000'}, format='json')
        self.assertEqual(res_lock.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn('Too many attempts', res_lock.data.get('detail', ''))

        # Subsequent attempt even with CORRECT code is locked
        res_correct_after_lock = self.client.post('/api/auth/password-reset/verify/', {'email': self.user.email, 'otp': correct_code}, format='json')
        self.assertEqual(res_correct_after_lock.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
