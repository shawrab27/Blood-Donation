# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Targeting and reach service for BloodPulse.
Queries real donors matching blood compatibility, scope, availability,
soft-delete status, and standard 90-day cooldown.
"""

from datetime import timedelta
from django.utils import timezone
from django.db.models import Q

from api.models import DonorProfile, CompatibilityRule, BloodRequest
from api.conf import DONOR_COOLDOWN_DAYS
from api.services.geo import haversine_distance

FALLBACK_COMPATIBILITY = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
}


def get_compatible_donor_blood_groups(recipient_group: str) -> list[str]:
    """
    Retrieves compatible donor groups from CompatibilityRule table.
    Falls back to medical standard if database table rule is missing.
    """
    group = (recipient_group or '').replace(' ', '+').strip().upper()
    rule = CompatibilityRule.objects.filter(blood_group=group).first()
    if rule and rule.can_receive_from:
        groups = [g.strip().upper() for g in rule.can_receive_from.split(',') if g.strip()]
        if groups:
            return groups
    return FALLBACK_COMPATIBILITY.get(group, [group] if group else [])


def get_base_eligible_donor_queryset(blood_group: str):
    """
    Returns base queryset of donors:
    - Compatible blood group
    - Cooldown passed (90 days from DONOR_COOLDOWN_DAYS)
    - Available (is_available=True)
    - Not soft-deleted (user.is_active=True)
    """
    cutoff_date = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS)
    compatible_groups = get_compatible_donor_blood_groups(blood_group)

    qs = DonorProfile.objects.filter(
        user__is_active=True,
        is_available=True,
        blood_group__in=compatible_groups,
    ).filter(
        Q(last_donation_date__isnull=True) | Q(last_donation_date__lte=cutoff_date)
    )
    return qs


def calculate_eligible_reach(
    blood_group: str,
    scope: str = 'LOCAL',
    district: str = '',
    division_name: str = '',
    lat: float = None,
    lng: float = None,
) -> int:
    """
    Calculates eligible reachable donor count strictly based on real DB data.
    Scope levels: LOCAL, DISTRICT, DIVISION, NATIONWIDE.
    """
    qs = get_base_eligible_donor_queryset(blood_group)
    norm_scope = (scope or 'LOCAL').strip().upper()

    if norm_scope == 'NATIONWIDE':
        return qs.count()

    if norm_scope == 'DIVISION' and division_name:
        return qs.filter(division__name__iexact=division_name).count()

    if norm_scope == 'DISTRICT' and district:
        return qs.filter(district__iexact=district).count()

    # LOCAL scope: radius within 5km if lat/lng available, else match district
    if norm_scope == 'LOCAL':
        if lat is not None and lng is not None:
            count = 0
            for d in qs.only('id', 'latitude', 'longitude', 'district'):
                d_lat = d.latitude
                d_lng = d.longitude
                if d_lat is not None and d_lng is not None:
                    if haversine_distance(float(lat), float(lng), float(d_lat), float(d_lng)) <= 5.0:
                        count += 1
                elif district and d.district and d.district.lower() == district.lower():
                    count += 1
            return count
        elif district:
            return qs.filter(district__iexact=district).count()

    return qs.count()


def find_nearest_standby_donor(
    request_obj: BloodRequest,
    exclude_donor_ids: list[int] = None,
) -> DonorProfile | None:
    """
    Finds the nearest eligible candidate for standby promotion using Haversine distance.
    Respects compatibility, 90-day cooldown, and excludes already-matched donors.
    """
    exclude_ids = set(exclude_donor_ids or [])
    qs = get_base_eligible_donor_queryset(request_obj.blood_group)
    if exclude_ids:
        qs = qs.exclude(id__in=exclude_ids)

    req_lat = request_obj.lat
    req_lng = request_obj.lng
    if req_lat is None and request_obj.hospital:
        req_lat = request_obj.hospital.lat
        req_lng = request_obj.hospital.lng

    candidates = list(qs)
    if not candidates:
        return None

    if req_lat is not None and req_lng is not None:
        def dist_key(d: DonorProfile):
            d_lat = d.latitude or d.last_lat
            d_lng = d.longitude or d.last_lng
            if d_lat is not None and d_lng is not None:
                return haversine_distance(float(req_lat), float(req_lng), float(d_lat), float(d_lng))
            return 999999.0

        candidates.sort(key=dist_key)

    return candidates[0] if candidates else None
