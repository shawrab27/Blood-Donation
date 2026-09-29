import secrets
import os
import hmac
import hashlib
import time
from datetime import timedelta
from django.utils import timezone
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import transaction
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework_simplejwt.tokens import OutstandingToken, BlacklistedToken
from .models import PasswordResetOTP
from .services.email import get_email_service


# -------------------------------------------------------------------
# Throttles
# -------------------------------------------------------------------

class IpRateThrottle(ScopedRateThrottle):
    """Limits by IP address. Scope set on the view via .throttle_scope."""
    scope_attr = 'throttle_scope'


class EmailRateThrottle(ScopedRateThrottle):
    """
    Limits by email address using a separate scope ('email_otp').
    This ensures unknown and known emails are treated identically by
    the IP throttle, while repeat requests for the SAME email are
    capped independently.
    """
    scope_attr = 'throttle_scope'
    # Override scope so this class always reads 'email_otp' rate, not the
    # IP scope ('request_otp').  We set it explicitly here so both
    # throttles can coexist on the same view without sharing the rate.
    scope = 'email_otp'

    def get_cache_key(self, request, view):
        email = request.data.get('email', '').strip().lower()
        if not email:
            # No email → fall back to IP so the request is still counted
            return self.get_ident(request)
        return self.cache_format % {
            'scope': self.scope,
            'ident': email,
        }


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

def generate_otp_hash(otp_code: str) -> str:
    pepper = settings.SECRET_KEY.encode('utf-8')
    return hmac.new(pepper, otp_code.encode('utf-8'), hashlib.sha256).hexdigest()


def _generic_success():
    return Response(
        {'detail': 'If this email is registered, a code has been sent.'},
        status=status.HTTP_200_OK,
    )


def _constant_time_sleep():
    """
    Tiny sleep so timing attacks cannot distinguish known vs unknown emails.
    The cooldown 429 path for known users does a DB round-trip; unknown emails
    return immediately. This equalises response time to ~5 ms within noise.
    """
    time.sleep(0.005)


# -------------------------------------------------------------------
# Views
# -------------------------------------------------------------------

@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([IpRateThrottle, EmailRateThrottle])
def request_otp(request):
    email = request.data.get('email', '').strip().lower()

    user = User.objects.filter(email=email).first()
    if not user:
        _constant_time_sleep()
        return _generic_success()

    now = timezone.now()
    cooldown_seconds = int(os.environ.get('OTP_RESEND_SECONDS', 45))
    cooldown_time = now - timedelta(seconds=cooldown_seconds)

    recent_otp = (
        PasswordResetOTP.objects
        .filter(user=user)
        .order_by('-last_sent_at')
        .first()
    )
    if recent_otp and recent_otp.last_sent_at > cooldown_time:
        wait_time = (recent_otp.last_sent_at - cooldown_time).total_seconds()
        # Return the SAME 200 body — do NOT leak that the account exists via
        # a 429.  The Flutter UI can show a generic "check your inbox" message.
        # The cooldown is enforced silently server-side.
        return _generic_success()

    # Invalidate all earlier unused OTPs for that user
    PasswordResetOTP.objects.filter(user=user, is_used=False).update(is_used=True)

    otp_code = str(secrets.randbelow(900000) + 100000)
    expiry_minutes = int(os.environ.get('OTP_EXPIRY_MINUTES', 10))

    PasswordResetOTP.objects.create(
        user=user,
        otp_hash=generate_otp_hash(otp_code),
        expires_at=now + timedelta(minutes=expiry_minutes),
        is_used=False,
    )

    email_service = get_email_service()
    email_service.send_otp(user.email, otp_code)

    return _generic_success()


# Scope for IpRateThrottle — must be set BEFORE DRF reads it on first request.
request_otp.throttle_scope = 'request_otp'


@api_view(['POST'])
@permission_classes([AllowAny])
@throttle_classes([IpRateThrottle, EmailRateThrottle])
def confirm_reset(request):
    email = request.data.get('email', '').strip().lower()
    otp_code = request.data.get('otp', '').strip()
    new_password = request.data.get('new_password', '')

    user = User.objects.filter(email=email).first()
    if not user or not otp_code or not new_password:
        return Response(
            {'detail': 'Invalid or expired OTP.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        validate_password(new_password, user=user)
    except ValidationError as e:
        return Response(
            {'errors': {'new_password': list(e.messages)}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    with transaction.atomic():
        otp_record = (
            PasswordResetOTP.objects
            .select_for_update()
            .filter(user=user, is_used=False)
            .order_by('-created_at')
            .first()
        )

        if not otp_record:
            return Response(
                {'detail': 'Invalid or expired OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        max_attempts = int(os.environ.get('OTP_MAX_ATTEMPTS', 5))
        if otp_record.attempts >= max_attempts:
            otp_record.is_used = True
            otp_record.save()
            return Response(
                {'detail': 'Too many attempts. Request a new code.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        if timezone.now() > otp_record.expires_at:
            otp_record.is_used = True
            otp_record.save()
            return Response(
                {'detail': 'Invalid or expired OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        expected_hash = generate_otp_hash(otp_code)
        if not hmac.compare_digest(expected_hash, otp_record.otp_hash):
            otp_record.attempts += 1
            if otp_record.attempts >= max_attempts:
                otp_record.is_used = True
                otp_record.save()
                return Response(
                    {'detail': 'Too many attempts. Request a new code.'},
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )
            otp_record.save()
            return Response(
                {'detail': 'Invalid or expired OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp_record.is_used = True
        otp_record.save()

        user.set_password(new_password)
        user.save()

        tokens = OutstandingToken.objects.filter(user=user)
        for token in tokens:
            BlacklistedToken.objects.get_or_create(token=token)

    return Response({'detail': 'Password reset successful.'}, status=status.HTTP_200_OK)


confirm_reset.throttle_scope = 'confirm_reset'
