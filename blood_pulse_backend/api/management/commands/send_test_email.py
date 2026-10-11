# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.conf import settings
from api.services.email import get_email_sender, EmailProviderError


class Command(BaseCommand):
    help = 'Sends a test email via the configured EMAIL_PROVIDER (e.g. Brevo REST API).'

    def add_arguments(self, parser):
        parser.add_argument('to_email', type=str, help='Recipient email address')

    def handle(self, *args, **options):
        to_email = options['to_email'].strip()
        provider = getattr(settings, 'EMAIL_PROVIDER', 'locmem')
        api_key = getattr(settings, 'BREVO_API_KEY', '') or ''

        self.stdout.write(f"Configured EMAIL_PROVIDER: {provider}")

        if not api_key:
            self.stdout.write(self.style.WARNING("BREVO_API_KEY missing"))
            return

        sender = get_email_sender()
        subject = "BloodPulse Test Email"
        body = "This is a test transactional email sent from BloodPulse."

        try:
            sender.send_email(to_email=to_email, subject=subject, text_content=body)
            self.stdout.write(self.style.SUCCESS(f"Successfully dispatched test email to {to_email}"))
        except EmailProviderError as e:
            if "BREVO_API_KEY missing" in str(e):
                self.stdout.write(self.style.WARNING("BREVO_API_KEY missing"))
                return
            self.stdout.write(self.style.ERROR(f"Failed to send test email: {e}"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"Unexpected error sending test email: {e}"))
