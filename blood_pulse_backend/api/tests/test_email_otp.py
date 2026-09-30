# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from api.models import EmailOTP, DonorProfile
from api.services.email import (
    hash_otp,
    verify_otp_hash,
    generate_secure_otp,
    OTP_EXPIRY_MINUTES,
)


class EmailOTPServiceAndEndpointTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='otpuser', email='donor@example.com', password='password123', first_name="Test")
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000099',
            email_verified=False,
        )

    def test_hash_and_verify_otp(self):
        code = "729401"
        email = "test@bloodpulse.org"
        code_hash = hash_otp(code, email)
        
        # Verify valid code matches
        self.assertTrue(verify_otp_hash(code, code_hash, email))
        
        # Verify wrong code fails
        self.assertFalse(verify_otp_hash("123456", code_hash, email))
        
        # Verify wrong email fails (tamper protection)
        self.assertFalse(verify_otp_hash(code, code_hash, "other@bloodpulse.org"))

    def test_send_otp_success_and_stored_hash_only(self):
        response = self.client.post('/api/auth/otp/send/', {'email': 'donor@example.com'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['email'], 'donor@example.com')

        # Verify DB has record and plain text code is NOT stored
        record = EmailOTP.objects.filter(email='donor@example.com').first()
        self.assertIsNotNone(record)
        self.assertEqual(len(record.otp_hash), 64) # SHA256 hex string
        self.assertFalse(record.is_used)

    def test_send_otp_cooldown_rate_limit(self):
        # First send
        resp1 = self.client.post('/api/auth/otp/send/', {'email': 'cooldown@example.com'})
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)

        # Immediate second send should be blocked (429)
        resp2 = self.client.post('/api/auth/otp/send/', {'email': 'cooldown@example.com'})
        self.assertEqual(resp2.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn('cooldown_seconds', resp2.json())

    def test_verify_otp_successful_and_marks_profile_verified(self):
        email = 'donor@example.com'
        code = '654321'
        code_hash = hash_otp(code, email)
        
        EmailOTP.objects.create(
            email=email,
            otp_hash=code_hash,
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        self.client.force_authenticate(user=self.user)
        resp = self.client.post('/api/auth/otp/verify/', {'email': email, 'code': code})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.json()['email_verified'])

        self.donor.refresh_from_db()
        self.assertTrue(self.donor.email_verified)

    def test_verify_otp_incorrect_decrements_attempts_and_locks(self):
        email = 'locked@example.com'
        code = '112233'
        otp = EmailOTP.objects.create(
            email=email,
            otp_hash=hash_otp(code, email),
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        # 4 wrong attempts
        for i in range(4):
            resp = self.client.post('/api/auth/otp/verify/', {'email': email, 'code': '999999'})
            self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

        otp.refresh_from_db()
        self.assertEqual(otp.attempts, 4)

        # 5th wrong attempt triggers lock
        resp5 = self.client.post('/api/auth/otp/verify/', {'email': email, 'code': '999999'})
        self.assertEqual(resp5.status_code, status.HTTP_400_BAD_REQUEST)
        
        otp.refresh_from_db()
        self.assertTrue(otp.is_locked())

        # Next attempt returns 429 Locked
        resp_locked = self.client.post('/api/auth/otp/verify/', {'email': email, 'code': code})
        self.assertEqual(resp_locked.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
