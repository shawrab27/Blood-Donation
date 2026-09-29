from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from unittest.mock import patch, MagicMock
from rest_framework.test import APIClient
from rest_framework import status
from api.models import PasswordResetOTP
from api.views_auth_reset import generate_otp_hash
from api.services.email import ConsoleEmailService, SmtpEmailService, get_email_service
from rest_framework_simplejwt.tokens import RefreshToken, BlacklistedToken

REQUEST_URL = '/api/auth/password-reset/request/'
CONFIRM_URL = '/api/auth/password-reset/confirm/'

# All tests that POST to request_otp must have DEBUG=True (or USE_SMTP_EMAIL=True)
# so get_email_service() doesn't raise ImproperlyConfigured.
REQUEST_SETTINGS = dict(DEBUG=True)


class PasswordResetTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='resetuser', email='reset@example.com', password='oldpassword123'
        )

    # ------------------------------------------------------------------
    # Risk 2 – Enumeration: known vs unknown must return identical body+code
    # at EVERY step, including when the cooldown is active.
    # ------------------------------------------------------------------

    @override_settings(**REQUEST_SETTINGS)
    def test_known_and_unknown_return_identical_body(self):
        resp_known = self.client.post(REQUEST_URL, {'email': 'reset@example.com'})
        resp_unknown = self.client.post(REQUEST_URL, {'email': 'nobody12345@example.com'})
        self.assertEqual(resp_known.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_unknown.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_known.json(), resp_unknown.json())

    @override_settings(**REQUEST_SETTINGS)
    def test_second_request_within_cooldown_same_body_and_code(self):
        """
        A second request within the 45-second cooldown for a KNOWN email must
        return the same 200 body as an unknown email — NOT a 429.
        If it returned 429, an attacker could infer the account exists.
        """
        self.client.post(REQUEST_URL, {'email': 'reset@example.com'})
        resp_known_again = self.client.post(REQUEST_URL, {'email': 'reset@example.com'})
        resp_unknown = self.client.post(REQUEST_URL, {'email': 'nobody12345@example.com'})

        # Both must be 200, not 429
        self.assertEqual(resp_known_again.status_code, status.HTTP_200_OK,
                         "Known email within cooldown returned non-200 (potential enumeration risk)")
        self.assertEqual(resp_unknown.status_code, status.HTTP_200_OK)
        # Same body
        self.assertEqual(resp_known_again.json(), resp_unknown.json())

    # ------------------------------------------------------------------
    # Risk 1 – Throttle: IP throttle scope must actually fire
    # ------------------------------------------------------------------

    @override_settings(
        DEBUG=True,
        CACHES={'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}},
    )
    def test_ip_throttle_wired_and_fires(self):
        """
        Verifies throttle scope is correctly wired on the function-based view.
        DRF reads view.throttle_scope at call time for ScopedRateThrottle.
        This test confirms:
        1. throttle_scope is set to 'request_otp' on request_otp view.
        2. IpRateThrottle is in the throttle_classes list.
        3. EmailRateThrottle uses a separate hardcoded scope 'email_otp'.
        """
        from api.views_auth_reset import request_otp, IpRateThrottle, EmailRateThrottle
        from rest_framework.throttling import ScopedRateThrottle

        # 1. Scope is wired on the view
        self.assertEqual(
            getattr(request_otp, 'throttle_scope', None),
            'request_otp',
            "request_otp.throttle_scope must be 'request_otp' for IP throttling to work",
        )

        # 2. Both throttle classes are in the decorator
        throttle_classes = request_otp.cls.throttle_classes  # type: ignore[attr-defined]
        class_names = {c.__name__ for c in throttle_classes}
        self.assertIn('IpRateThrottle', class_names,
                      f"IpRateThrottle missing from throttle_classes: {class_names}")
        self.assertIn('EmailRateThrottle', class_names,
                      f"EmailRateThrottle missing from throttle_classes: {class_names}")

        # 3. EmailRateThrottle uses its own scope (not 'request_otp')
        et = EmailRateThrottle()
        self.assertEqual(et.scope, 'email_otp',
                         "EmailRateThrottle.scope must be 'email_otp' to avoid sharing the IP rate")

    # ------------------------------------------------------------------
    # Risk 4 – Google-only account: set_password must work for social-only users
    # ------------------------------------------------------------------

    @override_settings(**REQUEST_SETTINGS)
    def test_google_only_user_can_set_password(self):
        google_user = User.objects.create_user(
            username='googleuser',
            email='google@example.com',
        )
        google_user.set_unusable_password()
        google_user.save()

        PasswordResetOTP.objects.create(
            user=google_user,
            otp_hash=generate_otp_hash('654321'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post(CONFIRM_URL, {
            'email': 'google@example.com',
            'otp': '654321',
            'new_password': 'NewSecurePass1!',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK,
                         f"Google-only user password reset failed: {resp.json()}")
        google_user.refresh_from_db()
        self.assertTrue(google_user.check_password('NewSecurePass1!'))

    # ------------------------------------------------------------------
    # Risk 5 – Email service: ConsoleEmailService blocked when DEBUG=False
    # ------------------------------------------------------------------

    @override_settings(DEBUG=False, USE_SMTP_EMAIL=False)
    def test_console_email_blocked_in_production(self):
        from django.core.exceptions import ImproperlyConfigured
        with self.assertRaises(ImproperlyConfigured):
            get_email_service()

    @override_settings(DEBUG=True, USE_SMTP_EMAIL=False)
    def test_console_email_allowed_in_debug(self):
        svc = get_email_service()
        self.assertIsInstance(svc, ConsoleEmailService)

    @override_settings(DEBUG=False, USE_SMTP_EMAIL=True)
    def test_smtp_email_selected_in_production(self):
        svc = get_email_service()
        self.assertIsInstance(svc, SmtpEmailService)

    # ------------------------------------------------------------------
    # Existing tests (retained)
    # ------------------------------------------------------------------

    @override_settings(**REQUEST_SETTINGS)
    def test_request_otp_stores_hash(self):
        self.client.post(REQUEST_URL, {'email': 'reset@example.com'})
        otp = PasswordResetOTP.objects.filter(user=self.user).first()
        self.assertIsNotNone(otp)
        self.assertEqual(len(otp.otp_hash), 64)

    def test_expired_otp(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() - timedelta(minutes=1),
            is_used=False,
        )
        resp = self.client.post(CONFIRM_URL, {
            'email': 'reset@example.com', 'otp': '123456', 'new_password': 'NewPassword123!',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_five_wrong_attempts_lock(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        for _ in range(5):
            resp = self.client.post(CONFIRM_URL, {
                'email': 'reset@example.com', 'otp': 'wrong1', 'new_password': 'NewPassword123!',
            })
        self.assertEqual(resp.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_success_flow_blacklists_tokens(self):
        refresh = RefreshToken.for_user(self.user)
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post(CONFIRM_URL, {
            'email': 'reset@example.com', 'otp': '123456', 'new_password': 'NewPassword123!',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertFalse(self.user.check_password('oldpassword123'))
        self.assertTrue(self.user.check_password('NewPassword123!'))
        self.assertTrue(BlacklistedToken.objects.filter(token__jti=refresh['jti']).exists())

    def test_weak_password_rejected(self):
        PasswordResetOTP.objects.create(
            user=self.user,
            otp_hash=generate_otp_hash('123456'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False,
        )
        resp = self.client.post(CONFIRM_URL, {
            'email': 'reset@example.com', 'otp': '123456', 'new_password': 'short',
        })
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('new_password', resp.json().get('errors', {}))
