# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import logging
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.core.files.storage import default_storage

from api.models import DirectMessage
from api.services.storage import get_media_storage

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Cleans up deleted, orphaned, or expired chat voice messages from storage."

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Report files that would be cleaned up without deleting them.',
        )
        parser.add_argument(
            '--days',
            type=int,
            default=7,
            help='Retention period in days for active voice messages (default 7 days).',
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        days = options.get('days', 7)
        cutoff = timezone.now() - timedelta(days=days)

        self.stdout.write(f"Scanning voice messages older than {days} days (cutoff: {cutoff})...")

        # 1. Clean up voice messages older than retention period
        expired_messages = DirectMessage.objects.filter(
            message_type='VOICE',
            voice_url__isnull=False,
            created_at__lt=cutoff,
        )

        expired_count = expired_messages.count()
        self.stdout.write(f"Found {expired_count} expired voice messages.")

        storage = get_media_storage()
        deleted_files = 0
        for msg in expired_messages:
            if msg.voice_url:
                if not dry_run:
                    try:
                        storage.delete_file(msg.voice_url, resource_type="video")
                        deleted_files += 1
                    except Exception as e:
                        logger.warning("Failed to delete voice file %s: %s", msg.voice_url, e)

                    try:
                        if '/media/' in msg.voice_url:
                            rel_path = msg.voice_url.split('/media/')[-1]
                            if default_storage.exists(rel_path):
                                default_storage.delete(rel_path)
                    except Exception:
                        pass
                else:
                    deleted_files += 1

        if not dry_run:
            expired_messages.update(voice_url=None)
            self.stdout.write(self.style.SUCCESS(f"Cleaned up {deleted_files} voice files from storage."))
        else:
            self.stdout.write(f"[Dry Run] Would clean up {deleted_files} voice files.")
