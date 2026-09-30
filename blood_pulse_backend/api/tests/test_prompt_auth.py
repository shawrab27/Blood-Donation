# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from api.models import DonorProfile, BloodRequest, EmailOTP
from django.utils import timezone
from datetime import timedelta
from api.services.email import hash_otp

class AuthIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='+8801700000001', password='correct_password', first_name="Test")
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='+8801700000001',
            blood_group='O+'
        )

    def test_registration_duplicate_phone(self):
        # 1. Registration with duplicate phone number (expect 400)
        data = {
            'phone_number': '+8801700000001',
            'blood_group': 'A+',
            'password': 'newpassword',
            'full_name': 'Test User'
        }
        res = self.client.post('/api/donors/', data)
        self.assertEqual(res.status_code, 400, "Expected 400 for duplicate phone registration")

    def test_login_wrong_password(self):
        # 2. Login with wrong password (expect 401)
        res = self.client.post('/api/token/', {
            'username': '+8801700000001',
            'password': 'wrong_password'
        })
        self.assertEqual(res.status_code, 401, "Expected 401 for wrong password")

    def test_blood_group_locked(self):
        # 4. Blood-group-locked field (attempt to edit blood_group as non-admin, expect rejected/ignored)
        self.client.force_authenticate(user=self.user)
        res = self.client.patch(f'/api/donors/{self.profile.id}/', {'blood_group': 'AB-'})
        self.assertEqual(res.status_code, 400, "Expected 400 when attempting to update blood group")

    def test_jit_otp_for_bloodhub_accept(self):
        # 3. JIT OTP request/verify for Blood Hub submission 
        # (expect OTP required before accept, expired OTP rejected)
        req = BloodRequest.objects.create(
            patient_name='Patient',
            blood_group='O+',
            units_needed=1,
            contact_number='123456',
            lat=0, lng=0
        )
        self.client.force_authenticate(user=self.user)
        
        # Expect OTP required before accept (e.g. returns 403 or 400 needing OTP)
        res = self.client.post(f'/api/emergency/requests/{req.id}/accept/', {})
        self.assertEqual(res.status_code, 403, "Expected 403 OTP Required before accept")

        # Expired OTP rejected
        # (Assuming the API takes an OTP code in the payload)
        expired_otp = EmailOTP.objects.create(
            email='test@example.com',
            otp_hash=hash_otp('123456', 'test@example.com'),
            expires_at=timezone.now() - timedelta(minutes=5)
        )
        res2 = self.client.post(f'/api/emergency/requests/{req.id}/accept/', {'otp': '123456'})
        self.assertEqual(res2.status_code, 403, "Expected 403 for expired OTP")
