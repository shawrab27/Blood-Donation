# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from django.core.management.base import BaseCommand
from django.utils import timezone
from api.models import DonorProfile
from api.services.geo import compute_deterministic_fuzzed_location

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Idempotently backfill deterministic public fuzzed coordinates (public_lat, public_lng) for donors"

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Recompute public coordinates even if public_lat is already populated',
        )
        parser.add_argument(
            '--batch-size',
            type=int,
            default=500,
            help='Batch size for database updates',
        )

    def handle(self, *args, **options):
        force = options.get('force', False)
        batch_size = options.get('batch_size', 500)

        qs = DonorProfile.objects.all()
        if not force:
            qs = qs.filter(public_lat__isnull=True)

        total_candidates = qs.count()
        self.stdout.write(f"Found {total_candidates} donor(s) to inspect for public fuzzed coordinates backfill.")

        updated_count = 0
        skipped_count = 0
        now = timezone.now()

        batch = []
        for donor in qs.iterator(chunk_size=batch_size):
            real_lat = donor.latitude if donor.latitude is not None else donor.last_lat
            real_lng = donor.longitude if donor.longitude is not None else donor.last_lng

            if real_lat is None or real_lng is None:
                skipped_count += 1
                continue

            fuzz_lat, fuzz_lng = compute_deterministic_fuzzed_location(
                real_lat, real_lng, donor.user_id or donor.pk
            )

            donor.public_lat = fuzz_lat
            donor.public_lng = fuzz_lng
            donor.public_geo_updated_at = now
            batch.append(donor)

            if len(batch) >= batch_size:
                DonorProfile.objects.bulk_update(
                    batch, ['public_lat', 'public_lng', 'public_geo_updated_at']
                )
                updated_count += len(batch)
                batch = []

        if batch:
            DonorProfile.objects.bulk_update(
                batch, ['public_lat', 'public_lng', 'public_geo_updated_at']
            )
            updated_count += len(batch)

        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully backfilled public coordinates: {updated_count} updated, {skipped_count} skipped (no GPS)."
            )
        )
