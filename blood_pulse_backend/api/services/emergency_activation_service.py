# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
National emergency activation and pledge service for BloodPulse.
Enforces 2-admin activation requirement and decrements donation slot capacity.
"""

from datetime import timedelta
from uuid import uuid4
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from api.models import (
    NationalEmergencyEvent,
    DisasterPledge,
    DonationSlot,
    DonorProfile,
)
from api.conf import DONOR_COOLDOWN_DAYS


def approve_national_emergency(event_id: int, admin_user) -> NationalEmergencyEvent:
    """Records admin approval. Activates ONLY when 2 DIFFERENT admins approve."""
    if not admin_user.is_staff:
        raise ValidationError({"detail": "Only admin staff can approve national emergency events."})

    event = NationalEmergencyEvent.objects.get(id=event_id)
    if not event.approved_by_admin_1:
        event.approved_by_admin_1 = admin_user
    elif event.approved_by_admin_1 == admin_user:
        raise ValidationError({"detail": "Two different admins are strictly required for activation."})
    elif not event.approved_by_admin_2:
        event.approved_by_admin_2 = admin_user
        event.active = True
        event.is_active = True
        event.activated_at = timezone.now()

    event.save()
    return event


def pledge_national_emergency(event_id: int, donor_profile: DonorProfile, slot_id: int = None) -> DisasterPledge:
    """Creates a disaster pledge and decrements available slot capacity."""
    event = NationalEmergencyEvent.objects.get(id=event_id)
    if not event.active and not event.is_active:
        raise ValidationError({"detail": "This national emergency event is not active."})

    if donor_profile.last_donation_date:
        cooldown_cutoff = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS)
        if donor_profile.last_donation_date > cooldown_cutoff:
            raise ValidationError({"detail": "You are currently on 90-day donation cooldown."})

    slot = None
    if slot_id:
        slot = DonationSlot.objects.filter(id=slot_id).first()
    else:
        point = event.points.first()
        if point:
            slot = point.slots.first()

    if not slot:
        raise ValidationError({"detail": "No donation slot available for this disaster pledge."})

    if slot.pledged >= slot.capacity:
        raise ValidationError({"detail": "Selected donation slot is already at full capacity."})

    slot.pledged += 1
    slot.save(update_fields=['pledged'])

    pledge = DisasterPledge.objects.create(
        event=event,
        donor=donor_profile,
        slot=slot,
        pledge_code=uuid4().hex[:8].upper(),
        status='PENDING',
    )
    return pledge
