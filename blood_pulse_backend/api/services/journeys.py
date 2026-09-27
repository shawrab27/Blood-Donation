# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.utils import timezone
from datetime import timedelta
from api.models import RequestAcceptance, DonationHistory

def finalize_donation(acceptance, auto=False):
    """
    Runs the full completion pipeline for a RequestAcceptance:
    sets completed_at, fulfills the BloodRequest, updates donor
    metrics, writes DonationHistory, and starts the donor's
    recovery cooldown.

    auto=True marks this as system-closed (timeout), not requester-verified.
    """
    now = timezone.now()
    acceptance.status = 'CONFIRMED'
    acceptance.completed_at = now
    acceptance.auto_confirmed = auto
    acceptance.save(update_fields=['status', 'completed_at', 'auto_confirmed'])

    blood_req = acceptance.request
    blood_req.status = 'FULFILLED'
    blood_req.is_active = False
    blood_req.save(update_fields=['status', 'is_active'])

    donor = acceptance.donor
    donor.fulfilled_count = (donor.fulfilled_count or 0) + 1
    donor.total_bags_donated = (donor.total_bags_donated or 0) + (blood_req.units_needed or 1)
    donor.last_donation_date = now.date()
    donor.is_available = False
    donor.save(update_fields=['fulfilled_count', 'total_bags_donated', 'last_donation_date', 'is_available'])

    DonationHistory.objects.create(
        donor=donor,
        date=now.date(),
        location=blood_req.hospital_location or (blood_req.hospital.name if blood_req.hospital else 'Hospital'),
        bags_donated=blood_req.units_needed or 1,
        notes=f"Emergency requisition #{blood_req.id} fulfilled. Auto-confirmed: {auto}",
    )


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
    Enforces the 90-day cooldown policy. 
    Defers any available donor whose last_donation_date > cutoff (i.e. < 90 days ago).
    Re-enables any unavailable (and unsuspended) donor whose last_donation_date <= cutoff.
    Returns (deferred_count, reenabled_count).
    """
    now = timezone.now().date()
    cutoff = now - timedelta(days=90)

    from api.models import DonorProfile
    
    # Needs to be deferred (donated less than 90 days ago)
    newly_deferred = DonorProfile.objects.filter(
        is_available=True,
        last_donation_date__gt=cutoff
    ).update(is_available=False)

    # Needs to be re-enabled (donated 90+ days ago)
    newly_available = DonorProfile.objects.filter(
        is_available=False,
        is_suspended=False,
        last_donation_date__lte=cutoff
    ).update(is_available=True)

    return newly_deferred, newly_available
