# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
from django.core.management.base import BaseCommand
from api.models import BloodRequest, RequestAcceptance, DonationMatch, RequestTimelineEvent


class Command(BaseCommand):
    help = (
        "Staff-only cleanup command for demo journeys created via seed_journey_demo (Part 8).\n"
        "REFUSES unless ALLOW_TEST_SEED=true in environment."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--request-id',
            type=int,
            default=None,
            help='Specific demo BloodRequest ID to clean up (optional).',
        )

    def handle(self, *args, **options):
        if os.environ.get('ALLOW_TEST_SEED') != 'true':
            self.stderr.write(self.style.ERROR(
                "ABORTED: cleanup_journey_demo refused. Environment variable ALLOW_TEST_SEED=true is required."
            ))
            sys.exit(1)

        from django.conf import settings
        db_host = settings.DATABASES.get('default', {}).get('HOST', '')
        if 'neon.tech' in db_host or 'aws.neon.tech' in db_host:
            self.stderr.write(self.style.ERROR(
                "ABORTED: cleanup_journey_demo refused on production database host."
            ))
            sys.exit(1)

        req_id = options.get('request_id')
        if req_id:
            qs = BloodRequest.objects.filter(pk=req_id, is_drill=True)
        else:
            qs = BloodRequest.objects.filter(is_drill=True, patient_name__icontains="Demo Patient")

        count = qs.count()
        if count == 0:
            self.stdout.write(self.style.NOTICE("No demo journeys found to clean up."))
            return

        for req in qs:
            req_id_val = req.id
            RequestTimelineEvent.objects.filter(request=req).delete()
            RequestAcceptance.objects.filter(request=req).delete()
            DonationMatch.objects.filter(request=req).delete()
            req.delete()
            self.stdout.write(f"Cleaned up Demo Request #{req_id_val}")

        self.stdout.write(self.style.SUCCESS(f"Cleaned up {count} demo journey(s) successfully."))
