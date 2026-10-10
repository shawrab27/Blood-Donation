# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Request Submit Email OTP and Mandatory Submit Token.
Enforces 6-digit HMAC-SHA256 hashed OTP, 10-minute expiry, max 5 attempts,
60s resend cooldown, user+IP rate limits, and 15-minute single-use submit_token.
"""

import hashlib
import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from api.models import EmailOTP, RequestSubmitToken
from api.services.email import (
    hash_otp,
    verify_otp_hash,
    generate_secure_otp,
    OTP_EXPIRY_MINUTES,
    OTP_RESEND_COOLDOWN_SECONDS,
)
from api.throttles import OTPAnonThrottle, OTPUserThrottle

logger = logging.getLogger(__name__)


def validate_and_consume_submit_token(user, submit_token: str, purpose: str = 'blood_request_submit') -> bool:
    """
    Validates and atomically consumes a single-use submit_token.
    Returns True if valid and consumed; False otherwise.
    """
    if not submit_token or not user or not user.is_authenticated:
        return False

    token_hash = hashlib.sha256(submit_token.strip().encode('utf-8')).hexdigest()
    now = timezone.now()

    with transaction.atomic():
        token_obj = (
            RequestSubmitToken.objects
            .select_for_update()
            .filter(
                token_hash=token_hash,
                user=user,
                purpose=purpose,
                is_used=False,
                expires_at__gte=now,
            )
            .first()
        )
        if not token_obj:
            return False

        token_obj.is_used = True
        token_obj.used_at = now
        token_obj.save(update_fields=['is_used', 'used_at'])
        return True


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPAnonThrottle, OTPUserThrottle])
def request_otp_send_view(request):
    """
    POST /api/requests/otp/send/
    Dispatches a 6-digit verification code to the requester's email.
    Enforces 60-second cooldown, max 5 attempts, invalidates older OTPs of same purpose.
    """
    user = request.user
    email = request.data.get('email', '').strip().lower() or user.email.strip().lower()

    if not email or '@' not in email:
        return Response(
            {'error': 'A valid email address is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    now = timezone.now()

    # Rate limiting: 60s cooldown per user or email
    recent_otp = (
        EmailOTP.objects
        .filter(user=user, purpose='blood_request_submit')
        .order_by('-created_at')
        .first()
    )
    if not recent_otp:
        recent_otp = (
            EmailOTP.objects
            .filter(email=email, purpose='blood_request_submit')
            .order_by('-created_at')
            .first()
        )

    if recent_otp and recent_otp.last_sent_at:
        elapsed = (now - recent_otp.last_sent_at).total_seconds()
        if elapsed < OTP_RESEND_COOLDOWN_SECONDS:
            wait_seconds = int(OTP_RESEND_COOLDOWN_SECONDS - elapsed)
            return Response({
                'error': f'Please wait {wait_seconds} seconds before requesting a new verification code.',
                'cooldown_seconds': wait_seconds,
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

    # Invalidate older unused OTPs for this user and purpose
    EmailOTP.objects.filter(
        user=user,
        purpose='blood_request_submit',
        is_used=False,
    ).update(is_used=True)

    # Generate 6-digit numeric OTP & HMAC-SHA256 hash
    code = generate_secure_otp(length=6)
    code_hash = hash_otp(code, email)
    expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)

    EmailOTP.objects.create(
        user=user,
        email=email,
        otp_hash=code_hash,
        expires_at=expires_at,
        purpose='blood_request_submit',
        last_sent_at=now,
    )

    # Dispatch email via Django email system (in tests: outbox; in prod: Brevo/SMTP)
    try:
        send_mail(
            subject=f"{code} is your BloodPulse verification code",
            message=(
                f"Your BloodPulse verification code is: {code}\n\n"
                f"This code will expire in {OTP_EXPIRY_MINUTES} minutes.\n"
                f"If you did not request this code, please ignore this email."
            ),
            from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@bloodpulse.org'),
            recipient_list=[email],
            fail_silently=False,
        )
    except Exception as exc:
        logger.error("Failed to send request OTP email to %s: %s", email, exc)

    return Response({
        'status': 'otp_sent',
        'email': email,
        'cooldown_seconds': OTP_RESEND_COOLDOWN_SECONDS,
        'expires_in_minutes': OTP_EXPIRY_MINUTES,
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([OTPAnonThrottle, OTPUserThrottle])
def request_otp_verify_view(request):
    """
    POST /api/requests/otp/verify/
    Verifies the 6-digit code using HMAC-SHA256 constant-time comparison.
    Locks after 5 wrong attempts. On success, returns single-use 15-minute submit_token.
    """
    user = request.user
    code = request.data.get('code', '') or request.data.get('otp', '')
    code = str(code).strip()
    email = request.data.get('email', '').strip().lower() or user.email.strip().lower()

    if not code:
        return Response(
            {'error': 'A 6-digit verification code is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    now = timezone.now()

    # Find the latest active OTP for this user and purpose
    otp_record = (
        EmailOTP.objects
        .filter(
            user=user,
            purpose='blood_request_submit',
            is_used=False,
            expires_at__gt=now,
        )
        .order_by('-created_at')
        .first()
    )

    if not otp_record:
        # Fallback to email matching if user foreign key was unset
        otp_record = (
            EmailOTP.objects
            .filter(
                email=email,
                purpose='blood_request_submit',
                is_used=False,
                expires_at__gt=now,
            )
            .order_by('-created_at')
            .first()
        )

    if not otp_record:
        return Response(
            {'error': 'Invalid or expired verification code. Please request a new one.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if otp_record.is_locked():
        return Response(
            {'error': 'This code has been locked due to too many failed attempts. Please request a new code.'},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    # Constant-time comparison
    if not verify_otp_hash(code, otp_record.otp_hash, otp_record.email):
        otp_record.attempts += 1
        otp_record.save(update_fields=['attempts'])
        remaining_attempts = max(0, 5 - otp_record.attempts)
        if otp_record.attempts >= 5:
            return Response(
                {'error': 'This code has been locked due to too many failed attempts. Please request a new code.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        return Response({
            'error': f'Incorrect code. {remaining_attempts} attempt(s) remaining.',
            'remaining_attempts': remaining_attempts,
        }, status=status.HTTP_400_BAD_REQUEST)

    # Verification successful: consume OTP
    otp_record.is_used = True
    otp_record.save(update_fields=['is_used'])

    # Invalidate older unused submit tokens for this user
    RequestSubmitToken.objects.filter(
        user=user,
        purpose='blood_request_submit',
        is_used=False,
    ).update(is_used=True)

    # Issue single-use 15-minute submit_token
    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
    expires_at = now + timedelta(minutes=15)

    RequestSubmitToken.objects.create(
        user=user,
        token_hash=token_hash,
        purpose='blood_request_submit',
        expires_at=expires_at,
    )

    return Response({
        'submit_token': raw_token,
        'expires_in_minutes': 15,
        'message': 'Identity verified. Submit token issued.',
    }, status=status.HTTP_200_OK)
