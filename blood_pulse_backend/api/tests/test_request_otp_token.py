# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import json
from datetime import timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.core import mail
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile, Hospital, BloodRequest, EmailOTP, RequestSubmitToken
from api.services.email import hash_otp


from django.core.cache import cache

class RequestOTPAndSubmitTokenTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='requester_user',
            email='requester@example.com',
            password='Password123!',
            first_name='Requester'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711111111',
            is_profile_complete=True,
            email_verified=True,
            user_intent='DONATE_AND_REQUEST',
        )
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            address='Secretariat Road, Dhaka',
        )

    def test_request_otp_send_real_flow(self):
        """POST /api/requests/otp/send/ dispatches code and records outbox email."""
        self.client.force_authenticate(user=self.user)
        mail.outbox.clear()

        res = self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['status'], 'otp_sent')
        self.assertEqual(res.data['cooldown_seconds'], 60)

        # Verified in memory email outbox
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("verification code", mail.outbox[0].subject)

        # Verify EmailOTP record in DB
        otp_rec = EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit', is_used=False).first()
        self.assertIsNotNone(otp_rec)
        self.assertEqual(len(otp_rec.otp_hash), 64)

    def test_request_otp_send_cooldown_enforced(self):
        """Consecutive OTP send within 60 seconds returns 429."""
        self.client.force_authenticate(user=self.user)
        res1 = self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)

        res2 = self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn('cooldown_seconds', res2.data)

    def test_request_otp_verify_and_token_issuance(self):
        """POST /api/requests/otp/verify/ returns a 15-minute submit token."""
        self.client.force_authenticate(user=self.user)
        mail.outbox.clear()

        # Send OTP
        self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        otp_rec = EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit', is_used=False).first()

        # Overwrite hash with known test code for deterministic assertion
        test_code = '849201'
        otp_rec.otp_hash = hash_otp(test_code, otp_rec.email)
        otp_rec.save()

        # Verify with wrong code
        res_bad = self.client.post('/api/requests/otp/verify/', {'code': '000000'}, format='json')
        self.assertEqual(res_bad.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res_bad.data['remaining_attempts'], 4)

        # Verify with correct code
        res_ok = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)
        self.assertIn('submit_token', res_ok.data)
        token = res_ok.data['submit_token']

        # Confirm token stored hashed in DB
        token_obj = RequestSubmitToken.objects.filter(user=self.user, is_used=False).first()
        self.assertIsNotNone(token_obj)
        self.assertTrue(token_obj.is_valid())

    def test_request_create_requires_token_and_single_use(self):
        """Emergency and priority request creation strictly requires unused submit_token."""
        self.client.force_authenticate(user=self.user)

        payload = {
            'patient_name': 'Karim Ullah',
            'blood_group': 'O+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 5, Bed 12',
        }

        # 1. Attempt create without submit_token -> 403 Forbidden
        res_no_token = self.client.post('/api/requests/', payload, format='json')
        self.assertEqual(res_no_token.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Issue a real submit_token
        self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        otp_rec = EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit', is_used=False).first()
        test_code = '554433'
        otp_rec.otp_hash = hash_otp(test_code, otp_rec.email)
        otp_rec.save()

        res_v = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        token = res_v.data['submit_token']

        # 3. Create with valid token -> 201 Created
        payload_with_token = {**payload, 'submit_token': token}
        res_create = self.client.post('/api/requests/', payload_with_token, format='json')
        self.assertEqual(res_create.status_code, status.HTTP_201_CREATED)

        # 4. Attempt second create with SAME token -> 403 Forbidden (Single use)
        res_reuse = self.client.post('/api/requests/', payload_with_token, format='json')
        self.assertEqual(res_reuse.status_code, status.HTTP_403_FORBIDDEN)

    def test_forgot_password_google_only_account(self):
        """Google user without usable password receives 'Please use Google sign-in.'."""
        google_user = User.objects.create_user(
            username='google_user',
            email='google@example.com',
            first_name='Google'
        )
        google_user.set_unusable_password()
        google_user.save()

        res = self.client.post('/api/auth/password-reset/request/', {'email': 'google@example.com'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res.data['detail'], 'Please use Google sign-in.')

    def test_submit_token_expired_rejected_403(self):
        """Expired submit token returns 403 Forbidden."""
        import secrets, hashlib
        self.client.force_authenticate(user=self.user)
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
        RequestSubmitToken.objects.create(
            user=self.user,
            token_hash=token_hash,
            purpose='blood_request_submit',
            expires_at=timezone.now() - timedelta(minutes=1),
            is_used=False,
        )
        payload = {
            'patient_name': 'Test Expired',
            'blood_group': 'O+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 1',
            'submit_token': raw_token,
        }
        res = self.client.post('/api/requests/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_submit_token_another_user_rejected_403(self):
        """Submit token belonging to another user returns 403 Forbidden."""
        import secrets, hashlib
        other_user = User.objects.create_user(username='other_u', email='other@example.com')
        self.client.force_authenticate(user=self.user)
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
        RequestSubmitToken.objects.create(
            user=other_user,
            token_hash=token_hash,
            purpose='blood_request_submit',
            expires_at=timezone.now() + timedelta(minutes=15),
            is_used=False,
        )
        payload = {
            'patient_name': 'Test Other User',
            'blood_group': 'O+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 1',
            'submit_token': raw_token,
        }
        res = self.client.post('/api/requests/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_submit_token_wrong_purpose_rejected_403(self):
        """Submit token with different purpose returns 403 Forbidden."""
        import secrets, hashlib
        self.client.force_authenticate(user=self.user)
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
        RequestSubmitToken.objects.create(
            user=self.user,
            token_hash=token_hash,
            purpose='other_purpose_token',
            expires_at=timezone.now() + timedelta(minutes=15),
            is_used=False,
        )
        payload = {
            'patient_name': 'Test Wrong Purpose',
            'blood_group': 'O+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 1',
            'submit_token': raw_token,
        }
        res = self.client.post('/api/requests/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_request_otp_expired_rejected(self):
        """Expired request OTP returns 400 Bad Request."""
        self.client.force_authenticate(user=self.user)
        code = '123456'
        EmailOTP.objects.create(
            user=self.user,
            email=self.user.email,
            otp_hash=hash_otp(code, self.user.email),
            purpose='blood_request_submit',
            expires_at=timezone.now() - timedelta(minutes=1),
            is_used=False,
        )
        res = self.client.post('/api/requests/otp/verify/', {'code': code}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_request_otp_five_wrong_attempts_locks(self):
        """5 incorrect OTP attempts locks the OTP and returns 429."""
        self.client.force_authenticate(user=self.user)
        code = '654321'
        EmailOTP.objects.create(
            user=self.user,
            email=self.user.email,
            otp_hash=hash_otp(code, self.user.email),
            purpose='blood_request_submit',
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        for i in range(4):
            res = self.client.post('/api/requests/otp/verify/', {'code': '000000'}, format='json')
            self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        # 5th attempt locks
        res5 = self.client.post('/api/requests/otp/verify/', {'code': '000000'}, format='json')
        self.assertEqual(res5.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        # Subsequent attempt also returns 429
        res_locked = self.client.post('/api/requests/otp/verify/', {'code': code}, format='json')
        self.assertEqual(res_locked.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_request_otp_older_invalidated_on_resend(self):
        """Requesting a new OTP invalidates prior unused OTP for the same purpose."""
        self.client.force_authenticate(user=self.user)
        code1 = '111111'
        otp1 = EmailOTP.objects.create(
            user=self.user,
            email=self.user.email,
            otp_hash=hash_otp(code1, self.user.email),
            purpose='blood_request_submit',
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        EmailOTP.objects.filter(id=otp1.id).update(last_sent_at=timezone.now() - timedelta(seconds=70))
        # Trigger send after cooldown
        res_send = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
        self.assertEqual(res_send.status_code, status.HTTP_200_OK)

        otp1.refresh_from_db()
        self.assertTrue(otp1.is_used, "Older unused OTP was not marked as is_used on resend")

