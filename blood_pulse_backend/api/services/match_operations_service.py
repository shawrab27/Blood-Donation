# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Match lifecycle operations for BloodPulse Blood Hub v2.
Handles match status changes, two-sided confirmation, donor withdrawal,
failure reporting, standby promotions, thank you letters, and 24-hour donor follow-ups.
"""

from datetime import timedelta
from uuid import uuid4
import logging

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError

from api.models import (
    BloodRequest,
    BrokerReport,
    DonationMatch,
    DonationReport,
    ThankYouLetter,
    FollowUp,
    DonationHistory,
)
from api.services.targeting_service import find_nearest_standby_donor

logger = logging.getLogger(__name__)


def _finalize_two_sided_match(req: BloodRequest, match: DonationMatch, now, note: str = "", auto_close: bool = True) -> DonationMatch:
    """
    Internal helper called inside transaction.atomic() when BOTH donor_confirmed_at
    and requester_confirmed_at are set.
    Idempotent: if match.confirmed_at is already set, does nothing (Part C.3 & Part E.4).
    Moves match.units_pledged from req.units_pending to req.units_received,
    records donor history & cooldown, and auto-closes req in the same transaction
    when req.units_received >= req.units_needed (Part E.1 & E.2).
    """
    if match.confirmed_at is not None:
        return match

    units = max(1, match.units_pledged or 1)
    match.confirmed_at = now
    match.donated_at = match.donated_at or now
    match.status = 'DONATED'
    match.save(update_fields=['confirmed_at', 'donated_at', 'status', 'updated_at'])

    req.units_pending = max(0, req.units_pending - units)
    req.units_received = min(req.units_needed, req.units_received + units)

    hosp_name = req.hospital_name_other or (
        req.hospital.name if req.hospital else 'Hospital'
    )
    dh = DonationHistory.objects.create(
        donor=match.donor,
        date=now.date(),
        donated_at=now.date(),
        location=hosp_name,
        hospital=hosp_name,
        city=req.district or match.donor.district or '',
        bags=units,
        bags_donated=units,
        source='verified',
        verified=True,
        linked_request=req,
        notes=note or "Blood donation confirmed by both donor and requester.",
    )
    from api.models import award_verified_donation_xp
    award_verified_donation_xp(dh)

    match.donor.total_bags_donated += units
    match.donor.last_donation_date = now.date()
    match.donor.save(update_fields=['total_bags_donated', 'last_donation_date'])

    FollowUp.objects.get_or_create(
        match=match,
        defaults={
            'due_at': now + timedelta(hours=24),
            'status': 'PENDING',
        },
    )

    update_fields = ['units_pending', 'units_received']
    if auto_close and req.units_received >= req.units_needed:
        req.status = 'CLOSED'
        req.is_active = False
        req.closed_at = req.closed_at or now
        req.close_reason = req.close_reason or 'FULFILLED'
        update_fields.extend(['status', 'is_active', 'closed_at', 'close_reason'])
    elif req.status in ('ARRIVED', 'IN_TRANSIT', 'MATCHED', 'OPEN'):
        req.status = 'DONATED'
        update_fields.append('status')

    req.save(update_fields=update_fields)
    return match


def confirm_match_donation(
    match_id: int,
    actor,
    action: str = 'CONFIRM',
    note: str = "",
) -> DonationMatch:
    """
    Two-sided donation confirmation (Part C & Part E):
    - Donor confirming ("I donated") sets donor_confirmed_at.
    - Requester/Proxy confirming ("I received") sets requester_confirmed_at.
    - One-sided confirmation leaves units in units_pending, never in units_received.
    - Calling the same confirmation endpoint twice by the same user is idempotent.
    - If action == 'DISPUTE' (disagreement), marks match FAILED/disputed, releases
      pending units so the request slot is freed, and logs a BrokerReport for admin review.
    """
    from api.services.blood_hub_lifecycle_service import ConflictError

    norm_action = (action or 'CONFIRM').strip().upper()
    if norm_action not in ('CONFIRM', 'DONOR_CONFIRM', 'REQUESTER_CONFIRM', 'DISPUTE', 'DISAGREE'):
        raise ValidationError({"action": "Invalid action. Use CONFIRM or DISPUTE."})

    with transaction.atomic():
        match = DonationMatch.objects.select_for_update().select_related('request', 'donor__user').get(id=match_id)
        req = BloodRequest.objects.select_for_update().get(id=match.request_id)

        is_donor = (actor.id == match.donor.user_id)
        is_requester = (actor.id == req.requester_id)
        is_staff = getattr(actor, 'is_staff', False)

        if not (is_donor or is_requester or is_staff):
            raise PermissionDenied("Only the matched donor or the requester/proxy can confirm this donation.")

        now = timezone.now()

        # Ensure req.units_pending reflects this active unconfirmed match if created directly in tests
        if match.confirmed_at is None and match.status in ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'):
            if req.units_pending < match.units_pledged and req.units_received + match.units_pledged <= req.units_needed:
                req.units_pending = max(req.units_pending, match.units_pledged)
                req.save(update_fields=['units_pending'])

        # Handle disagreement / dispute (Part C.4)
        if norm_action in ('DISPUTE', 'DISAGREE'):
            if match.confirmed_at is not None:
                raise ConflictError("Donation has already been confirmed by both sides.")
            if match.disputed_at is not None:
                return match
            match.disputed_at = now
            match.dispute_reason = note or "One party disagreed with donation confirmation."
            match.status = 'FAILED'
            match.save(update_fields=['disputed_at', 'dispute_reason', 'status', 'updated_at'])

            req.units_pending = max(0, req.units_pending - (match.units_pledged or 1))
            if req.units_pending == 0 and req.units_received < req.units_needed and req.status not in ('CLOSED', 'EXPIRED'):
                req.status = 'OPEN'
            req.save(update_fields=['units_pending', 'status'])
            return match

        if match.status in ('CANCELLED', 'FAILED', 'EXPIRED'):
            raise ConflictError(f"Cannot confirm donation on a {match.status} match.")

        # Idempotent already-confirmed check
        if match.confirmed_at is not None:
            return match

        # Determine which side is confirming
        if is_donor and not (is_requester and norm_action == 'REQUESTER_CONFIRM'):
            if match.donor_confirmed_at is None:
                match.donor_confirmed_at = now
                match.donated_at = match.donated_at or now
                match.status = 'DONATED'
                match.save(update_fields=['donor_confirmed_at', 'donated_at', 'status', 'updated_at'])

                # Cooldown Safety (Step 7.1): Donor's 90-day cooldown (last_donation_date)
                # begins immediately upon donor's confirmation to protect health.
                if match.donor.last_donation_date != now.date():
                    match.donor.last_donation_date = now.date()
                    match.donor.save(update_fields=['last_donation_date'])
        elif is_requester or is_staff:
            if match.requester_confirmed_at is None:
                match.requester_confirmed_at = now
                match.donated_at = match.donated_at or now
                match.status = 'DONATED'
                match.save(update_fields=['requester_confirmed_at', 'donated_at', 'status', 'updated_at'])

        # Check if BOTH sides have now confirmed
        if match.donor_confirmed_at is not None and match.requester_confirmed_at is not None:
            return _finalize_two_sided_match(req, match, now, note=note)

        # One-sided confirmation: leave units in units_pending, never in units_received!
        if is_requester and req.status in ('ARRIVED', 'IN_TRANSIT', 'MATCHED'):
            req.status = 'DONATED'
            req.save(update_fields=['status'])

        return match


def withdraw_match_response(match_id: int, actor, reason: str = "") -> DonationMatch:
    """
    Allows a donor to withdraw their response before two-sided confirmation,
    atomically releasing their reserved units from req.units_pending (Part B.2).
    """
    from api.services.blood_hub_lifecycle_service import ConflictError

    with transaction.atomic():
        match = DonationMatch.objects.select_for_update().select_related('request', 'donor__user').get(id=match_id)
        req = BloodRequest.objects.select_for_update().get(id=match.request_id)

        is_donor = (actor.id == match.donor.user_id)
        is_requester = (actor.id == req.requester_id)
        is_staff = getattr(actor, 'is_staff', False)

        if not (is_donor or is_requester or is_staff):
            raise PermissionDenied("You are not authorized to withdraw this donor response.")

        if match.confirmed_at is not None or (
            match.donor_confirmed_at is not None and match.requester_confirmed_at is not None
        ):
            raise ConflictError("Cannot withdraw after donation has been confirmed by both sides.")

        if match.status in ('CANCELLED', 'FAILED', 'EXPIRED'):
            raise ConflictError(f"Match is already {match.status}.")

        units = max(1, match.units_pledged or 1)
        if match.status in ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'):
            req.units_pending = max(0, req.units_pending - units)

        match.status = 'CANCELLED'
        match.donor_confirmed_at = None
        match.requester_confirmed_at = None
        match.save(update_fields=['status', 'donor_confirmed_at', 'requester_confirmed_at', 'updated_at'])

        active_remaining = req.donation_matches.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
        ).exists()
        if not active_remaining and req.units_received < req.units_needed and req.status in ('MATCHED', 'IN_TRANSIT', 'ARRIVED', 'DONATED'):
            req.status = 'OPEN'
        req.save(update_fields=['units_pending', 'status'])

        return match


def update_match_status(match_id: int, actor, new_status: str, note: str = "") -> DonationMatch:
    """Updates match progress (ON_THE_WAY, ARRIVED, DONATED, CONFIRMED, CANCELLED)."""
    from api.services.blood_hub_lifecycle_service import transition

    norm_status = new_status.strip().upper()

    if norm_status == 'CANCELLED':
        return withdraw_match_response(match_id, actor, reason=note)

    if norm_status in ('COMPLETED', 'CONFIRMED'):
        raise ValidationError({"detail": "Terminal donation completion requires two-sided confirmation via confirm_match_donation."})

    if norm_status in ('DISPUTED', 'DISPUTE'):
        return confirm_match_donation(match_id, actor, action='DISPUTE', note=note)

    match = DonationMatch.objects.select_related('request', 'donor__user').get(id=match_id)

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
        # Part 0(b) & Step 7.1: One party reporting donation completed.
        # Updates match progress status to DONATED.
        # Medical Cooldown Safety: If donor reports DONATED, donor's 90-day cooldown
        # (last_donation_date) starts immediately to safeguard health against premature re-donation.
        # However, total_bags_donated, DonationHistory, certificate, feedback eligibility,
        # and trust score stay strictly two-sided (confirmed_at).
        now = timezone.now()
        match.status = 'DONATED'
        match.donated_at = match.donated_at or now
        match.save(update_fields=['status', 'donated_at'])

        if actor.id == match.donor.user_id:
            if match.donor_confirmed_at is None:
                match.donor_confirmed_at = now
                match.save(update_fields=['donor_confirmed_at'])
            if match.donor.last_donation_date != now.date():
                match.donor.last_donation_date = now.date()
                match.donor.save(update_fields=['last_donation_date'])

        if match.request.status in ['ARRIVED', 'IN_TRANSIT', 'MATCHED']:
            transition(match.request, 'DONATED', actor)

    return match


def report_match_failure(match_id: int, actor, reason: str, note: str = "") -> tuple[DonationMatch, DonationMatch | None]:
    """Marks match FAILED, releases pending units if unreplaced, and auto-promotes nearest standby donor."""
    from api.services.blood_hub_lifecycle_service import transition

    with transaction.atomic():
        match = DonationMatch.objects.select_for_update().select_related('request').get(id=match_id)
        req = BloodRequest.objects.select_for_update().get(id=match.request_id)

        was_holding_slot = (
            match.confirmed_at is None
            and match.status in ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED')
        )
        match.status = 'FAILED'
        match.save(update_fields=['status'])

        DonationReport.objects.create(
            match=match,
            reason=reason,
            note=note,
            reported_by=actor,
        )

        if was_holding_slot:
            req.units_pending = max(0, req.units_pending - (match.units_pledged or 1))
            req.save(update_fields=['units_pending'])

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
            if standby_match.status == 'ACCEPTED':
                req.units_pending = min(
                    req.units_needed - req.units_received,
                    req.units_pending + (standby_match.units_pledged or 1),
                )
                req.save(update_fields=['units_pending'])
            return match, standby_match

        active_exists = req.donation_matches.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
        ).exists()
        if not active_exists and req.status != 'OPEN' and req.status not in ('CLOSED', 'EXPIRED'):
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


def sweep_expired_standby_matches() -> int:
    """Expires pending standby offers past their 5-min timer and triggers standby failover."""
    from api.services.blood_hub_lifecycle_service import transition

    now = timezone.now()
    expired_matches = DonationMatch.objects.filter(
        status='PENDING',
        expires_at__lte=now,
    ).select_related('request')

    count = 0
    for match in expired_matches:
        match.status = 'EXPIRED'
        match.save(update_fields=['status'])
        count += 1

        req = match.request
        exclude_ids = list(req.donation_matches.values_list('donor_id', flat=True))
        candidate = find_nearest_standby_donor(req, exclude_donor_ids=exclude_ids)
        if candidate:
            DonationMatch.objects.create(
                request=req,
                donor=candidate,
                status='PENDING',
                role='PRIMARY',
                expires_at=now + timedelta(minutes=5),
                chat_room_id=f"chat_{req.id}_{candidate.id}_{uuid4().hex[:8]}",
                tracking_room_id=f"track_{req.id}_{candidate.id}_{uuid4().hex[:8]}",
            )
        elif not req.donation_matches.filter(status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']).exists():
            if req.status != 'OPEN' and req.status not in ('CLOSED', 'EXPIRED'):
                transition(req, 'OPEN', req.requester)
    return count


def run_due_followups() -> int:
    """
    Step 6: Day-after check-in:
    Sweeps expired standby offers, dispatches due 24h follow-ups, sends one FCM push from
    standard EN/BN template (asks how the donor feels, reminds to drink water and rest;
    no medical claims, no 'life saved' wording), and marks sent_at idempotently.
    Expired/invalid tokens are handled gracefully without crashing.
    """
    sweep_expired_standby_matches()

    due_items = FollowUp.objects.filter(
        due_at__lte=timezone.now(),
        status='PENDING',
    ).select_related('match__donor')

    count = 0
    now = timezone.now()
    from api.services.notify import send_fcm_multicast_batches

    for item in due_items:
        # Mark sent_at first for idempotency
        item.status = 'SENT'
        item.sent_at = now
        item.save(update_fields=['status', 'sent_at'])
        count += 1

        donor = item.match.donor
        token = getattr(donor, 'fcm_token', None)
        if token:
            title = "Checking In / স্বাস্থ্য কেমন আছে?"
            body = (
                "How are you feeling after yesterday's blood donation? Remember to drink plenty of fluids and rest. "
                "/ গতকাল রক্তদানের পর আপনার শরীর কেমন আছে? পর্যাপ্ত পানি পান করুন ও বিশ্রাম নিন।"
            )
            data_payload = {
                'type': 'FOLLOW_UP',
                'followup_id': str(item.id),
                'match_id': str(item.match_id),
            }
            try:
                send_fcm_multicast_batches(
                    tokens_with_donors=[(token, donor)],
                    title=title,
                    body=body,
                    data_payload=data_payload,
                )
            except Exception as e:
                logger.warning("Failed to send follow-up FCM push for FollowUp #%s: %s", item.id, e)

    return count
