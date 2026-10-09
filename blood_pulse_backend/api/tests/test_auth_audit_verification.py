# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from unittest.mock import patch, MagicMock
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken, BlacklistedToken

from api.models import DonorProfile, PasswordResetOTP, BloodRequest
from api.views_auth_reset import generate_otp_hash

REQUEST_URL = '/api/auth/password-reset/request/'
CONFIRM_URL = '/api/auth/password-reset/confirm/'
GOOGLE_AUTH_URL = '/api/auth/google/'

REQUEST_SETTINGS = dict(
    DEBUG=True,
    CACHES={'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}
)


class AuthAuditVerificationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='audituser',
            email='audit@example.com',
            password='InitialPassword123!',
            first_name='Audit',
            last_name='User'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            phone_number='+8801711223344',
            district='Dhaka',
            is_profile_complete=True,
            email_verified=True,
        )

    # -------------------------------------------------------------------------
    # 1. Guest blocked on protected endpoints (401 / 403)
    # -------------------------------------------------------------------------
    def test_guest_blocked_on_protected_endpoints(self):
        anon_client = APIClient()

        # Emergency blood request creation (POST)
        res_emergency = anon_client.post('/api/emergency/requests/', {
            'patient_name': 'Emergency Patient',
            'blood_group': 'B+',
            'district': 'Dhaka',
        })
        self.assertEqual(res_emergency.status_code, status.HTTP_401_UNAUTHORIZED,
                         "Unauthenticated guest was not rejected with 401 on emergency request creation")

        # Standard request creation (POST)
        res_requests = anon_client.post('/api/requests/', {
            'patient_name': 'Standard Patient',
            'blood_group': 'B+',
        })
        self.assertEqual(res_requests.status_code, status.HTTP_401_UNAUTHORIZED,
                         "Unauthenticated guest was not rejected with 401 on /api/requests/")

        # Assistant Chat (POST)
        res_chat = anon_client.post('/api/assistant/chat/', {
            'message': 'Hello assistant',
        })
        self.assertEqual(res_chat.status_code, status.HTTP_401_UNAUTHORIZED,
                         "Unauthenticated guest was not rejected with 401 on assistant chat")

        # Profile personal details (GET)
        res_profile = anon_client.get('/api/profile/me/')
        self.assertEqual(res_profile.status_code, status.HTTP_401_UNAUTHORIZED,
                         "Unauthenticated guest was not rejected with 401 on profile me")

        # Accept emergency request (POST)
        res_accept = anon_client.post('/api/emergency/requests/99999/accept/', {})
        self.assertEqual(res_accept.status_code, status.HTTP_401_UNAUTHORIZED,
                         "Unauthenticated guest was not rejected with 401 on emergency request accept")

    # -------------------------------------------------------------------------
    # 2. OTP Expiry (10 minutes server-side rule)
    # -------------------------------------------------------------------------
    def test_otp_expiry(self):
        otp_record = PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() - timedelta(seconds=1),  # already expired
            is_used=False,
        )

        resp = self.client.post(CONFIRM_URL, {
            'email': self.user.email,
            'otp': '123456',
            'new_password': 'NewPassword123!',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        otp_record.refresh_from_db()
        self.assertTrue(otp_record.is_used, "Expired OTP must be marked as used/invalidated")

    # -------------------------------------------------------------------------
    # 3. 5-Wrong-Attempt Lockout
    # -------------------------------------------------------------------------
    def test_five_wrong_attempt_lockout(self):
        otp_record = PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('654321'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )

        for attempt in range(1, 5):
            resp = self.client.post(CONFIRM_URL, {
                'email': self.user.email,
                'otp': '000000',
                'new_password': 'NewPassword123!',
            })
            self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST, f"Attempt {attempt} should return 400")

        # 5th wrong attempt triggers lockout
        resp5 = self.client.post(CONFIRM_URL, {
            'email': self.user.email,
            'otp': '000000',
            'new_password': 'NewPassword123!',
        })
        self.assertEqual(resp5.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        otp_record.refresh_from_db()
        self.assertTrue(otp_record.is_used, "OTP must be invalidated on 5th failed attempt")

        # Even correct code fails after invalidation
        resp_after = self.client.post(CONFIRM_URL, {
            'email': self.user.email,
            'otp': '654321',
            'new_password': 'NewPassword123!',
        })
        self.assertEqual(resp_after.status_code, status.HTTP_400_BAD_REQUEST)

    # -------------------------------------------------------------------------
    # 4. Resend Limit (Max 3 resends per 15 minutes per email)
    # -------------------------------------------------------------------------
    @override_settings(**REQUEST_SETTINGS)
    def test_resend_limit_three_per_fifteen_minutes(self):
        now = timezone.now()
        # Create 3 recent OTP requests within 15 minutes
        for i in range(3):
            PasswordResetOTP.objects.create(
                user=self.user,
                otp_hash=generate_otp_hash(f'10000{i}'),
                expires_at=now + timedelta(minutes=10),
                created_at=now - timedelta(minutes=i),
                last_sent_at=now - timedelta(minutes=i),
                is_used=True,
            )

        initial_count = PasswordResetOTP.objects.filter(user=self.user).count()

        # 4th request must NOT generate a new OTP
        resp = self.client.post(REQUEST_URL, {'email': self.user.email})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        final_count = PasswordResetOTP.objects.filter(user=self.user).count()
        self.assertEqual(final_count, initial_count, "4th request should not create a new OTP record")

    # -------------------------------------------------------------------------
    # 5. Password validation / rejection of weak password
    # -------------------------------------------------------------------------
    def test_password_mismatch_and_weak_password_rejected(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post(CONFIRM_URL, {
            'email': self.user.email,
            'otp': '123456',
            'new_password': '123',  # Too short / common
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('new_password', resp.json().get('errors', {}))

    # -------------------------------------------------------------------------
    # 6. Reset invalidates old sessions / tokens
    # -------------------------------------------------------------------------
    def test_reset_invalidates_old_sessions(self):
        # Create active JWT tokens for user
        refresh = RefreshToken.for_user(self.user)
        access = refresh.access_token

        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('789012'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )

        resp = self.client.post(CONFIRM_URL, {
            'email': self.user.email,
            'otp': '789012',
            'new_password': 'FreshSecurePassword99!',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        # Password changed
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('FreshSecurePassword99!'))
        self.assertFalse(self.user.check_password('InitialPassword123!'))

        # Token was blacklisted
        self.assertTrue(
            BlacklistedToken.objects.filter(token__jti=refresh['jti']).exists(),
            "All previous outstanding tokens must be blacklisted upon password reset"
        )

    # -------------------------------------------------------------------------
    # 7. Anti-enumeration: send-OTP response is identical for existing vs non-existing
    # -------------------------------------------------------------------------
    @override_settings(**REQUEST_SETTINGS)
    def test_send_otp_response_identical_for_existing_and_non_existing(self):
        resp_existing = self.client.post(REQUEST_URL, {'email': self.user.email})
        resp_non_existing = self.client.post(REQUEST_URL, {'email': 'ghost_user_does_not_exist@example.com'})

        self.assertEqual(resp_existing.status_code, resp_non_existing.status_code)
        self.assertEqual(resp_existing.json(), resp_non_existing.json())
        self.assertEqual(resp_existing.status_code, status.HTTP_200_OK)

    # -------------------------------------------------------------------------
    # 8. Google auth: new user vs existing user branch
    # -------------------------------------------------------------------------
    def test_google_auth_new_user_vs_existing_user(self):
        fake_id_token = "valid_fake_id_token"

        # Mock urllib call to Google tokeninfo endpoint
        new_google_payload = {
            'sub': 'google-uid-new-12345',
            'email': 'new_google_person@example.com',
            'name': 'New Google Person',
            'picture': 'https://example.com/photo.jpg',
            'email_verified': True,
        }

        with patch('urllib.request.urlopen') as mock_urlopen:
            mock_resp = MagicMock()
            mock_resp.status = 200
            import json
            mock_resp.read.return_value = json.dumps(new_google_payload).encode('utf-8')
            mock_urlopen.return_value.__enter__.return_value = mock_resp

            # Case A: Brand new Google user
            resp_new = self.client.post(GOOGLE_AUTH_URL, {'id_token': fake_id_token})
            self.assertEqual(resp_new.status_code, status.HTTP_200_OK)
            self.assertIn('access', resp_new.data)
            self.assertIn('refresh', resp_new.data)
            self.assertEqual(resp_new.data['user']['email'], 'new_google_person@example.com')

            # Verify user and donor profile created in database
            created_user = User.objects.filter(email='new_google_person@example.com').first()
            self.assertIsNotNone(created_user)
            self.assertEqual(created_user.donorprofile.google_uid, 'google-uid-new-12345')

        # Case B: Existing Google user logging in again
        with patch('urllib.request.urlopen') as mock_urlopen:
            mock_resp = MagicMock()
            mock_resp.status = 200
            mock_resp.read.return_value = json.dumps(new_google_payload).encode('utf-8')
            mock_urlopen.return_value.__enter__.return_value = mock_resp

            resp_existing = self.client.post(GOOGLE_AUTH_URL, {'id_token': fake_id_token})
            self.assertEqual(resp_existing.status_code, status.HTTP_200_OK)
            self.assertEqual(resp_existing.data['user']['email'], 'new_google_person@example.com')
            self.assertEqual(resp_existing.data['user']['id'], created_user.id)
