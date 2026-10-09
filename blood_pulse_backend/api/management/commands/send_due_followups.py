# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Management command to send scheduled 24-hour post-donation follow-ups to donors.
"""

from django.core.management.base import BaseCommand
from api.services.match_operations_service import run_due_followups


class Command(BaseCommand):
    help = "Dispatches due 24-hour post-donation wellness checks to donors."

    def handle(self, *args, **options):
        self.stdout.write("Checking for due post-donation follow-ups...")
        count = run_due_followups()
        self.stdout.write(self.style.SUCCESS(f"Successfully processed and dispatched {count} follow-up check(s)."))
