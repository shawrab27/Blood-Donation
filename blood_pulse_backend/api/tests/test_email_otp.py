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

    def test_deprecated_auth_otp_endpoints_return_410(self):
        res_send = self.client.post('/api/auth/otp/send/', {'email': 'donor@example.com'})
        self.assertEqual(res_send.status_code, status.HTTP_410_GONE)

        res_verify = self.client.post('/api/auth/otp/verify/', {'email': 'donor@example.com', 'code': '123456'})
        self.assertEqual(res_verify.status_code, status.HTTP_410_GONE)
