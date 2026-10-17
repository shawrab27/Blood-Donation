# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
import os
import requests
from abc import ABC, abstractmethod
from typing import Optional

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


class EmailUnavailableError(Exception):
    """Raised when the email provider is unconfigured, disabled, or fails to deliver."""
    pass


class EmailProviderError(EmailUnavailableError):
    """Raised when the email provider fails with a network or 4xx/5xx error."""
    pass


def mask_email(email: str) -> str:
    """Mask email for safe logging without PII leakage: j***e@example.com"""
    if not email or '@' not in email:
        return '***'
    user, domain = email.split('@', 1)
    if len(user) <= 2:
        masked_user = user[0] + '*'
    else:
        masked_user = user[0] + '***' + user[-1]
    return f"{masked_user}@{domain}"


class EmailSender(ABC):
    @abstractmethod
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> bool:
        """Sends a transactional email. Raises EmailProviderError on recoverable provider failures."""
        pass


class LocMemEmailSender(EmailSender):
    """Test-only sender using Django's locmem backend or in-memory outbox."""
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> bool:
        from django.core.mail import EmailMultiAlternatives
        from_addr = (
            getattr(settings, 'BREVO_SENDER_EMAIL', '')
            or getattr(settings, 'DEFAULT_FROM_EMAIL', '')
            or 'locmem@localhost'
        )
        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_addr,
            to=[to_email],
        )
        if html_content:
            msg.attach_alternative(html_content, "text/html")
        msg.send(fail_silently=False)
        return True


class ConsoleEmailSender(EmailSender):
    """Dev-only sender. Prints destination and subject. Never logs OTP codes or raw PII."""
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> bool:
        logger.info("[ConsoleEmailSender] To: %s | Subject: %s", mask_email(to_email), subject)
        return True


class BrevoApiEmailSender(EmailSender):
    """
    Sends transactional email via Brevo REST API:
    POST https://api.brevo.com/v3/smtp/email
    Timeout: 8 seconds.
    Config strictly from env/settings (BREVO_API_KEY, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME).
    Never logs API keys or OTP codes.
    """
    ENDPOINT = "https://api.brevo.com/v3/smtp/email"
    TIMEOUT_SECONDS = 8

    def __init__(self, api_key: str = None, sender_email: str = None, sender_name: str = None):
        self.api_key = api_key if api_key is not None else (getattr(settings, 'BREVO_API_KEY', '') or os.getenv('BREVO_API_KEY', ''))
        self.sender_email = sender_email if sender_email is not None else (getattr(settings, 'BREVO_SENDER_EMAIL', '') or os.getenv('BREVO_SENDER_EMAIL', ''))
        self.sender_name = sender_name if sender_name is not None else (getattr(settings, 'BREVO_SENDER_NAME', '') or os.getenv('BREVO_SENDER_NAME', 'BloodPulse'))

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> bool:
        masked = mask_email(to_email)
        if not self.api_key:
            logger.error("BREVO_API_KEY missing. Cannot dispatch email to %s", masked)
            raise EmailProviderError("BREVO_API_KEY missing")
        if not self.sender_email:
            logger.error("BREVO_SENDER_EMAIL missing. Cannot dispatch email to %s", masked)
            raise EmailProviderError("BREVO_SENDER_EMAIL missing")

        headers = {
            "api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        payload = {
            "sender": {
                "name": self.sender_name,
                "email": self.sender_email,
            },
            "to": [
                {"email": to_email}
            ],
            "subject": subject,
            "textContent": text_content,
        }
        if html_content:
            payload["htmlContent"] = html_content

        try:
            resp = requests.post(
                self.ENDPOINT,
                json=payload,
                headers=headers,
                timeout=self.TIMEOUT_SECONDS,
            )
        except (requests.exceptions.Timeout, requests.exceptions.RequestException) as exc:
            logger.error("Brevo API request failed for recipient %s: %s", masked, exc.__class__.__name__)
            raise EmailProviderError(f"Email delivery timed out or network error: {exc.__class__.__name__}") from exc

        if resp.status_code in (200, 201, 202):
            return True
        elif resp.status_code == 429:
            logger.warning("Brevo API rate limited (429) for recipient %s", masked)
            raise EmailProviderError("Email service rate limit reached. Please try again shortly.")
        else:
            logger.error("Brevo API error %s for recipient %s", resp.status_code, masked)
            raise EmailProviderError(f"Email service returned HTTP {resp.status_code}")


class ResendApiEmailSender(EmailSender):
    """
    Sends transactional email via Resend REST API:
    POST https://api.resend.com/emails
    Timeout: 8 seconds.
    Config from env/settings (RESEND_API_KEY, RESEND_SENDER_EMAIL).
    Free tier allows 100 emails/day with owner-verified domain.
    """
    ENDPOINT = "https://api.resend.com/emails"
    TIMEOUT_SECONDS = 8

    def __init__(self, api_key: str = None, sender_email: str = None):
        self.api_key = api_key if api_key is not None else (getattr(settings, 'RESEND_API_KEY', '') or os.getenv('RESEND_API_KEY', ''))
        self.sender_email = sender_email if sender_email is not None else (getattr(settings, 'RESEND_SENDER_EMAIL', '') or os.getenv('RESEND_SENDER_EMAIL', 'onboarding@resend.dev'))

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> bool:
        masked = mask_email(to_email)
        if not self.api_key:
            logger.error("RESEND_API_KEY missing. Cannot dispatch email to %s", masked)
            raise EmailProviderError("RESEND_API_KEY missing")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        payload = {
            "from": self.sender_email,
            "to": [to_email],
            "subject": subject,
            "text": text_content,
        }
        if html_content:
            payload["html"] = html_content

        try:
            resp = requests.post(
                self.ENDPOINT,
                json=payload,
                headers=headers,
                timeout=self.TIMEOUT_SECONDS,
            )
        except (requests.exceptions.Timeout, requests.exceptions.RequestException) as exc:
            logger.error("Resend API request failed for recipient %s: %s", masked, exc.__class__.__name__)
            raise EmailProviderError(f"Email delivery timed out or network error: {exc.__class__.__name__}") from exc

        if resp.status_code in (200, 201):
            return True
        elif resp.status_code == 429:
            logger.warning("Resend API rate limited (429) for recipient %s", masked)
            raise EmailProviderError("Email service rate limit reached. Please try again shortly.")
        else:
            logger.error("Resend API error %s for recipient %s", resp.status_code, masked)
            raise EmailProviderError(f"Email service returned HTTP {resp.status_code}")


# Aliases matching Phase 1 architecture naming
from api.services.email_service import (
    ConsoleEmailProvider as ConsoleProvider,
    BrevoEmailProvider as BrevoApiProvider,
    LocMemEmailProvider as LocMemProvider,
)


def get_email_provider() -> EmailSender:
    """
    Returns the appropriate EmailProvider via api.services.email_service.
    Supports mailjet, resend, brevo, console, and locmem.
    """
    from api.services.email_service import get_email_provider as _get_provider
    return _get_provider()


def get_email_sender() -> EmailSender:
    """Returns the configured EmailSender instance via api.services.email_service."""
    from api.services.email_service import get_email_service as _get_service
    return _get_service()


# ── Backward compatibility adapter for send_otp ───────────────────────────────

class EmailService(ABC):
    @abstractmethod
    def send_otp(self, to_email: str, otp: str) -> bool:
        pass


class UnifiedEmailService(EmailService):
    def send_otp(self, to_email: str, otp: str) -> bool:
        sender = get_email_provider()
        expiry = getattr(settings, 'OTP_EXPIRY_MINUTES', 10)
        subject = f"{otp} is your BloodPulse verification code"
        text_content = (
            f"Your BloodPulse verification code is: {otp}\n\n"
            f"This code expires in {expiry} minutes.\n"
            "If you did not request this code, you can safely ignore this email."
        )
        return sender.send_email(to_email=to_email, subject=subject, text_content=text_content)


def get_email_service() -> EmailService:
    return UnifiedEmailService()

