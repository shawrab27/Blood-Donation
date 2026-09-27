# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Wave Expansion & Donor Ranking Engine.
Determines target donor cohorts across expanding geographical tiers
and ranks candidate donors based on proximity, reliability, and compatibility.
"""

from django.utils import timezone
from api.conf import WAVE_RADIUS_KM
from api.services.compat import get_compatible_donor_groups
from api.services.eligibility import evaluate_donor_eligibility
from api.services.geo import haversine_distance


def get_candidate_donors_for_wave(blood_request, wave_number: int = 1) -> list:
    """
    Selects and ranks candidate donors eligible for the given wave tier.
    Applies compatibility, eligibility, geographical bounds, and effective scope restrictions.
    """
    from api.models import DonorProfile

    effective_scope = getattr(blood_request, 'effective_scope', 'LOCAL').upper()

    # Scope cap checks:
    if effective_scope == 'LOCAL' and wave_number > 1:
        return []
    if effective_scope == 'DISTRICT' and wave_number > 2:
        return []
    if effective_scope == 'DIVISION' and wave_number > 3:
        return []

    # 1. Component & blood group compatibility
    compatible_groups = get_compatible_donor_groups(
        blood_request.blood_group,
        blood_request.component or 'WHOLE'
    )

    # Base queryset: Available, searchable, matching blood group
    donors_qs = DonorProfile.objects.filter(
        blood_group__in=compatible_groups,
        is_available=True,
    ).select_related('user')

    # Exclude requester if requester is a donor profile
    if blood_request.requester_id:
        donors_qs = donors_qs.exclude(user_id=blood_request.requester_id)

    # Exclude donors already notified for this request
    already_notified_donor_ids = blood_request.notifications.values_list('donor_id', flat=True)
    if already_notified_donor_ids:
        donors_qs = donors_qs.exclude(id__in=already_notified_donor_ids)

    req_lat = blood_request.lat
    req_lng = blood_request.lng
    req_district = blood_request.district
    req_upazila = blood_request.upazila

    max_radius_km = WAVE_RADIUS_KM.get(wave_number, 5.0)

    candidates = []

    for donor in donors_qs:
        # Check medical & interval eligibility
        eligibility = evaluate_donor_eligibility(donor, blood_request.component)
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
            # Wave 1: Immediate local / campus / upazila / < 5km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif req_upazila and getattr(donor, 'upazila', None) == req_upazila:
                in_boundary = True
            elif blood_request.district and donor.district and blood_request.district.strip().lower() == donor.district.strip().lower():
                # If no lat/lng available, match same district for local fallback
                in_boundary = True

        elif wave_number == 2:
            # Wave 2: District-wide / < 25km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif blood_request.district and donor.district and blood_request.district.strip().lower() == donor.district.strip().lower():
                in_boundary = True

        elif wave_number == 3:
            # Wave 3: Division-wide / < 100km
            if dist_km is not None and dist_km <= max_radius_km:
                in_boundary = True
            elif blood_request.division_id and getattr(donor, 'division_id', None) == blood_request.division_id:
                in_boundary = True

        elif wave_number >= 4:
            # Wave 4: Nationwide broadcast
            in_boundary = True

        if not in_boundary:
            continue

        # Compute Ranking Score (Higher is better)
        # Weights: Proximity 0.4, Activity/Reliability 0.3, Rating 0.2, Exact Group Match 0.1
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
    return candidates
