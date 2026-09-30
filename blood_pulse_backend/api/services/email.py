import logging
from abc import ABC, abstractmethod

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


class EmailService(ABC):
    @abstractmethod
    def send_otp(self, to_email: str, otp: str) -> bool:
        pass


class ConsoleEmailService(EmailService):
    """Dev-only adapter. Prints OTP to the terminal/log. Must NOT be used in production."""

    def send_otp(self, to_email: str, otp: str) -> bool:
        logger.info(
            "\n========== OTP EMAIL ==========\nTo: %s\nOTP: %s\n===============================\n",
            to_email,
            otp,
        )
        print(
            f"\n========== OTP EMAIL ==========\nTo: {to_email}\nOTP: {otp}\n===============================\n"
        )
        return True


class SmtpEmailService(EmailService):
    """Production adapter. Uses Django's EMAIL_* settings (Gmail SMTP app-password)."""

    def send_otp(self, to_email: str, otp: str) -> bool:
        expiry = getattr(settings, 'OTP_EXPIRY_MINUTES', 10)
        try:
            send_mail(
                subject="Your BloodPulse Password Reset Code",
                message=(
                    f"Your BloodPulse password reset code is: {otp}\n\n"
                    f"This code expires in {expiry} minutes.\n"
                    "If you did not request a password reset, you can safely ignore this email."
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[to_email],
                fail_silently=False,
            )
            return True
        except Exception as exc:
            logger.error("SmtpEmailService failed to send to %s: %s", to_email, exc)
            return False


def get_email_service() -> EmailService:
    """
    Returns the correct EmailService adapter.

    Selection rules (evaluated in order):
    1. If USE_SMTP_EMAIL=True in settings → SmtpEmailService (production).
    2. If DEBUG=True → ConsoleEmailService (dev / test convenience).
    3. Fallback when DEBUG=False and no SMTP configured → raise ImproperlyConfigured
       so the misconfiguration is loud rather than silently swallowing real emails.
    """
    if getattr(settings, 'USE_SMTP_EMAIL', False):
        return SmtpEmailService()

    if settings.DEBUG:
        return ConsoleEmailService()

    # Production without SMTP configured: fail loudly so operators notice.
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured(
        "Email service is not configured for production. "
        "Set USE_SMTP_EMAIL=True and configure EMAIL_HOST / EMAIL_HOST_USER / "
        "EMAIL_HOST_PASSWORD in your environment, or set DEBUG=True for local dev."
    )


import os
import secrets
import hmac
import hashlib

OTP_EXPIRY_MINUTES = 10
OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_MAX_HOURLY_REQUESTS = 3


def get_otp_pepper() -> str:
    """Returns the secret pepper used for HMAC-SHA256 OTP hashing."""
    return os.environ.get("OTP_PEPPER", settings.SECRET_KEY[:32])


def generate_secure_otp(length: int = 6) -> str:
    """Generates a cryptographically strong numeric OTP."""
    digits = "0123456789"
    return "".join(secrets.choice(digits) for _ in range(length))


def hash_otp(code: str, email: str = "") -> str:
    """Computes HMAC-SHA256 of the OTP code and email with secret pepper."""
    pepper = get_otp_pepper()
    msg = f"{email.strip().lower()}:{code.strip()}"
    return hmac.new(pepper.encode('utf-8'), msg.encode('utf-8'), hashlib.sha256).hexdigest()


def verify_otp_hash(code: str, expected_hash: str, email: str = "") -> bool:
    """Constant-time comparison of OTP code HMAC hash."""
    computed_hash = hash_otp(code, email)
    return hmac.compare_digest(computed_hash, expected_hash)


class EmailSender:
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: str = None) -> bool:
        raise NotImplementedError


class ConsoleEmailSender(EmailSender):
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: str = None) -> bool:
        logger.info(f"[CONSOLE EMAIL] To: {to_email} | Subject: {subject} | Body: {text_content}")
        return True


def get_email_sender() -> EmailSender:
    return ConsoleEmailSender()


