# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Public Aggregated Statistics API.
Provides non-PII, truthfully calculated donor and district counts.
Cached for 10 minutes; throttled for anonymous clients.
"""

from django.core.cache import cache
from django.db.models import Q
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from api.models import DonorProfile
from api.conf import PUBLIC_STATS_MIN_DONORS

CACHE_KEY_PUBLIC_STATS = 'bp_public_stats_v1'
CACHE_TIMEOUT_SECONDS = 600  # 10 minutes


from django.utils import timezone


def eligible_public_donors_queryset():
    """
    Shared base queryset for BOTH public stats and the anonymous guest map:
    - is_profile_complete=True
    - user_intent='DONATE_AND_REQUEST'
    - is_searchable=True
    - user is active, not staff, not superuser
    - excludes demo/seed accounts
    - excludes donors with alert_pause_until in the future
    """
    now = timezone.now()
    return (
        DonorProfile.objects
        .filter(
            is_profile_complete=True,
            is_suspended=False,
            user_intent='DONATE_AND_REQUEST',
            is_searchable=True,
            user__is_active=True,
            user__is_staff=False,
            user__is_superuser=False,
        )
        .exclude(
            Q(user__username__istartswith='demo') |
            Q(user__email__iendswith='@bloodpulse.com') |
            Q(user__email__istartswith='demo') |
            Q(phone_number__startswith='017000000') |
            Q(phone_number__startswith='+8801700000')
        )
        .exclude(alert_pause_until__gt=now)
    )


def compute_public_stats_data() -> dict:
    """
    Computes real public stats using eligible_public_donors_queryset():
    registered_donors = eligible public donors count.
    districts_covered = distinct non-empty districts of those donors.
    """
    cached = cache.get(CACHE_KEY_PUBLIC_STATS)
    if cached is not None:
        return cached

    base_qs = eligible_public_donors_queryset()

    registered_donors = base_qs.count()
    districts_covered = (
        base_qs
        .exclude(district__isnull=True)
        .exclude(district='')
        .values('district')
        .distinct()
        .count()
    )

    data = {
        'registered_donors': registered_donors,
        'districts_covered': districts_covered,
    }

    cache.set(CACHE_KEY_PUBLIC_STATS, data, timeout=CACHE_TIMEOUT_SECONDS)
    return data


@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def public_stats_view(request):
    """
    GET /api/public/stats/
    Returns ONLY {registered_donors, districts_covered, request_otp_required}.
    No PII, no ids, no phones, no names.
    Cached for 10 minutes.
    """
    from django.conf import settings
    data = dict(compute_public_stats_data())
    data['request_otp_required'] = getattr(settings, 'REQUEST_OTP_REQUIRED', True)
    return Response(data, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def public_config_view(request):
    """
    GET /api/public/config/
    Returns public runtime configuration and feature flag booleans for the requesting user.
    Never exposes allowed user lists.
    """
    from django.conf import settings
    from api.models import FeatureFlag

    flags = {}
    try:
        user = request.user if getattr(request, 'user', None) and request.user.is_authenticated else None
        for flag in FeatureFlag.objects.all():
            flags[flag.name] = flag.is_active_for_user(user)
    except Exception:
        pass

    return Response({
        'request_otp_required': getattr(settings, 'REQUEST_OTP_REQUIRED', True),
        'flags': flags,
    }, status=status.HTTP_200_OK)
