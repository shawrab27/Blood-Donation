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
    """Dev-only adapter. Routes OTP delivery through UnifiedEmailService / EMAIL_PROVIDER."""

    def send_otp(self, to_email: str, otp: str) -> bool:
        return UnifiedEmailService().send_otp(to_email, otp)


class SmtpEmailService(EmailService):
    """Production adapter. Routes OTP delivery through UnifiedEmailService / EMAIL_PROVIDER."""

    def send_otp(self, to_email: str, otp: str) -> bool:
        return UnifiedEmailService().send_otp(to_email, otp)


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


from api.services.email_sender import (
    EmailSender,
    LocMemEmailSender,
    ConsoleEmailSender,
    BrevoApiEmailSender,
    EmailProviderError,
    UnifiedEmailService,
    get_email_sender,
)


def get_email_service() -> EmailService:
    """
    Returns the EmailService adapter, routing all OTP emails through UnifiedEmailService
    (EMAIL_PROVIDER = brevo_api | console | locmem) while enforcing production safety checks.
    """
    if getattr(settings, 'USE_SMTP_EMAIL', False):
        return SmtpEmailService()

    if settings.DEBUG:
        return ConsoleEmailService()

    if getattr(settings, 'EMAIL_PROVIDER', '') == 'brevo_api':
        return UnifiedEmailService()

    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured(
        "Email service is not configured for production. "
        "Set EMAIL_PROVIDER=brevo_api (or USE_SMTP_EMAIL=True) in production, "
        "or set DEBUG=True for local dev."
    )
