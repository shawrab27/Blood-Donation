# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Provider-Agnostic HTTPS API Email Service (Anomaly #1, #26).
Render free-tier environments block outgoing SMTP ports (25, 465, 587).
This service dispatches all transactional and OTP emails purely via HTTPS REST APIs.
Supported providers:
  - mailjet: Mailjet v3.1 Send API (HTTP Basic Auth with MAILJET_API_KEY and MAILJET_SECRET_KEY)
  - resend: Resend REST API (Bearer auth with RESEND_API_KEY)
  - brevo: Brevo v3 SMTP API (api-key header with BREVO_API_KEY)
  - console: Dev-only (STRICTLY REFUSED when DEBUG is False)
  - locmem: Test-only (in-memory outbox)
"""

import logging
import os
from abc import ABC, abstractmethod
from typing import Optional, Tuple
import requests

from django.conf import settings
from django.core.mail import EmailMultiAlternatives

logger = logging.getLogger(__name__)


class EmailDeliveryError(Exception):
    """Base exception for email delivery failures."""
    pass


class EmailConfigError(EmailDeliveryError):
    """Raised when required environment variables or configuration for a provider are missing."""
    pass


class EmailProviderError(EmailDeliveryError):
    """Raised when an external HTTPS email provider returns an error or times out."""
    def __init__(self, message: str, status_code: Optional[int] = None):
        super().__init__(message)
        self.status_code = status_code


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


def render_otp_email(otp_code: str, expiry_minutes: int = 10, purpose: str = "Verification") -> Tuple[str, str]:
    """
    Renders short branded plain-text and HTML templates for BloodPulse OTP emails.
    Uses BloodPulse brand tokens (#C30121 primary, #FDF3F3 surface, Georgia / Inter).
    """
    text_content = (
        f"BloodPulse {purpose} Code\n\n"
        f"Your 6-digit verification code is: {otp_code}\n\n"
        f"This code will expire in {expiry_minutes} minutes.\n"
        f"If you did not request this code, please ignore this email. Never share this code with anyone.\n\n"
        f"— BloodPulse Bangladesh Blood Network"
    )

    html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>BloodPulse {purpose}</title>
</head>
<body style="margin: 0; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #FDF3F3; color: #2B2B2B;">
  <div style="max-width: 520px; margin: 0 auto; background-color: #FFFFFF; border-radius: 16px; padding: 32px; border: 1px solid #F3E5E5; box-shadow: 0 4px 12px rgba(195,1,33,0.04);">
    <div style="text-align: center; margin-bottom: 24px;">
      <h1 style="font-family: Georgia, serif; color: #C30121; font-size: 26px; margin: 0;">BloodPulse</h1>
      <p style="color: #666666; font-size: 13px; margin: 4px 0 0 0;">Nationwide Blood Network • Bangladesh</p>
    </div>
    <div style="text-align: center; margin: 24px 0;">
      <p style="font-size: 15px; margin-bottom: 12px;">Use the verification code below to complete your {purpose.lower()}:</p>
      <div style="display: inline-block; background-color: #FFF8F7; border: 2px solid #C30121; border-radius: 12px; padding: 14px 28px; font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #C30121; font-family: monospace;">
        {otp_code}
      </div>
      <p style="font-size: 13px; color: #888888; margin-top: 12px;">This code will expire in <strong>{expiry_minutes} minutes</strong>.</p>
    </div>
    <div style="background-color: #FFF8F7; border-left: 4px solid #C30121; padding: 12px 16px; border-radius: 6px; font-size: 12px; color: #555555; margin-top: 24px;">
      <strong>Security notice:</strong> If you did not request this verification code, please ignore this email. BloodPulse staff will never ask for your code.
    </div>
    <div style="text-align: center; margin-top: 28px; border-top: 1px solid #F3E5E5; padding-top: 16px; font-size: 11px; color: #999999;">
      &copy; 2026 BloodPulse. Safe, voluntary, nationwide blood transfusion network.
    </div>
  </div>
</body>
</html>"""

    return text_content, html_content


class BaseEmailProvider(ABC):
    provider_name: str = "base"

    @abstractmethod
    def send_email(
        self,
        to_email: str,
        subject: str,
        text_content: str,
        html_content: Optional[str] = None,
    ) -> dict:
        """
        Sends an email. Returns dict with keys: 'success', 'status_code', 'provider'.
        Raises EmailConfigError or EmailProviderError on failure.
        """
        pass

    def send_otp(self, to_email: str, otp_code: str, purpose: str = "Verification") -> bool:
        """Helper to render template and dispatch OTP email."""
        expiry = getattr(settings, 'OTP_EXPIRY_MINUTES', 10)
        subject = f"{otp_code} is your BloodPulse {purpose.lower()} code"
        text, html = render_otp_email(otp_code, expiry_minutes=expiry, purpose=purpose)
        res = self.send_email(to_email=to_email, subject=subject, text_content=text, html_content=html)
        return res.get('success', False)


class MailjetEmailProvider(BaseEmailProvider):
    """
    Mailjet Send API v3.1 (Basic Auth)
    Endpoint: https://api.mailjet.com/v3.1/send
    Requires: MAILJET_API_KEY, MAILJET_SECRET_KEY, MAILJET_SENDER_EMAIL
    """
    provider_name = "mailjet"
    ENDPOINT = "https://api.mailjet.com/v3.1/send"
    TIMEOUT_SECONDS = 8

    def __init__(self, api_key: str = None, secret_key: str = None, sender_email: str = None, sender_name: str = None):
        self.api_key = api_key if api_key is not None else (os.getenv('MAILJET_API_KEY', '') or getattr(settings, 'MAILJET_API_KEY', ''))
        self.secret_key = secret_key if secret_key is not None else (os.getenv('MAILJET_SECRET_KEY', '') or getattr(settings, 'MAILJET_SECRET_KEY', ''))
        self.sender_email = sender_email if sender_email is not None else (os.getenv('MAILJET_SENDER_EMAIL', '') or getattr(settings, 'MAILJET_SENDER_EMAIL', ''))
        self.sender_name = sender_name if sender_name is not None else (os.getenv('MAILJET_SENDER_NAME', '') or getattr(settings, 'MAILJET_SENDER_NAME', 'BloodPulse'))

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> dict:
        masked = mask_email(to_email)
        if not self.api_key or not self.secret_key:
            logger.error("Mailjet credentials missing (MAILJET_API_KEY or MAILJET_SECRET_KEY). Cannot dispatch to %s", masked)
            raise EmailConfigError("MAILJET_API_KEY or MAILJET_SECRET_KEY missing")
        if not self.sender_email:
            logger.error("Mailjet sender email missing (MAILJET_SENDER_EMAIL). Cannot dispatch to %s", masked)
            raise EmailConfigError("MAILJET_SENDER_EMAIL missing")

        payload = {
            "Messages": [
                {
                    "From": {
                        "Email": self.sender_email,
                        "Name": self.sender_name,
                    },
                    "To": [
                        {
                            "Email": to_email,
                        }
                    ],
                    "Subject": subject,
                    "TextPart": text_content,
                    "HTMLPart": html_content or text_content,
                }
            ]
        }

        try:
            resp = requests.post(
                self.ENDPOINT,
                auth=(self.api_key, self.secret_key),
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=self.TIMEOUT_SECONDS,
            )
        except (requests.exceptions.Timeout, requests.exceptions.RequestException) as exc:
            logger.error("Mailjet API request failed for recipient %s: %s", masked, exc.__class__.__name__)
            raise EmailProviderError(f"Mailjet delivery network error: {exc.__class__.__name__}", status_code=503) from exc

        if resp.status_code == 200:
            data = resp.json()
            messages = data.get("Messages", [{}])
            msg_status = messages[0].get("Status") if messages else None
            if msg_status == "success":
                logger.info("Mailjet email dispatched successfully to %s", masked)
                return {'success': True, 'status_code': 200, 'provider': self.provider_name}
            else:
                errors = messages[0].get("Errors", [])
                logger.error("Mailjet message status '%s' for %s: %s", msg_status, masked, errors)
                raise EmailProviderError(f"Mailjet delivery status: {msg_status}", status_code=200)

        logger.error("Mailjet API returned HTTP %s for %s", resp.status_code, masked)
        raise EmailProviderError(f"Mailjet returned HTTP {resp.status_code}", status_code=resp.status_code)


class ResendEmailProvider(BaseEmailProvider):
    """
    Resend REST API (Bearer auth)
    Endpoint: https://api.resend.com/emails
    Requires: RESEND_API_KEY, RESEND_SENDER_EMAIL
    """
    provider_name = "resend"
    ENDPOINT = "https://api.resend.com/emails"
    TIMEOUT_SECONDS = 8

    def __init__(self, api_key: str = None, sender_email: str = None, sender_name: str = None):
        self.api_key = api_key if api_key is not None else (os.getenv('RESEND_API_KEY', '') or getattr(settings, 'RESEND_API_KEY', ''))
        self.sender_email = sender_email if sender_email is not None else (os.getenv('RESEND_SENDER_EMAIL', '') or getattr(settings, 'RESEND_SENDER_EMAIL', ''))
        self.sender_name = sender_name if sender_name is not None else (os.getenv('RESEND_SENDER_NAME', '') or getattr(settings, 'RESEND_SENDER_NAME', 'BloodPulse'))

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> dict:
        masked = mask_email(to_email)
        if not self.api_key:
            logger.error("RESEND_API_KEY missing. Cannot dispatch to %s", masked)
            raise EmailConfigError("RESEND_API_KEY missing")
        if not self.sender_email:
            logger.error("RESEND_SENDER_EMAIL missing. Cannot dispatch to %s", masked)
            raise EmailConfigError("RESEND_SENDER_EMAIL missing")

        from_header = f"{self.sender_name} <{self.sender_email}>" if self.sender_name else self.sender_email
        payload = {
            "from": from_header,
            "to": [to_email],
            "subject": subject,
            "text": text_content,
        }
        if html_content:
            payload["html"] = html_content

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        try:
            resp = requests.post(
                self.ENDPOINT,
                json=payload,
                headers=headers,
                timeout=self.TIMEOUT_SECONDS,
            )
        except (requests.exceptions.Timeout, requests.exceptions.RequestException) as exc:
            logger.error("Resend API request failed for recipient %s: %s", masked, exc.__class__.__name__)
            raise EmailProviderError(f"Resend delivery network error: {exc.__class__.__name__}", status_code=503) from exc

        if resp.status_code in (200, 201):
            logger.info("Resend email dispatched successfully to %s", masked)
            return {'success': True, 'status_code': resp.status_code, 'provider': self.provider_name}

        logger.error("Resend API returned HTTP %s for %s", resp.status_code, masked)
        raise EmailProviderError(f"Resend returned HTTP {resp.status_code}", status_code=resp.status_code)


class BrevoEmailProvider(BaseEmailProvider):
    """
    Brevo REST API (api-key header)
    Endpoint: https://api.brevo.com/v3/smtp/email
    Requires: BREVO_API_KEY, BREVO_SENDER_EMAIL
    """
    provider_name = "brevo"
    ENDPOINT = "https://api.brevo.com/v3/smtp/email"
    TIMEOUT_SECONDS = 8

    def __init__(self, api_key: str = None, sender_email: str = None, sender_name: str = None):
        self.api_key = api_key if api_key is not None else (os.getenv('BREVO_API_KEY', '') or getattr(settings, 'BREVO_API_KEY', ''))
        self.sender_email = sender_email if sender_email is not None else (os.getenv('BREVO_SENDER_EMAIL', '') or getattr(settings, 'BREVO_SENDER_EMAIL', ''))
        self.sender_name = sender_name if sender_name is not None else (os.getenv('BREVO_SENDER_NAME', '') or getattr(settings, 'BREVO_SENDER_NAME', 'BloodPulse'))

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> dict:
        masked = mask_email(to_email)
        if not self.api_key:
            logger.error("BREVO_API_KEY missing. Cannot dispatch to %s", masked)
            raise EmailConfigError("BREVO_API_KEY missing")
        if not self.sender_email:
            logger.error("BREVO_SENDER_EMAIL missing. Cannot dispatch to %s", masked)
            raise EmailConfigError("BREVO_SENDER_EMAIL missing")

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
            raise EmailProviderError(f"Brevo delivery network error: {exc.__class__.__name__}", status_code=503) from exc

        if resp.status_code in (200, 201, 202):
            logger.info("Brevo email dispatched successfully to %s", masked)
            return {'success': True, 'status_code': resp.status_code, 'provider': self.provider_name}

        logger.error("Brevo API returned HTTP %s for %s", resp.status_code, masked)
        raise EmailProviderError(f"Brevo returned HTTP {resp.status_code}", status_code=resp.status_code)


class ConsoleEmailProvider(BaseEmailProvider):
    """Dev-only provider. Prints masked target and subject. Refused when DEBUG is False."""
    provider_name = "console"

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> dict:
        is_debug = getattr(settings, 'DEBUG', False)
        if not is_debug:
            logger.error("Console email provider was invoked while DEBUG=False. Refusing to operate.")
            raise EmailConfigError("Console email provider is disabled when DJANGO_DEBUG=False.")

        logger.info("[ConsoleEmailProvider] Dispatched email to %s | Subject: %s", mask_email(to_email), subject)
        return {'success': True, 'status_code': 200, 'provider': self.provider_name}


class LocMemEmailProvider(BaseEmailProvider):
    """Test-only provider. Dispatches via Django EmailMultiAlternatives into mail.outbox."""
    provider_name = "locmem"

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: Optional[str] = None) -> dict:
        from_addr = (
            getattr(settings, 'DEFAULT_FROM_EMAIL', '')
            or getattr(settings, 'BREVO_SENDER_EMAIL', '')
            or 'locmem@bloodpulse.app'
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
        return {'success': True, 'status_code': 200, 'provider': self.provider_name}


class SmtpEmailProvider(BaseEmailProvider):
    """Standard SMTP Provider (e.g. Gmail App Password, Custom SMTP Relay)."""
    provider_name = "smtp"

    def send_email(
        self,
        to_email: str,
        subject: str,
        text_content: str,
        html_content: Optional[str] = None,
    ) -> dict:
        host = getattr(settings, 'SMTP_HOST', '') or os.getenv('SMTP_HOST', '')
        user = getattr(settings, 'SMTP_USER', '') or os.getenv('SMTP_USER', '')
        password = getattr(settings, 'SMTP_PASSWORD', '') or os.getenv('SMTP_PASSWORD', '')
        port = int(getattr(settings, 'SMTP_PORT', 0) or os.getenv('SMTP_PORT', 587))
        from_email = (
            getattr(settings, 'SMTP_FROM', '')
            or os.getenv('SMTP_FROM', '')
            or getattr(settings, 'DEFAULT_FROM_EMAIL', '')
            or user
        )
        use_tls = getattr(settings, 'SMTP_USE_TLS', True)

        if not host or not user or not password:
            raise EmailConfigError("SMTP configuration incomplete: SMTP_HOST, SMTP_USER, and SMTP_PASSWORD are required.")

        try:
            from django.core.mail.backends.smtp import EmailBackend
            connection = EmailBackend(
                host=host,
                port=port,
                username=user,
                password=password,
                use_tls=use_tls,
                fail_silently=False,
                timeout=10,
            )
            msg = EmailMultiAlternatives(
                subject=subject,
                body=text_content,
                from_email=from_email,
                to=[to_email],
                connection=connection,
            )
            if html_content:
                msg.attach_alternative(html_content, "text/html")
            msg.send(fail_silently=False)
            logger.info("[SmtpEmailProvider] Dispatched email to %s via %s:%s", mask_email(to_email), host, port)
            return {'success': True, 'status_code': 200, 'provider': self.provider_name}
        except Exception as exc:
            logger.error("[SmtpEmailProvider] Failed sending to %s: %s", mask_email(to_email), exc)
            raise EmailProviderError(f"SMTP send failed: {exc}", status_code=500)


def get_email_provider() -> BaseEmailProvider:
    """
    Instantiates the configured BaseEmailProvider based on EMAIL_PROVIDER setting/env.
    Allowed values: 'mailjet', 'resend', 'brevo', 'brevo_api', 'console', 'locmem'.
    """
    provider_str = (
        getattr(settings, 'EMAIL_PROVIDER', '')
        or os.getenv('EMAIL_PROVIDER', '')
    ).strip().lower()

    if provider_str == 'mailjet':
        return MailjetEmailProvider()
    elif provider_str in ('resend', 'resend_api'):
        return ResendEmailProvider()
    elif provider_str in ('brevo', 'brevo_api'):
        return BrevoEmailProvider()
    elif provider_str == 'console':
        return ConsoleEmailProvider()
    elif provider_str == 'locmem':
        return LocMemEmailProvider()
    elif provider_str in ('smtp', 'smtp_backend'):
        return SmtpEmailProvider()

    # Default fallback: if running tests or unset in dev
    if getattr(settings, 'IS_TESTING', False) or 'test' in os.sys.argv:
        return LocMemEmailProvider()
    if getattr(settings, 'DEBUG', False):
        return ConsoleEmailProvider()

    # In production without an explicit valid provider
    raise EmailConfigError(f"Invalid or unconfigured EMAIL_PROVIDER '{provider_str}'.")


def get_email_service() -> BaseEmailProvider:
    """Unified service accessor matching legacy get_email_service signature."""
    return get_email_provider()
