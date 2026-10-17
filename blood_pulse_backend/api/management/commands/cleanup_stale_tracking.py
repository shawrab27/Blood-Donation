# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Management command to clean up stale tracking states, expired standby offers,
and donor no-show journeys.
"""

from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db import transaction

from api.models import RequestAcceptance, StandbyOffer, BloodRequest
from api.conf import (
    STANDBY_TIMEOUT_MINUTES,
    JOURNEY_NO_SHOW_TIMEOUT_MINUTES,
)
from api.services.journeys import auto_confirm_stale_donations
from api.services.standby import trigger_standby_donor_offer


class Command(BaseCommand):
    help = (
        "Cleans up stale journey tracking, auto-expires unresponded standby offers, "
        "auto-promotes replacement standby donors, and auto-confirms stale donations."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--timeout-minutes',
            type=int,
            default=JOURNEY_NO_SHOW_TIMEOUT_MINUTES,
            help=f"Minutes of inactivity before an unmoving journey is marked no-show (default {JOURNEY_NO_SHOW_TIMEOUT_MINUTES}m).",
        )
        parser.add_argument(
            '--auto-confirm-hours',
            type=int,
            default=48,
            help="Hours before unconfirmed DONATED journeys are auto-completed (default 48h).",
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            default=False,
            help="Simulate cleanup and print counts without modifying the database.",
        )

    def handle(self, *args, **options):
        timeout_minutes = options['timeout_minutes']
        auto_confirm_hours = options['auto_confirm_hours']
        dry_run = options['dry_run']
        now = timezone.now()

        prefix = "[DRY-RUN] " if dry_run else ""
        self.stdout.write(f"{prefix}Starting stale tracking and standby cleanup at {now.isoformat()}...")

        # ── 1. Expire Stale Standby Offers & Trigger Next ────────────────────────
        expired_offers_qs = StandbyOffer.objects.filter(
            status='PENDING',
            expires_at__lte=now,
        ).select_related('request', 'donor')

        expired_count = expired_offers_qs.count()
        promoted_count = 0

        if not dry_run:
            for offer in expired_offers_qs:
                with transaction.atomic():
                    offer.status = 'EXPIRED'
                    offer.save(update_fields=['status'])

                    # Auto-promote next candidate
                    next_offer = trigger_standby_donor_offer(
                        offer.request,
                        exclude_donor_ids=[offer.donor_id],
                    )
                    if next_offer:
                        promoted_count += 1
        self.stdout.write(f"{prefix}Expired Standby Offers: {expired_count} (Promoted next: {promoted_count})")

        # ── 2. Handle No-Show Inactive Journeys ─────────────────────────────────
        cutoff_time = now - timedelta(minutes=timeout_minutes)
        stale_journeys_qs = RequestAcceptance.objects.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY'],
            started_at__lte=cutoff_time,
        ).filter(
            last_location_update__isnull=True
        ) | RequestAcceptance.objects.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY'],
            last_location_update__lte=cutoff_time,
        )

        stale_journeys_count = stale_journeys_qs.count()
        replaced_count = 0

        if not dry_run:
            for acc in stale_journeys_qs:
                with transaction.atomic():
                    locked_acc = RequestAcceptance.objects.select_for_update().get(pk=acc.pk)
                    if locked_acc.status not in ['ACCEPTED', 'ON_THE_WAY']:
                        continue

                    locked_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)
                    locked_acc.status = 'FAILED'
                    locked_acc.cancellation_reason = f"Automated no-show timeout ({timeout_minutes}m inactivity)"
                    locked_acc.completed_at = now
                    locked_acc.save(update_fields=['status', 'cancellation_reason', 'completed_at'])

                    # Penalize donor no-show
                    donor = locked_acc.donor
                    donor.no_show_count = (donor.no_show_count or 0) + 1
                    donor.save(update_fields=['no_show_count'])

                    # Release pending unit count if needed
                    if not locked_acc.is_standby and locked_req.units_pending > 0:
                        locked_req.units_pending = max(0, locked_req.units_pending - max(1, locked_acc.units_pledged or 1))
                        locked_req.save(update_fields=['units_pending'])

                    # Trigger standby offer
                    replacement = trigger_standby_donor_offer(
                        locked_req,
                        exclude_donor_ids=[donor.id],
                    )
                    if replacement:
                        replaced_count += 1

        self.stdout.write(f"{prefix}Timed-out No-Show Journeys: {stale_journeys_count} (Standby activated: {replaced_count})")

        # ── 3. Auto-Confirm Stale Donations ────────────────────────────────────
        auto_confirmed_list = []
        if not dry_run:
            auto_confirmed_list = auto_confirm_stale_donations(hours=auto_confirm_hours)
        else:
            cutoff_donated = now - timedelta(hours=auto_confirm_hours)
            auto_confirmed_list = list(RequestAcceptance.objects.filter(
                status='DONATED',
                donated_at__isnull=False,
                donated_at__lte=cutoff_donated,
            ))

        self.stdout.write(f"{prefix}Auto-Confirmed Stale Donations: {len(auto_confirmed_list)}")
        self.stdout.write(self.style.SUCCESS(f"{prefix}Cleanup completed successfully."))
