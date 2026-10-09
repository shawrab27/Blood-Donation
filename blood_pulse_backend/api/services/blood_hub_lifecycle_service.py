# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Permanent service layer for the Blood Hub request lifecycle.
Contains the strict state machine, atomic acceptance, SMTP email OTP verification,
and orchestrates match and emergency operations.
"""

from datetime import timedelta
from uuid import uuid4
import logging

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from api.models import (
    BloodRequest,
    DonorProfile,
    EmailOTP,
    DonationMatch,
)
from api.conf import DONOR_COOLDOWN_DAYS
from api.services.email import generate_secure_otp, hash_otp, verify_otp_hash

# Re-export operations from modular service subpackages to keep each file <300 lines
from api.services.match_operations_service import (
    update_match_status,
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
    'MATCHED': ['IN_TRANSIT', 'OPEN', 'CLOSED', 'FAILED'],
    'IN_TRANSIT': ['ARRIVED', 'OPEN', 'CLOSED', 'FAILED'],
    'ARRIVED': ['DONATED', 'OPEN', 'CLOSED', 'FAILED'],
    'DONATED': ['CLOSED'],
    'CLOSED': [],
    'FAILED': [],
    'EXPIRED': [],
    'ACTIVE': ['MATCHED', 'CLOSED', 'EXPIRED', 'FAILED'],
}


def transition(request: BloodRequest, new_state: str, actor=None) -> BloodRequest:
    """
    State machine single entry point for BloodRequest.
    Raises IllegalStateTransitionError (maps to HTTP 409) on invalid transition.
    """
    current_state = request.status
    allowed = ALLOWED_TRANSITIONS.get(current_state, [])
    if new_state not in allowed:
        raise IllegalStateTransitionError(
            f"Cannot transition BloodRequest #{request.id} from {current_state} to {new_state}.",
            current_state=current_state,
            target_state=new_state,
        )

    request.status = new_state
    if new_state in ['CLOSED', 'FAILED', 'EXPIRED']:
        request.is_active = False
    request.save(update_fields=['status', 'is_active'])
    logger.info("BloodRequest #%s transitioned from %s to %s by actor %s", request.id, current_state, new_state, actor)
    return request


def create_draft_request(requester, data: dict) -> BloodRequest:
    """Creates a BloodRequest in initial DRAFT state."""
    blood_group = data.get('blood_group', '').strip().upper()
    units_needed = int(data.get('units_needed', 1))
    hospital = data.get('hospital')
    hospital_name_other = data.get('hospital_name_other', '').strip()

    if not blood_group:
        raise ValidationError({"blood_group": "Blood group is required."})
    if units_needed < 1:
        raise ValidationError({"units_needed": "At least 1 unit is required."})
    if not hospital and not hospital_name_other:
        raise ValidationError({"hospital": "Hospital selection or custom hospital name is required."})

    req = BloodRequest.objects.create(
        requester=requester,
        patient_name=data.get('patient_name', ''),
        blood_group=blood_group,
        units_needed=units_needed,
        component=data.get('component', 'WHOLE'),
        urgency=data.get('urgency', 'CRITICAL_2H'),
        needed_by=data.get('needed_by'),
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
        attendant_name=data.get('attendant_name', ''),
        contact_phone=data.get('contact_phone', ''),
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
                subject=f"BloodPulse Requisition Verification Code: {code}",
                message=(
                    f"Your BloodPulse requisition OTP is: {code}\n\n"
                    f"This code will expire in 10 minutes.\n"
                    "If you did not initiate this request, please disregard."
                ),
                from_email=settings.DEFAULT_FROM_EMAIL or host_user,
                recipient_list=[target_email],
                fail_silently=False,
            )
        except Exception as exc:
            logger.error("Failed to dispatch requisition OTP email: %s", exc)

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


def accept_request(blood_request_id: int, donor_user) -> DonationMatch:
    """
    Atomic acceptance of a blood request by a donor.
    Uses select_for_update to prevent race conditions. Returns 409 if units filled.
    """
    donor_profile = getattr(donor_user, 'donorprofile', None)
    if not donor_profile:
        donor_profile = DonorProfile.objects.filter(user=donor_user).first()
    if not donor_profile:
        raise ValidationError({"detail": "Donor profile not found."})

    if donor_profile.last_donation_date:
        cooldown_cutoff = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS)
        if donor_profile.last_donation_date > cooldown_cutoff:
            raise ConflictError("You are currently under the 90-day donation cooldown.")

    with transaction.atomic():
        req = BloodRequest.objects.select_for_update().get(id=blood_request_id)
        if req.status not in ['OPEN', 'MATCHED']:
            raise ConflictError(f"Request cannot be accepted in status '{req.status}'.")

        active_matches_count = req.donation_matches.filter(
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
        ).count()
        if active_matches_count >= req.units_needed:
            raise ConflictError("All requested units for this requisition are already filled.")

        if req.donation_matches.filter(donor=donor_profile).exists():
            raise ConflictError("You have already accepted or have a match on this request.")

        role = 'PRIMARY' if active_matches_count == 0 else (
            'STANDBY_1' if active_matches_count == 1 else 'STANDBY_2'
        )

        match = DonationMatch.objects.create(
            request=req,
            donor=donor_profile,
            status='ACCEPTED',
            role=role,
            accepted_at=timezone.now(),
            chat_room_id=f"chat_{req.id}_{donor_profile.id}_{uuid4().hex[:8]}",
            tracking_room_id=f"track_{req.id}_{donor_profile.id}_{uuid4().hex[:8]}",
        )

        if req.status == 'OPEN':
            transition(req, 'MATCHED', donor_user)

    return match
