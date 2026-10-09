# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Match lifecycle operations for BloodPulse Blood Hub v2.
Handles match status changes, failure reporting, standby promotions,
thank you letters, and 24-hour donor follow-ups.
"""

from datetime import timedelta
from uuid import uuid4
import logging

from django.utils import timezone
from rest_framework.exceptions import ValidationError

from api.models import (
    DonationMatch,
    DonationReport,
    ThankYouLetter,
    FollowUp,
    DonationHistory,
)
from api.services.targeting_service import find_nearest_standby_donor

logger = logging.getLogger(__name__)


def update_match_status(match_id: int, actor, new_status: str, note: str = "") -> DonationMatch:
    """Updates match progress (ON_THE_WAY, ARRIVED, DONATED) and creates follow-up."""
    from api.services.blood_hub_lifecycle_service import transition

    match = DonationMatch.objects.select_related('request', 'donor__user').get(id=match_id)
    norm_status = new_status.strip().upper()

    if norm_status == 'ON_THE_WAY':
        match.status = 'ON_THE_WAY'
        match.save(update_fields=['status'])
        if match.request.status in ['MATCHED', 'OPEN']:
            transition(match.request, 'IN_TRANSIT', actor)

    elif norm_status == 'ARRIVED':
        match.status = 'ARRIVED'
        match.save(update_fields=['status'])
        if match.request.status in ['IN_TRANSIT', 'MATCHED']:
            transition(match.request, 'ARRIVED', actor)

    elif norm_status == 'DONATED':
        now = timezone.now()
        match.status = 'DONATED'
        match.donated_at = now
        match.save(update_fields=['status', 'donated_at'])

        hosp_name = match.request.hospital_name_other or (
            match.request.hospital.name if match.request.hospital else 'Hospital'
        )
        DonationHistory.objects.create(
            donor=match.donor,
            date=now.date(),
            location=hosp_name,
            bags_donated=1,
            notes=note or "Blood donation completed via BloodPulse dispatch.",
        )
        match.donor.total_bags_donated += 1
        match.donor.last_donation_date = now.date()
        match.donor.save(update_fields=['total_bags_donated', 'last_donation_date'])

        FollowUp.objects.create(
            match=match,
            due_at=now + timedelta(hours=24),
            status='PENDING',
        )
        transition(match.request, 'DONATED', actor)

    return match


def report_match_failure(match_id: int, actor, reason: str, note: str = "") -> tuple[DonationMatch, DonationMatch | None]:
    """Marks match FAILED and auto-promotes nearest standby donor with 5-min timer."""
    from api.services.blood_hub_lifecycle_service import transition

    match = DonationMatch.objects.select_related('request').get(id=match_id)
    match.status = 'FAILED'
    match.save(update_fields=['status'])

    DonationReport.objects.create(
        match=match,
        reason=reason,
        note=note,
        reported_by=actor,
    )

    req = match.request
    standby_match = req.donation_matches.filter(
        role__in=['STANDBY_1', 'STANDBY_2'],
        status__in=['ACCEPTED', 'PENDING'],
    ).first()

    if not standby_match:
        exclude_ids = list(req.donation_matches.values_list('donor_id', flat=True))
        candidate = find_nearest_standby_donor(req, exclude_donor_ids=exclude_ids)
        if candidate:
            standby_match = DonationMatch.objects.create(
                request=req,
                donor=candidate,
                status='PENDING',
                role='PRIMARY',
                expires_at=timezone.now() + timedelta(minutes=5),
                chat_room_id=f"chat_{req.id}_{candidate.id}_{uuid4().hex[:8]}",
                tracking_room_id=f"track_{req.id}_{candidate.id}_{uuid4().hex[:8]}",
            )

    if standby_match:
        standby_match.role = 'PRIMARY'
        standby_match.expires_at = timezone.now() + timedelta(minutes=5)
        standby_match.save(update_fields=['role', 'expires_at'])
        return match, standby_match

    active_exists = req.donation_matches.filter(
        status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
    ).exists()
    if not active_exists and req.status != 'OPEN':
        transition(req, 'OPEN', actor)

    return match, None


def send_thank_you_letter(match_id: int, requester, template_key: str, body: str) -> ThankYouLetter:
    """Requester sends thank you letter after donation is confirmed."""
    match = DonationMatch.objects.select_related('request').get(id=match_id)
    if match.request.requester != requester and not requester.is_staff:
        raise ValidationError({"detail": "Only the requisition owner can send a thank you letter."})
    if match.status != 'DONATED':
        raise ValidationError({"detail": "Thank you letter can only be sent after donation is confirmed."})

    letter = ThankYouLetter.objects.create(
        match=match,
        template_key=template_key or 'warm_gratitude',
        body=body.strip(),
    )
    return letter


def answer_follow_up(followup_id: int, donor_user, response_val: str, notes: str = "") -> FollowUp:
    """Answers 24h health follow-up check."""
    fu = FollowUp.objects.select_related('match__donor__user').get(id=followup_id)
    if fu.match.donor.user != donor_user and not donor_user.is_staff:
        raise ValidationError({"detail": "Only the donor can answer this follow-up."})

    fu.status = 'ANSWERED'
    fu.response = response_val
    fu.notes = notes
    fu.answered_at = timezone.now()
    fu.save(update_fields=['status', 'response', 'notes', 'answered_at'])
    return fu


def run_due_followups() -> int:
    """Dispatches due 24h follow-ups and marks them SENT."""
    due_items = FollowUp.objects.filter(
        due_at__lte=timezone.now(),
        status='PENDING',
    )
    count = 0
    now = timezone.now()
    for item in due_items:
        item.status = 'SENT'
        item.sent_at = now
        item.save(update_fields=['status', 'sent_at'])
        count += 1
    return count
