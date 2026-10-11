# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Permanent service layer for the Blood Hub request lifecycle.
Contains the strict state machine, atomic acceptance, SMTP email OTP verification,
auto-close helpers, and orchestrates match and emergency operations.
"""

from datetime import timedelta
from uuid import uuid4
import logging

from django.conf import settings
from django.core.mail import send_mail
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from api.models import (
    BloodRequest,
    DonorProfile,
    EmailOTP,
    DonationMatch,
)
from api.conf import DONOR_COOLDOWN_DAYS
from api.services.eligibility import evaluate_donor_eligibility
from api.services.email import generate_secure_otp, hash_otp, verify_otp_hash

# Re-export operations from modular service subpackages to keep each file <300 lines
from api.services.match_operations_service import (
    update_match_status,
    confirm_match_donation,
    withdraw_match_response,
    report_match_failure,
    send_thank_you_letter,
    answer_follow_up,
    run_due_followups,
)
from api.services.emergency_activation_service import (
    approve_national_emergency,
    pledge_national_emergency,
)

logger = logging.getLogger(__name__)


class IllegalStateTransitionError(Exception):
    def __init__(self, message, current_state="", target_state=""):
        super().__init__(message)
        self.current_state = current_state
        self.target_state = target_state


class ConflictError(Exception):
    pass


ALLOWED_TRANSITIONS = {
    'DRAFT': ['PENDING_EMAIL_OTP', 'CLOSED', 'FAILED'],
    'PENDING_EMAIL_OTP': ['OPEN', 'CLOSED', 'EXPIRED', 'FAILED'],
    'OPEN': ['MATCHED', 'CLOSED', 'EXPIRED', 'FAILED'],
    'MATCHED': ['IN_TRANSIT', 'OPEN', 'CLOSED', 'EXPIRED', 'FAILED'],
    'IN_TRANSIT': ['ARRIVED', 'OPEN', 'CLOSED', 'EXPIRED', 'FAILED'],
    'ARRIVED': ['DONATED', 'OPEN', 'CLOSED', 'EXPIRED', 'FAILED'],
    'DONATED': ['CLOSED'],
    'CLOSED': ['CLOSED'],
    'FAILED': ['FAILED'],
    'EXPIRED': ['EXPIRED'],
    'ACTIVE': ['MATCHED', 'CLOSED', 'EXPIRED', 'FAILED'],
}


VALID_SUPPORT_STATUSES = {
    'CAN_SUPPORT': 'CAN_SUPPORT',
    'CAN SUPPORT': 'CAN_SUPPORT',
    'VOLUNTARY_ONLY': 'VOLUNTARY_ONLY',
    'VOLUNTARY ONLY': 'VOLUNTARY_ONLY',
    'VOLUNTARY ONLY / CHARITY': 'VOLUNTARY_ONLY',
    'VOLUNTARY_ONLY_CHARITY': 'VOLUNTARY_ONLY',
}


def normalize_support_status(raw_status: str | None) -> str:
    if not raw_status:
        return 'CAN_SUPPORT'
    norm = str(raw_status).strip().upper()
    if norm not in VALID_SUPPORT_STATUSES:
        raise ValidationError({
            "support_status": "Invalid support_status. Must be CAN_SUPPORT or VOLUNTARY_ONLY."
        })
    return VALID_SUPPORT_STATUSES[norm]


def normalize_request_mode(raw_mode: str | None, patient_name: str = "", attendant_name: str = "", requester=None) -> str:
    if raw_mode:
        norm = str(raw_mode).strip().upper()
        if norm in ('SELF', 'PROXY'):
            return norm
        raise ValidationError({"request_mode": "Invalid request_mode. Must be SELF or PROXY."})
    clean_patient = (patient_name or '').strip()
    clean_attendant = (attendant_name or '').strip()
    if clean_attendant and clean_patient and clean_attendant.lower() != clean_patient.lower():
        return 'PROXY'
    if requester and clean_patient:
        req_name = (requester.first_name or requester.username or '').strip()
        if req_name and clean_patient.lower() != req_name.lower():
            return 'PROXY'
    return 'SELF'


def transition(request: BloodRequest, new_state: str, actor=None) -> BloodRequest:
    """
    State machine single entry point for BloodRequest.
    Raises IllegalStateTransitionError (maps to HTTP 409) on invalid transition.
    Idempotent when already in terminal state CLOSED/EXPIRED/FAILED.
    """
    current_state = request.status
    if current_state == new_state and new_state in ('CLOSED', 'EXPIRED', 'FAILED'):
        return request

    allowed = ALLOWED_TRANSITIONS.get(current_state, [])
    if new_state not in allowed:
        raise IllegalStateTransitionError(
            f"Cannot transition BloodRequest #{request.id} from {current_state} to {new_state}.",
            current_state=current_state,
            target_state=new_state,
        )

    now = timezone.now()
    request.status = new_state
    update_fields = ['status', 'is_active']
    if new_state in ['CLOSED', 'FAILED', 'EXPIRED']:
        request.is_active = False
        if not request.closed_at:
            request.closed_at = now
            update_fields.append('closed_at')
        if not request.close_reason:
            request.close_reason = new_state
            update_fields.append('close_reason')
    request.save(update_fields=update_fields)
    logger.info("BloodRequest #%s transitioned from %s to %s by actor %s", request.id, current_state, new_state, actor)
    return request


def auto_close_expired_requests(now=None) -> int:
    """
    Sweeps and closes expired BloodRequests safely and idempotently (Part E).
    Releases any unconfirmed pending units when expiring.
    """
    now = now or timezone.now()
    terminal_statuses = ['CLOSED', 'FULFILLED', 'EXPIRED', 'CANCELLED', 'REJECTED', 'FAILED']
    expired_qs = BloodRequest.objects.filter(
        expires_at__isnull=False,
        expires_at__lte=now,
    ).exclude(status__in=terminal_statuses)

    closed_count = 0
    for req_id in list(expired_qs.values_list('id', flat=True)):
        with transaction.atomic():
            req = BloodRequest.objects.select_for_update().get(id=req_id)
            if req.status in terminal_statuses:
                continue
            req.status = 'EXPIRED'
            req.is_active = False
            req.closed_at = req.closed_at or now
            req.close_reason = req.close_reason or 'EXPIRED'
            req.units_pending = 0
            req.save(update_fields=['status', 'is_active', 'closed_at', 'close_reason', 'units_pending'])
            closed_count += 1
    return closed_count


def create_draft_request(requester, data: dict) -> BloodRequest:
    """Creates a BloodRequest in initial DRAFT state."""
    blood_group = data.get('blood_group', '').strip().upper()
    units_needed = int(data.get('units_needed', 1))
    hospital = data.get('hospital')
    hospital_name_other = data.get('hospital_name_other', '').strip()

    if not blood_group:
        raise ValidationError({"blood_group": "Blood group is required."})
    if units_needed < 1 or units_needed > 5:
        raise ValidationError({"units_needed": "units_needed must be between 1 and 5."})
    if not hospital and not hospital_name_other:
        raise ValidationError({"hospital": "Hospital selection or custom hospital name is required."})

    patient_name = data.get('patient_name', '')
    attendant_name = data.get('attendant_name', '')
    request_mode = normalize_request_mode(
        data.get('request_mode'),
        patient_name=patient_name,
        attendant_name=attendant_name,
        requester=requester,
    )

    urgency = data.get('urgency', 'CRITICAL_2H')
    expires_at = data.get('expires_at')
    if not expires_at:
        expiry_hours = {
            'CRITICAL_2H': 6,
            'URGENT_6H': 12,
            'TODAY_24H': 24,
            'SCHEDULED': 72,
        }.get(urgency, 24)
        expires_at = timezone.now() + timedelta(hours=expiry_hours)

    req = BloodRequest.objects.create(
        requester=requester,
        patient_name=patient_name,
        blood_group=blood_group,
        units_needed=units_needed,
        units_received=0,
        units_pending=0,
        request_mode=request_mode,
        component=data.get('component', 'WHOLE'),
        urgency=urgency,
        needed_by=data.get('needed_by'),
        expires_at=expires_at,
        condition_category=data.get('condition_category', 'OTHER'),
        condition_note=data.get('condition_note', ''),
        scope=data.get('scope', 'LOCAL'),
        effective_scope=data.get('scope', 'LOCAL'),
        division=data.get('division'),
        district=data.get('district', ''),
        upazila=data.get('upazila'),
        hospital=hospital,
        hospital_name_other=hospital_name_other,
        ward_bed=data.get('ward_bed', ''),
        attendant_name=attendant_name,
        contact_phone=data.get('contact_phone', ''),
        contact_number=data.get('contact_number', '') or data.get('contact_phone', ''),
        lat=data.get('lat'),
        lng=data.get('lng'),
        patient_photo=data.get('patient_photo'),
        requisition_slip=data.get('requisition_slip'),
        status='DRAFT',
    )
    return req


def send_request_otp(blood_request: BloodRequest, email: str = None) -> EmailOTP:
    """Generates and dispatches 6-digit OTP code to requester's email via SMTP."""
    target_email = (email or (blood_request.requester.email if blood_request.requester else '')).strip().lower()
    if not target_email:
        raise ValidationError({"email": "Email address is required to dispatch OTP."})

    last_otp = EmailOTP.objects.filter(request=blood_request, purpose='request_submit').first()
    if last_otp and not last_otp.resend_cooldown_passed(cooldown_seconds=60):
        raise ValidationError({"detail": "Please wait 60 seconds before requesting a new OTP."})

    code = generate_secure_otp(length=6)
    code_hash = hash_otp(code, target_email)
    now = timezone.now()

    otp_record = EmailOTP.objects.create(
        request=blood_request,
        email=target_email,
        otp_hash=code_hash,
        expires_at=now + timedelta(minutes=10),
        last_sent_at=now,
        purpose='request_submit',
    )

    host_user = getattr(settings, 'EMAIL_HOST_USER', '')
    host_pass = getattr(settings, 'EMAIL_HOST_PASSWORD', '')
    if host_user and host_pass:
        try:
            send_mail(
                subject="BloodPulse Requisition Verification Code",
                message=(
                    f"Your BloodPulse requisition OTP is: {code}\n\n"
                    f"This code will expire in 10 minutes.\n"
                    "If you did not initiate this request, please disregard."
                ),
                from_email=settings.DEFAULT_FROM_EMAIL or host_user,
                recipient_list=[target_email],
                fail_silently=False,
            )
        except Exception:
            logger.error("Failed to dispatch requisition OTP email.")

    transition(blood_request, 'PENDING_EMAIL_OTP', blood_request.requester)
    return otp_record


def verify_request_otp(blood_request: BloodRequest, otp_code: str) -> bool:
    """Verifies OTP code and transitions request to OPEN for broadcast."""
    otp_record = EmailOTP.objects.filter(
        request=blood_request,
        purpose='request_submit',
        is_used=False,
    ).order_by('-created_at').first()

    if not otp_record or timezone.now() > otp_record.expires_at:
        raise ValidationError({"detail": "Invalid or expired OTP code."})

    if otp_record.is_locked():
        raise ValidationError({"detail": "Maximum attempts reached. Please request a new code."})

    if not verify_otp_hash(otp_code, otp_record.otp_hash, otp_record.email):
        otp_record.attempts += 1
        otp_record.save(update_fields=['attempts'])
        raise ValidationError({"detail": "Invalid verification code."})

    otp_record.is_used = True
    otp_record.save(update_fields=['is_used'])
    transition(blood_request, 'OPEN', blood_request.requester)
    return True


def accept_request(
    blood_request_id: int,
    donor_user,
    support_status: str = 'CAN_SUPPORT',
    units_pledged: int = 1,
) -> DonationMatch:
    """
    Atomic acceptance of a blood request by a donor (Part A & Part B).
    - Enforces Donor Support Status (CAN_SUPPORT | VOLUNTARY_ONLY).
    - Enforces donor eligibility (90-day DONOR_COOLDOWN_DAYS from api/conf.py,
      is_available, is_suspended, alert_pause_until snooze, user_intent).
    - Uses select_for_update() inside transaction.atomic() to enforce
      units_received + units_pending <= units_needed.
    - Prevents duplicate response by the same donor via DB unique constraint + ConflictError.
    """
    donor_profile = getattr(donor_user, 'donorprofile', None)
    if not donor_profile:
        donor_profile = DonorProfile.objects.filter(user=donor_user).first()
    if not donor_profile:
        raise ValidationError({"detail": "Donor profile not found."})

    norm_support = normalize_support_status(support_status)
    try:
        units_val = int(units_pledged or 1)
    except (TypeError, ValueError):
        raise ValidationError({"units_pledged": "units_pledged must be a valid integer."})
    if units_val < 1 or units_val > 5:
        raise ValidationError({"units_pledged": "units_pledged must be between 1 and 5."})

    with transaction.atomic():
        req = BloodRequest.objects.select_for_update().get(id=blood_request_id)

        # Auto-expire if past expires_at
        now = timezone.now()
        if req.expires_at and req.expires_at <= now and req.status not in ('CLOSED', 'FULFILLED', 'EXPIRED'):
            req.status = 'EXPIRED'
            req.is_active = False
            req.closed_at = req.closed_at or now
            req.close_reason = req.close_reason or 'EXPIRED'
            req.units_pending = 0
            req.save(update_fields=['status', 'is_active', 'closed_at', 'close_reason', 'units_pending'])
            raise ConflictError("This blood request has expired and is closed.")

        if req.status in ('CLOSED', 'FULFILLED', 'EXPIRED', 'CANCELLED', 'REJECTED', 'FAILED') or not req.is_active:
            raise ConflictError(f"Request is closed and cannot accept new responses (status: '{req.status}').")

        if req.status not in ['OPEN', 'MATCHED', 'IN_TRANSIT', 'ARRIVED', 'ACTIVE']:
            raise ConflictError(f"Request cannot be accepted in status '{req.status}'.")

        if req.requester_id and req.requester_id == donor_user.id:
            raise ValidationError({"detail": "You cannot respond as a donor to your own blood request."})

        # Evaluate full donor eligibility (cooldown from api/conf.py, is_available, is_suspended, snooze, user_intent)
        elig = evaluate_donor_eligibility(donor_profile, req.component or 'WHOLE')
        if not elig['is_eligible']:
            raise ConflictError(elig['reason'])

        # Check duplicate response from the same donor first
        existing_match = req.donation_matches.filter(donor=donor_profile).first()
        if existing_match and existing_match.status != 'PENDING':
            raise ConflictError("You have already responded to this request.")

        # Reconcile units_pending with existing active matches if legacy test created BloodRequest directly
        active_matches_qs = req.donation_matches.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED']
        )
        db_pending_units = sum(m.units_pledged for m in active_matches_qs)
        effective_pending = max(req.units_pending, db_pending_units)

        # Enforce invariant: units_received + units_pending <= units_needed
        if req.units_received + effective_pending + units_val > req.units_needed:
            raise ConflictError("All requested units for this requisition are already filled.")

        req.units_pending = effective_pending + units_val
        req.save(update_fields=['units_pending'])

        if existing_match and existing_match.status == 'PENDING':
            existing_match.status = 'ACCEPTED'
            existing_match.role = 'PRIMARY'
            existing_match.support_status = norm_support
            existing_match.units_pledged = units_val
            existing_match.accepted_at = now
            existing_match.save(
                update_fields=['status', 'role', 'support_status', 'units_pledged', 'accepted_at', 'updated_at']
            )
            match = existing_match
        else:
            try:
                match = DonationMatch.objects.create(
                    request=req,
                    donor=donor_profile,
                    status='ACCEPTED',
                    role='PRIMARY',
                    support_status=norm_support,
                    units_pledged=units_val,
                    accepted_at=now,
                    chat_room_id=f"chat_{req.id}_{donor_profile.id}_{uuid4().hex[:8]}",
                    tracking_room_id=f"track_{req.id}_{donor_profile.id}_{uuid4().hex[:8]}",
                )
            except IntegrityError:
                raise ConflictError("You have already responded to this request.")

        from api.models import RequestAcceptance
        RequestAcceptance.objects.update_or_create(
            request=req,
            donor=donor_profile,
            defaults={
                'status': 'ACCEPTED',
                'support_status': norm_support,
                'units_pledged': units_val,
            },
        )

        if req.status in ('OPEN', 'ACTIVE'):
            transition(req, 'MATCHED', donor_user)

    return match
