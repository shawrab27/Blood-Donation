# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Wave Expansion & Donor Ranking Engine.
Determines target donor cohorts across expanding geographical tiers
and ranks candidate donors based on proximity, reliability, and compatibility.
Enforces dispatch scope ceilings, quiet hours (unless critical), deduplication
against WaveNotificationLog, and pure DB geohash prefiltering.
"""

from django.db.models import Q
from django.utils import timezone
from api.conf import WAVE_RADIUS_KM, WAVE_CANDIDATE_BATCH_LIMIT
from api.services.compat import get_compatible_donor_groups
from api.services.eligibility import evaluate_donor_eligibility
from api.services.geo import haversine_distance, encode_geohash


# Dispatch scope ceilings: LOCAL -> 1, DISTRICT -> 2, DIVISION -> 3, NATIONWIDE -> 4
SCOPE_MAX_WAVE = {
    'LOCAL': 1,
    'DISTRICT': 2,
    'DIVISION': 3,
    'NATIONWIDE': 4,
}


def get_candidate_donors_for_wave(blood_request, wave_number: int = 1, eval_time=None) -> list:
    """
    Selects and ranks candidate donors eligible for the given wave tier.
    Applies compatibility, eligibility, geographical bounds, and effective scope restrictions.
    Enforces quiet hours (skipped for non-critical; bypassed for critical).
    Excludes donors already logged in WaveNotificationLog or EmergencyNotification.
    Caps results to WAVE_CANDIDATE_BATCH_LIMIT (default 200).
    """
    from api.models import DonorProfile, WaveNotificationLog

    effective_scope = getattr(blood_request, 'effective_scope', 'LOCAL')
    if not effective_scope:
        effective_scope = 'LOCAL'
    effective_scope = effective_scope.upper()

    max_allowed_wave = SCOPE_MAX_WAVE.get(effective_scope, 1)
    if wave_number > max_allowed_wave:
        return []

    from api.services.eligibility import get_eligible_donors_base_queryset

    now = eval_time or timezone.now()

    # Base queryset: Available, not suspended, active user, compatible blood group,
    # passes cooldown, not snoozed (alert_pause_until <= now or null), not deferred
    donors_qs = get_eligible_donors_base_queryset(
        blood_group=blood_request.blood_group,
        component=blood_request.component or 'WHOLE',
        for_search=False,
        now=now,
    ).select_related('user')

    # Exclude requester if requester is a donor profile
    if blood_request.requester_id:
        donors_qs = donors_qs.exclude(user_id=blood_request.requester_id)

    # Exclude donors already notified in WaveNotificationLog or EmergencyNotification
    notified_wave_donor_ids = WaveNotificationLog.objects.filter(
        request=blood_request
    ).values_list('donor_id', flat=True)
    if notified_wave_donor_ids:
        donors_qs = donors_qs.exclude(id__in=notified_wave_donor_ids)

    already_notified_donor_ids = blood_request.notifications.values_list('donor_id', flat=True)
    if already_notified_donor_ids:
        donors_qs = donors_qs.exclude(id__in=already_notified_donor_ids)


    req_lat = blood_request.lat
    req_lng = blood_request.lng
    req_district = blood_request.district
    req_upazila = blood_request.upazila

    # Radius for current wave
    if not WAVE_RADIUS_KM:
        max_radius_km = 5.0
    else:
        radius_idx = max(0, min(wave_number - 1, len(WAVE_RADIUS_KM) - 1))
        max_radius_km = WAVE_RADIUS_KM[radius_idx]

    # Geohash pre-filter: in Wave 1 and Wave 2 with GPS coordinates,
    # narrow down DB candidates using geohash prefix to avoid scanning thousands of distant donors.
    if req_lat is not None and req_lng is not None:
        try:
            req_geohash = encode_geohash(req_lat, req_lng, precision=5)
            if wave_number == 1:
                # Wave 1 (~5km): filter on geohash length 4 (~39km cell) or same district
                donors_qs = donors_qs.filter(
                    Q(geohash__startswith=req_geohash[:4]) |
                    Q(district__iexact=(req_district or '').strip())
                )
            elif wave_number == 2:
                # Wave 2 (~25km): filter on geohash length 3 (~156km cell) or same district
                donors_qs = donors_qs.filter(
                    Q(geohash__startswith=req_geohash[:3]) |
                    Q(district__iexact=(req_district or '').strip())
                )
        except Exception:
            pass

    # Urgency & Quiet Hours check
    is_critical = (getattr(blood_request, 'urgency', '') == 'CRITICAL_2H')

    candidates = []

    for donor in donors_qs:
        # Check medical & interval eligibility + Quiet Hours
        eligibility = evaluate_donor_eligibility(
            donor,
            component=blood_request.component or 'WHOLE',
            is_critical=is_critical,
            check_quiet_hours=True,
            eval_time=eval_time,
        )
        if not eligibility['is_eligible']:
            continue

        donor_lat = donor.last_lat or donor.latitude
        donor_lng = donor.last_lng or donor.longitude

        dist_km = None
        if req_lat is not None and req_lng is not None and donor_lat is not None and donor_lng is not None:
            dist_km = haversine_distance(req_lat, req_lng, donor_lat, donor_lng)

        # Wave Boundary Matchers
        in_boundary = False

        if wave_number == 1:
            # Wave 1: Immediate local / campus / upazila / <= 5km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif req_upazila and getattr(donor, 'upazila', None) == req_upazila:
                in_boundary = True
            elif blood_request.district and donor.district and blood_request.district.strip().lower() == donor.district.strip().lower():
                # If no lat/lng available, match same district for local fallback
                in_boundary = True

        elif wave_number == 2:
            # Wave 2: District-wide / <= 25km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif blood_request.district and donor.district and blood_request.district.strip().lower() == donor.district.strip().lower():
                in_boundary = True

        elif wave_number == 3:
            # Wave 3: Division-wide / <= 100km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif blood_request.division_id and getattr(donor, 'division_id', None) == blood_request.division_id:
                in_boundary = True

        elif wave_number >= 4:
            # Wave 4: Nationwide broadcast (or <= 1000km)
            in_boundary = True

        if not in_boundary:
            continue

        # Compute Ranking Score (Higher is better)
        proximity_score = max(0.0, 1.0 - (dist_km / max_radius_km)) if dist_km is not None else 0.5

        response_rate = 1.0
        if (donor.alert_count or 0) > 0:
            response_rate = min(1.0, (donor.response_count or 0) / float(donor.alert_count))
        reliability_score = response_rate * (1.0 if (donor.no_show_count or 0) == 0 else 0.5)

        rating_score = min(1.0, (donor.rating_avg or 5.0) / 5.0)
        exact_match_score = 1.0 if donor.blood_group == blood_request.blood_group else 0.5

        rank_score = (
            0.40 * proximity_score +
            0.30 * reliability_score +
            0.20 * rating_score +
            0.10 * exact_match_score
        )

        candidates.append({
            'donor': donor,
            'distance_km': round(dist_km, 2) if dist_km is not None else None,
            'rank_score': round(rank_score, 4),
        })

    # Sort candidates by descending rank score
    candidates.sort(key=lambda c: c['rank_score'], reverse=True)

    # Per-step candidate limit cap
    return candidates[:WAVE_CANDIDATE_BATCH_LIMIT]

