# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import timedelta
from django.db import transaction
from django.utils import timezone
from api.conf import DONOR_COOLDOWN_DAYS
from api.models import BloodRequest, RequestAcceptance, DonationHistory


def finalize_donation(acceptance, auto=False):
    """
    Runs the full completion pipeline for a RequestAcceptance:
    sets completed_at, increments units_received (and auto-closes the BloodRequest
    when units_received >= units_needed inside the same transaction), updates donor
    metrics, writes DonationHistory, and starts the donor's recovery cooldown.

    Idempotent when called multiple times on an already CONFIRMED acceptance.
    auto=True marks this as system-closed (timeout), not requester-verified.
    """
    now = timezone.now()
    with transaction.atomic():
        locked_acc = RequestAcceptance.objects.select_for_update().select_related('donor').get(pk=acceptance.pk)
        blood_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)

        if locked_acc.status == 'CONFIRMED' and locked_acc.completed_at is not None:
            acceptance.status = locked_acc.status
            acceptance.completed_at = locked_acc.completed_at
            acceptance.auto_confirmed = locked_acc.auto_confirmed
            return locked_acc

        units = max(1, locked_acc.units_pledged or 1)
        locked_acc.status = 'CONFIRMED'
        locked_acc.completed_at = now
        locked_acc.auto_confirmed = auto
        if not locked_acc.donor_confirmed_at:
            locked_acc.donor_confirmed_at = locked_acc.donated_at or now
        if not locked_acc.requester_confirmed_at and not auto:
            locked_acc.requester_confirmed_at = now
        locked_acc.save(
            update_fields=[
                'status',
                'completed_at',
                'auto_confirmed',
                'donor_confirmed_at',
                'requester_confirmed_at',
            ]
        )

        blood_req.units_pending = max(0, blood_req.units_pending - units)
        blood_req.units_received = min(blood_req.units_needed, blood_req.units_received + units)
        req_update_fields = ['units_pending', 'units_received']

        if blood_req.units_received >= blood_req.units_needed:
            blood_req.status = 'FULFILLED'
            blood_req.is_active = False
            blood_req.closed_at = blood_req.closed_at or now
            blood_req.close_reason = blood_req.close_reason or 'FULFILLED'
            req_update_fields.extend(['status', 'is_active', 'closed_at', 'close_reason'])
        blood_req.save(update_fields=req_update_fields)

        donor = locked_acc.donor
        donor.fulfilled_count = (donor.fulfilled_count or 0) + 1
        donor.total_bags_donated = (donor.total_bags_donated or 0) + units
        donor.last_donation_date = now.date()
        donor.is_available = False
        donor.save(update_fields=['fulfilled_count', 'total_bags_donated', 'last_donation_date', 'is_available'])

        hosp = blood_req.hospital_location or (blood_req.hospital.name if blood_req.hospital else 'Hospital')
        dh = DonationHistory.objects.create(
            donor=donor,
            date=now.date(),
            donated_at=now.date(),
            location=hosp,
            hospital=hosp,
            city=blood_req.district or donor.district or '',
            bags=units,
            bags_donated=units,
            source='verified' if not auto else 'self_reported',
            verified=not auto,
            linked_request=blood_req,
            notes=f"Emergency requisition #{blood_req.id} fulfilled. Auto-confirmed: {auto}",
        )
        if not auto:
            from api.models import award_verified_donation_xp
            award_verified_donation_xp(dh)
            from django.core.cache import cache
            cache.delete('top_donors_v2')
            cache.delete('global_rank_v2')

        acceptance.status = locked_acc.status
        acceptance.completed_at = locked_acc.completed_at
        acceptance.auto_confirmed = locked_acc.auto_confirmed
        return locked_acc


def auto_confirm_stale_donations(hours=48):
    """
    Finds journeys stuck in DONATED past the grace period and
    closes them automatically, crediting the donor even if the
    requester never came back to confirm.
    Returns the list of acceptances that were closed, for logging.
    """
    cutoff = timezone.now() - timedelta(hours=hours)
    stale = RequestAcceptance.objects.filter(
        status='DONATED',
        donated_at__isnull=False,
        donated_at__lte=cutoff,
    )
    closed = list(stale)
    for acceptance in stale:
        finalize_donation(acceptance, auto=True)
    return closed


def auto_manage_deferrals():
    """
    Enforces the DONOR_COOLDOWN_DAYS policy from api/conf.py.
    Defers any available donor whose last_donation_date > cutoff.
    Re-enables any unavailable (and unsuspended) donor whose last_donation_date <= cutoff.
    Returns (deferred_count, reenabled_count).
    """
    now = timezone.now().date()
    cutoff = now - timedelta(days=DONOR_COOLDOWN_DAYS)

    from api.models import DonorProfile

    # Needs to be deferred (donated less than DONOR_COOLDOWN_DAYS ago)
    newly_deferred = DonorProfile.objects.filter(
        is_available=True,
        last_donation_date__gt=cutoff,
    ).update(is_available=False)

    # Needs to be re-enabled (donated DONOR_COOLDOWN_DAYS+ days ago)
    newly_available = DonorProfile.objects.filter(
        is_available=False,
        is_suspended=False,
        last_donation_date__lte=cutoff,
    ).update(is_available=True)

    return newly_deferred, newly_available
