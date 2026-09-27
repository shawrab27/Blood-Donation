# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Email & OTP Service with Brevo HTTPS API.
Complies with Rule 8: Render blocks outbound SMTP ports (25, 465, 587).
Sends transactional emails strictly through Brevo's HTTPS REST API.
"""

import os
import json
import logging
import secrets
import hmac
import hashlib
import urllib.request
import urllib.error
from django.conf import settings
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)

# Daily email budget guard (well below Brevo's 300/day free limit)
EMAIL_DAILY_BUDGET = 250
OTP_EXPIRY_MINUTES = 10
OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_MAX_HOURLY_REQUESTS = 3


class EmailSender:
    """Interface for email dispatchers."""
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: str = None) -> bool:
        raise NotImplementedError


class BrevoHttpsEmailSender(EmailSender):
    """
    Sends transactional emails via Brevo HTTPS REST API v3.
    Requires BREVO_API_KEY and EMAIL_FROM environment variables.
    """
    def __init__(self, api_key: str, sender_email: str, sender_name: str = "BloodPulse"):
        self.api_key = api_key
        self.sender_email = sender_email
        self.sender_name = sender_name
        self.api_url = "https://api.brevo.com/v3/smtp/email"

    def send_email(self, to_email: str, subject: str, text_content: str, html_content: str = None) -> bool:
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

        data = json.dumps(payload).encode('utf-8')
        headers = {
            "api-key": self.api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "BloodPulse-Backend/1.0",
        }

        req = urllib.request.Request(self.api_url, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status in (200, 201, 202):
                    logger.info("Brevo HTTPS email dispatched successfully.")
                    return True
                logger.error(f"Brevo API responded with HTTP {response.status}")
                return False
        except urllib.error.HTTPError as e:
            err_body = e.read().decode('utf-8', errors='ignore')
            logger.error(f"Brevo HTTP error {e.code}: {err_body}")
            return False
        except Exception as e:
            logger.error(f"Failed to send email via Brevo HTTPS API: {e}")
            return False


class ConsoleEmailSender(EmailSender):
    """Fallback console email sender for local testing (DEBUG=True)."""
    def send_email(self, to_email: str, subject: str, text_content: str, html_content: str = None) -> bool:
        logger.info(f"[CONSOLE EMAIL] To: {to_email} | Subject: {subject} | Body: {text_content}")
        return True


def get_email_sender() -> EmailSender:
    """Factory function returning the configured EmailSender."""
    api_key = os.environ.get("BREVO_API_KEY", "").strip()
    sender_email = os.environ.get("EMAIL_FROM", "noreply@bloodpulse.org").strip()

    if api_key:
        return BrevoHttpsEmailSender(api_key=api_key, sender_email=sender_email)

    if settings.DEBUG:
        return ConsoleEmailSender()

    logger.warning("BREVO_API_KEY not configured. Falling back to ConsoleEmailSender.")
    return ConsoleEmailSender()


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
