# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from api.models import MediaUploadRecord
from api.services.storage import get_media_storage

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = "Cleans up orphan uploaded media (>24 hours old and not attached to any post)."

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Report orphan media records without deleting them.',
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        cutoff = timezone.now() - timedelta(hours=24)
        orphans = MediaUploadRecord.objects.filter(post__isnull=True, created_at__lt=cutoff)
        count = orphans.count()

        self.stdout.write(f"Found {count} orphan media records older than 24h.")
        if dry_run:
            self.stdout.write("Dry run completed. No media deleted.")
            return

        storage = get_media_storage()
        deleted_count = 0
        for record in orphans:
            try:
                storage.delete_image(record.public_id)
            except Exception as e:
                logger.warning("Failed to delete media %s from remote storage: %s", record.public_id, e)
            record.delete()
            deleted_count += 1

        self.stdout.write(self.style.SUCCESS(f"Successfully cleaned up {deleted_count} orphan media records."))
