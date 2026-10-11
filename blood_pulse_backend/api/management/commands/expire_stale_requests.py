"""
Management command to expire stale blood requests (Part E).
Safe when run twice (idempotent).
"""

from django.core.management.base import BaseCommand
from api.services.blood_hub_lifecycle_service import auto_close_expired_requests


class Command(BaseCommand):
    help = "Auto-close expired blood requests where expires_at <= now() safely and idempotently."

    def handle(self, *args, **options):
        closed_count = auto_close_expired_requests()
        self.stdout.write(
            self.style.SUCCESS(f"Successfully closed {closed_count} expired blood request(s).")
        )
