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
