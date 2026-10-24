# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import timedelta
from unittest.mock import patch, MagicMock
from io import StringIO
import requests

from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.management import call_command
from rest_framework.test import APIClient
from rest_framework import status

from api.models import PasswordResetOTP
from api.views_auth_reset import generate_otp_hash
from api.services.email_service import (
    MailjetEmailProvider,
    ResendEmailProvider,
    BrevoEmailProvider,
    ConsoleEmailProvider,
    LocMemEmailProvider,
    EmailConfigError,
    EmailProviderError,
    render_otp_email,
    get_email_service,
    mask_email,
)


class EmailServiceAndProviderTests(TestCase):
    def test_mask_email_redacts_pii(self):
        self.assertEqual(mask_email('user@example.com'), 'u***r@example.com')
        self.assertEqual(mask_email('me@example.com'), 'm*@example.com')
        self.assertEqual(mask_email('invalid'), '***')

    def test_render_otp_email_contains_brand_tokens(self):
        text, html = render_otp_email("123456", expiry_minutes=10, purpose="Password Reset")
        self.assertIn("123456", text)
        self.assertIn("10 minutes", text)
        self.assertIn("BloodPulse", text)
        self.assertIn("#C30121", html)
        self.assertIn("123456", html)
        self.assertIn("Georgia", html)

    # ── Mailjet Provider Tests ──────────────────────────────────────────

    def test_mailjet_missing_credentials_raises_config_error(self):
        provider = MailjetEmailProvider(api_key='', secret_key='', sender_email='')
        with self.assertRaises(EmailConfigError):
            provider.send_email(to_email='user@example.com', subject='Test', text_content='Hello')

    @patch('api.services.email_service.requests.post')
    def test_mailjet_send_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "Messages": [{"Status": "success"}]
        }
        mock_post.return_value = mock_resp

        provider = MailjetEmailProvider(
            api_key='fake_mj_key',
            secret_key='fake_mj_secret',
            sender_email='noreply@bloodpulse.app',
        )
        res = provider.send_email(to_email='recipient@example.com', subject='Test', text_content='Msg')
        self.assertTrue(res['success'])
        self.assertEqual(res['status_code'], 200)
        self.assertEqual(res['provider'], 'mailjet')

    @patch('api.services.email_service.requests.post')
    def test_mailjet_provider_http_error(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 401
        mock_post.return_value = mock_resp

        provider = MailjetEmailProvider(
            api_key='fake_mj_key',
            secret_key='fake_mj_secret',
            sender_email='noreply@bloodpulse.app',
        )
        with self.assertRaises(EmailProviderError) as ctx:
            provider.send_email(to_email='recipient@example.com', subject='Test', text_content='Msg')
        self.assertEqual(ctx.exception.status_code, 401)

    @patch('api.services.email_service.requests.post')
    def test_mailjet_network_timeout(self, mock_post):
        mock_post.side_effect = requests.exceptions.Timeout("Connection timed out")

        provider = MailjetEmailProvider(
            api_key='fake_mj_key',
            secret_key='fake_mj_secret',
            sender_email='noreply@bloodpulse.app',
        )
        with self.assertRaises(EmailProviderError) as ctx:
            provider.send_email(to_email='recipient@example.com', subject='Test', text_content='Msg')
        self.assertEqual(ctx.exception.status_code, 503)

    # ── Resend Provider Tests ───────────────────────────────────────────

    def test_resend_missing_credentials_raises_config_error(self):
        provider = ResendEmailProvider(api_key='', sender_email='')
        with self.assertRaises(EmailConfigError):
            provider.send_email(to_email='user@example.com', subject='Test', text_content='Hello')

    @patch('api.services.email_service.requests.post')
    def test_resend_send_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_post.return_value = mock_resp

        provider = ResendEmailProvider(api_key='re_test123', sender_email='onboarding@resend.dev')
        res = provider.send_email(to_email='user@example.com', subject='Test', text_content='Body')
        self.assertTrue(res['success'])
        self.assertEqual(res['provider'], 'resend')

    # ── Console Provider Tests ──────────────────────────────────────────

    @override_settings(DEBUG=False)
    def test_console_provider_refused_when_debug_false(self):
        provider = ConsoleEmailProvider()
        with self.assertRaises(EmailConfigError):
            provider.send_email(to_email='user@example.com', subject='Test', text_content='Body')

    @override_settings(DEBUG=True)
    def test_console_provider_allowed_in_debug(self):
        provider = ConsoleEmailProvider()
        res = provider.send_email(to_email='user@example.com', subject='Test', text_content='Body')
        self.assertTrue(res['success'])

    # ── LocMem Provider Tests ───────────────────────────────────────────

    @override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
    def test_locmem_provider_dispatches_to_outbox(self):
        from django.core import mail
        mail.outbox.clear()
        provider = LocMemEmailProvider()
        res = provider.send_email(to_email='user@example.com', subject='Test LocMem', text_content='Body text')
        self.assertTrue(res['success'])
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].subject, 'Test LocMem')

    # ── SMTP Provider Tests ─────────────────────────────────────────────

    def test_smtp_provider_with_all_vars_loads_and_missing_var_raises_improperly_configured(self):
        """
        Verify that:
        1. When EMAIL_PROVIDER=smtp with all vars provided, SMTP settings load correctly:
           - EMAIL_BACKEND is 'django.core.mail.backends.smtp.EmailBackend'
           - EMAIL_HOST, EMAIL_PORT, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD, EMAIL_USE_TLS are configured.
           - Case-insensitive TLS parsing works ('yes', 'true', '1' -> True; '0', 'false' -> False).
           - DEFAULT_FROM_EMAIL defaults to SMTP_USER unless already set.
        2. When EMAIL_PROVIDER=smtp with a missing var, ImproperlyConfigured is raised naming the missing var.
        """
        from django.core.exceptions import ImproperlyConfigured
        from blood_pulse_backend.settings import configure_smtp_settings

        full_env = {
            'EMAIL_PROVIDER': 'smtp',
            'SMTP_HOST': 'smtp.gmail.com',
            'SMTP_PORT': '587',
            'SMTP_USER': 'bloodpulse.alerts@gmail.com',
            'SMTP_PASSWORD': 'app-specific-password',
            'SMTP_USE_TLS': 'YES',
        }
        cfg = configure_smtp_settings(full_env)
        self.assertEqual(cfg['EMAIL_BACKEND'], 'django.core.mail.backends.smtp.EmailBackend')
        self.assertEqual(cfg['EMAIL_HOST'], 'smtp.gmail.com')
        self.assertEqual(cfg['EMAIL_PORT'], 587)
        self.assertEqual(cfg['EMAIL_HOST_USER'], 'bloodpulse.alerts@gmail.com')
        self.assertEqual(cfg['EMAIL_HOST_PASSWORD'], 'app-specific-password')
        self.assertTrue(cfg['EMAIL_USE_TLS'])
        self.assertEqual(cfg['DEFAULT_FROM_EMAIL'], 'bloodpulse.alerts@gmail.com')
        self.assertTrue(cfg['USE_SMTP_EMAIL'])

        # Case-insensitive TLS parsing checks
        self.assertTrue(configure_smtp_settings({**full_env, 'SMTP_USE_TLS': 'true'})['EMAIL_USE_TLS'])
        self.assertTrue(configure_smtp_settings({**full_env, 'SMTP_USE_TLS': '1'})['EMAIL_USE_TLS'])
        self.assertFalse(configure_smtp_settings({**full_env, 'SMTP_USE_TLS': 'false'})['EMAIL_USE_TLS'])
        self.assertFalse(configure_smtp_settings({**full_env, 'SMTP_USE_TLS': '0'})['EMAIL_USE_TLS'])

        # DEFAULT_FROM_EMAIL already set check
        env_with_from = {**full_env, 'DEFAULT_FROM_EMAIL': 'custom@bloodpulse.app'}
        self.assertEqual(configure_smtp_settings(env_with_from)['DEFAULT_FROM_EMAIL'], 'custom@bloodpulse.app')

        # Failure cases: Missing required vars raise ImproperlyConfigured naming missing var
        for missing_var in ('SMTP_HOST', 'SMTP_USER', 'SMTP_PASSWORD'):
            bad_env = {k: v for k, v in full_env.items() if k != missing_var}
            with self.assertRaises(ImproperlyConfigured) as ctx:
                configure_smtp_settings(bad_env)
            self.assertIn(missing_var, str(ctx.exception))

    @override_settings(
        EMAIL_PROVIDER='smtp',
        EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
        EMAIL_HOST='smtp.gmail.com',
        EMAIL_PORT=587,
        EMAIL_HOST_USER='test@example.com',
        EMAIL_HOST_PASSWORD='password',
        DEFAULT_FROM_EMAIL='test@example.com',
    )
    def test_smtp_provider_dispatch_uses_django_send_mail(self):
        from django.core import mail
        from api.services.email_service import SmtpEmailProvider
        mail.outbox.clear()

        provider = SmtpEmailProvider()
        res = provider.send_email(
            to_email='recipient@example.com',
            subject='SMTP OTP Subject',
            text_content='OTP code: 123456',
            html_content='<p>123456</p>',
        )
        self.assertTrue(res['success'])
        self.assertEqual(res['provider'], 'smtp')
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].subject, 'SMTP OTP Subject')
        self.assertEqual(mail.outbox[0].to, ['recipient@example.com'])
        self.assertEqual(mail.outbox[0].from_email, 'test@example.com')


class ManagementCommandTests(TestCase):
    @override_settings(EMAIL_PROVIDER='locmem')
    def test_send_test_email_command_with_to_flag(self):
        out = StringIO()
        call_command('send_test_email', '--to', 'testrecipient@example.com', stdout=out)
        output = out.getvalue()
        self.assertIn('Provider: locmem', output)
        self.assertIn('Status: Success (HTTP 200)', output)
        self.assertIn('t***t@example.com', output)

    @override_settings(EMAIL_PROVIDER='locmem')
    def test_send_test_email_command_positional(self):
        out = StringIO()
        call_command('send_test_email', 'testrecipient@example.com', stdout=out)
        output = out.getvalue()
        self.assertIn('Provider: locmem', output)
        self.assertIn('Status: Success (HTTP 200)', output)


class VerifyOtpAndResetEndpointTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='otpuser1',
            email='testuser@example.com',
            password='oldPassword123!',
        )

    @override_settings(DEBUG=True, EMAIL_PROVIDER='locmem')
    def test_request_otp_invalidates_previous_otps(self):
        otp = PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('111111'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        # Backdate last_sent_at past cooldown
        PasswordResetOTP.objects.filter(pk=otp.pk).update(last_sent_at=timezone.now() - timedelta(seconds=70))

        resp = self.client.post('/api/auth/request-otp/', {'email': 'testuser@example.com'})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        old_otp = PasswordResetOTP.objects.filter(user=self.user, otp_hash=generate_otp_hash('111111')).first()
        self.assertTrue(old_otp.is_used)

    def test_verify_otp_endpoint_success(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('555666'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post('/api/auth/verify-otp/', {
            'email': 'testuser@example.com',
            'otp': '555666',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.json().get('valid'))

    def test_verify_otp_endpoint_wrong_code(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('555666'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post('/api/auth/verify-otp/', {
            'email': 'testuser@example.com',
            'otp': '999999',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_verify_otp_endpoint_expired_code(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('555666'),
            expires_at=timezone.now() - timedelta(minutes=1),
            is_used=False,
        )
        resp = self.client.post('/api/auth/verify-otp/', {
            'email': 'testuser@example.com',
            'otp': '555666',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_verify_otp_endpoint_max_attempts_lockout(self):
        otp = PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('555666'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
            attempts=4,
        )
        resp = self.client.post('/api/auth/verify-otp/', {
            'email': 'testuser@example.com',
            'otp': '000000',
        })
        self.assertEqual(resp.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        otp.refresh_from_db()
        self.assertTrue(otp.is_used)

    @override_settings(DEBUG=True)
    @patch('api.services.email_service.get_email_service')
    def test_request_otp_provider_failure_returns_clean_503(self, mock_get_svc):
        PasswordResetOTP.objects.filter(user=self.user).delete()
        mock_svc = MagicMock()
        mock_svc.send_otp.side_effect = EmailProviderError("Mailjet returned HTTP 500", status_code=500)
        mock_get_svc.return_value = mock_svc

        resp = self.client.post('/api/auth/request-otp/', {'email': 'testuser@example.com'})
        self.assertEqual(resp.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        data = resp.json()
        self.assertEqual(data.get('code'), 'EMAIL_UNAVAILABLE')
        self.assertIn('unavailable', data.get('detail', '').lower())
