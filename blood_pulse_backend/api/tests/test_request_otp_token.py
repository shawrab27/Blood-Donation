# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import json
from datetime import timedelta
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.core import mail
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile, Hospital, BloodRequest, EmailOTP, RequestSubmitToken
from api.services.email import hash_otp


from django.core.cache import cache

@override_settings(EMAIL_PROVIDER='locmem')
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

    def test_submit_token_not_burned_on_validation_error(self):
        """Invalid payload does not consume submit_token; token remains usable until success."""
        self.client.force_authenticate(user=self.user)

        # Issue a real submit_token
        self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        otp_rec = EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit', is_used=False).first()
        test_code = '112233'
        otp_rec.otp_hash = hash_otp(test_code, otp_rec.email)
        otp_rec.save()

        res_v = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        token = res_v.data['submit_token']

        # 1. Submit with invalid payload (missing required fields e.g. blood_group)
        bad_payload = {
            'patient_name': 'Patient Error',
            # missing blood_group or invalid blood_group
            'blood_group': '',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 1',
            'submit_token': token,
        }
        res_fail = self.client.post('/api/requests/', bad_payload, format='json')
        self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)

        # Check token is still NOT used in database
        token_hash = RequestSubmitToken.objects.filter(user=self.user, is_used=False).first()
        self.assertIsNotNone(token_hash)
        self.assertFalse(token_hash.is_used)

        # 2. Re-submit valid payload using the SAME token -> Succeeds 201 Created
        good_payload = {
            'patient_name': 'Patient Success',
            'blood_group': 'O+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'ward_bed': 'Ward 1',
            'submit_token': token,
        }
        res_ok = self.client.post('/api/requests/', good_payload, format='json')
        self.assertEqual(res_ok.status_code, status.HTTP_201_CREATED)

        # Check token IS consumed now
        token_hash.refresh_from_db()
        self.assertTrue(token_hash.is_used)

        # 3. Third attempt with same token -> 403 Forbidden
        res_reuse = self.client.post('/api/requests/', good_payload, format='json')
        self.assertEqual(res_reuse.status_code, status.HTTP_403_FORBIDDEN)

    def test_otp_not_burned_when_emergency_request_missing_ward_bed_400(self):
        """When an emergency request fails with 400 (missing Ward/Bed), OTP is not burned."""
        self.client.force_authenticate(user=self.user)

        # 1. Dispatch OTP
        self.client.post('/api/requests/otp/send/', {'email': 'requester@example.com'}, format='json')
        otp_rec = EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit', is_used=False).first()
        test_code = '778899'
        otp_rec.otp_hash = hash_otp(test_code, otp_rec.email)
        otp_rec.save()

        # 2. Verify OTP -> Issues submit_token, but does NOT consume the OTP
        res_v = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        self.assertEqual(res_v.status_code, status.HTTP_200_OK)
        token = res_v.data['submit_token']

        otp_rec.refresh_from_db()
        self.assertFalse(otp_rec.is_used, "OTP should not be consumed until request payload is validated.")

        # 3. Post emergency request with missing Ward/Bed -> 400 Bad Request
        bad_emergency_payload = {
            'patient_name': 'Emergency Patient',
            'blood_group': 'B+',
            'units_needed': 1,
            'hospital_name_other': 'Dhaka Medical',
            'contact_phone': '+8801700000000',
            'urgency': 'CRITICAL_2H',
            'submit_token': token,
            # 'ward_bed' is missing!
        }
        res_fail = self.client.post('/api/emergency/requests/', bad_emergency_payload, format='json')
        self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('ward_bed', res_fail.data)
        self.assertEqual(res_fail.data['ward_bed'], ['Ward/Bed information is required.'])

        # Confirm OTP is STILL not marked used
        otp_rec.refresh_from_db()
        self.assertFalse(otp_rec.is_used)

        # 4. User verifies OTP again -> Still succeeds (not locked out with 'Invalid or expired verification code')
        res_v2 = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        self.assertEqual(res_v2.status_code, status.HTTP_200_OK)
        token2 = res_v2.data['submit_token']

        # 5. Post emergency request with valid Ward/Bed -> 201 Created
        good_emergency_payload = {
            **bad_emergency_payload,
            'ward_bed': 'Ward 5, Bed 12',
            'submit_token': token2,
        }
        res_ok = self.client.post('/api/emergency/requests/', good_emergency_payload, format='json')
        self.assertEqual(res_ok.status_code, status.HTTP_201_CREATED)

        # 6. Check that BOTH submit_token AND OTP are now consumed
        otp_rec.refresh_from_db()
        self.assertTrue(otp_rec.is_used, "OTP must be marked as used after request is created successfully.")

        # 7. Further attempt to verify the same code -> 400 Invalid or expired code
        res_v3 = self.client.post('/api/requests/otp/verify/', {'code': test_code}, format='json')
        self.assertEqual(res_v3.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Invalid or expired', res_v3.data['error'])

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


class BrevoApiEmailSenderAndSeedGuardTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='brevo_user',
            email='brevo_user@example.com',
            password='Password123!',
            first_name='Brevo',
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_profile_complete=True,
            email_verified=True,
            user_intent='DONATE_AND_REQUEST',
        )

    def test_brevo_api_sender_posts_https_with_api_key_and_8s_timeout(self):
        """BrevoApiEmailSender calls POST https://api.brevo.com/v3/smtp/email with api-key header and 8s timeout."""
        from unittest.mock import patch, MagicMock
        from api.services.email_sender import BrevoApiEmailSender

        mock_resp = MagicMock()
        mock_resp.status_code = 201

        sender = BrevoApiEmailSender(
            api_key='test-brevo-key',
            sender_email='verified@sender.example',
            sender_name='BloodPulse',
        )
        with patch('api.services.email_sender.requests.post', return_value=mock_resp) as mock_post:
            ok = sender.send_email(
                to_email='recipient@example.com',
                subject='123456 is your code',
                text_content='Code: 123456',
            )
            self.assertTrue(ok)
            mock_post.assert_called_once()
            args, kwargs = mock_post.call_args
            self.assertEqual(args[0], 'https://api.brevo.com/v3/smtp/email')
            self.assertEqual(kwargs['timeout'], 8)
            self.assertEqual(kwargs['headers']['api-key'], 'test-brevo-key')
            self.assertEqual(kwargs['json']['sender']['email'], 'verified@sender.example')
            self.assertEqual(kwargs['json']['to'], [{'email': 'recipient@example.com'}])

    def test_provider_429_or_timeout_returns_503_and_does_not_start_cooldown(self):
        """On Brevo 429 or timeout, OTP endpoints return HTTP 503 and do NOT start resend cooldown."""
        import requests as req_lib
        from unittest.mock import patch, MagicMock
        from django.test import override_settings
        from api.models import PasswordResetOTP

        self.client.force_authenticate(user=self.user)

        # 1. Simulate HTTP 429 from Brevo on /api/requests/otp/send/
        resp_429 = MagicMock()
        resp_429.status_code = 429
        with override_settings(
            EMAIL_PROVIDER='brevo_api',
            BREVO_API_KEY='test-key',
            BREVO_SENDER_EMAIL='verified@sender.example',
            BREVO_SENDER_NAME='BloodPulse',
        ):
            with patch('api.services.email_sender.requests.post', return_value=resp_429):
                res = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
                self.assertEqual(res.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
                self.assertEqual(
                    EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit').count(),
                    0,
                )

            # 2. Simulate Timeout on /api/auth/password-reset/request/
            with patch('api.services.email_sender.requests.post', side_effect=req_lib.exceptions.Timeout('timed out')):
                res_pw = self.client.post('/api/auth/password-reset/request/', {'email': self.user.email}, format='json')
                self.assertEqual(res_pw.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
                self.assertEqual(PasswordResetOTP.objects.filter(user=self.user).count(), 0)

            # 3. Immediate retry when Brevo recovers (201) succeeds (cooldown was NOT started!)
            resp_201 = MagicMock()
            resp_201.status_code = 201
            with patch('api.services.email_sender.requests.post', return_value=resp_201):
                res_ok = self.client.post('/api/requests/otp/send/', {'email': self.user.email}, format='json')
                self.assertEqual(res_ok.status_code, status.HTTP_200_OK)
                self.assertEqual(
                    EmailOTP.objects.filter(user=self.user, purpose='blood_request_submit').count(),
                    1,
                )

    def test_send_test_email_command_missing_key_prints_warning_and_continues(self):
        """manage.py send_test_email prints 'BREVO_API_KEY missing' and returns cleanly when key is absent."""
        from io import StringIO
        from django.core.management import call_command
        from django.test import override_settings

        out = StringIO()
        with override_settings(EMAIL_PROVIDER='brevo_api', BREVO_API_KEY=''):
            call_command('send_test_email', 'test@example.com', stdout=out)
        self.assertIn('BREVO_API_KEY missing', out.getvalue())

    def test_seed_commands_refuse_in_production_or_without_flag(self):
        """seed_bloodhub_demo and seed_health_hub_content refuse under DJANGO_ENV=production or without flag."""
        import os
        from io import StringIO
        from unittest.mock import patch
        from django.core.management import call_command
        from django.core.management.base import CommandError

        # 1. Refuses in production even when --i-understand-this-creates-fake-users is passed
        with patch.dict(os.environ, {'DJANGO_ENV': 'production'}):
            with self.assertRaises(CommandError):
                call_command(
                    'seed_bloodhub_demo',
                    '--i-understand-this-creates-fake-users',
                    stdout=StringIO(),
                    stderr=StringIO(),
                )
            with self.assertRaises(CommandError):
                call_command(
                    'seed_health_hub_content',
                    '--i-understand-this-creates-fake-users',
                    stdout=StringIO(),
                    stderr=StringIO(),
                )

        # 2. Refuses in dev when flag is omitted
        with patch.dict(os.environ, {'DJANGO_ENV': 'dev'}):
            with self.assertRaises(CommandError):
                call_command('seed_bloodhub_demo', stdout=StringIO(), stderr=StringIO())
            with self.assertRaises(CommandError):
                call_command('seed_health_hub_content', stdout=StringIO(), stderr=StringIO())


