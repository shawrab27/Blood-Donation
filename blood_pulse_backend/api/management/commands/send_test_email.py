# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.conf import settings
from api.services.email_service import (
    get_email_service,
    EmailConfigError,
    EmailProviderError,
    EmailDeliveryError,
    mask_email,
)


class Command(BaseCommand):
    help = 'Sends one real test email via configured EMAIL_PROVIDER HTTPS REST API (Mailjet, Resend, Brevo, Console, LocMem).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--to',
            dest='to_email_opt',
            type=str,
            default=None,
            help='Recipient email address (e.g. --to recipient@example.com)',
        )
        parser.add_argument(
            'to_email',
            nargs='?',
            type=str,
            default=None,
            help='Optional positional recipient email address',
        )

    def handle(self, *args, **options):
        to_email = (options.get('to_email_opt') or options.get('to_email') or '').strip()
        if not to_email:
            self.stdout.write(self.style.ERROR("Error: Recipient email is required. Use: send_test_email --to <email>"))
            return

        provider_name = (getattr(settings, 'EMAIL_PROVIDER', '') or 'unconfigured').lower()
        self.stdout.write(f"Provider: {provider_name}")

        try:
            service = get_email_service()
        except EmailConfigError as exc:
            self.stdout.write(self.style.ERROR(f"Status: Failure (Config Error - {exc})"))
            return
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f"Status: Failure ({exc.__class__.__name__})"))
            return

        subject = "BloodPulse Test Email"
        text_content = (
            "This is a test transactional email dispatched via the BloodPulse HTTPS email API service.\n"
            "If you received this message, your email provider configuration is working correctly."
        )

        try:
            res = service.send_email(
                to_email=to_email,
                subject=subject,
                text_content=text_content,
            )
            http_status = res.get('status_code', 200) if isinstance(res, dict) else 200
            self.stdout.write(self.style.SUCCESS(f"Status: Success (HTTP {http_status})"))
            self.stdout.write(f"Recipient: {mask_email(to_email)}")
        except EmailConfigError as exc:
            self.stdout.write(self.style.ERROR(f"Status: Failure (Config Error - {exc})"))
        except EmailProviderError as exc:
            http_status = getattr(exc, 'status_code', 503) or 503
            self.stdout.write(self.style.ERROR(f"Status: Failure (HTTP {http_status})"))
        except EmailDeliveryError as exc:
            self.stdout.write(self.style.ERROR(f"Status: Failure ({exc.__class__.__name__})"))
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f"Status: Failure ({exc.__class__.__name__})"))

