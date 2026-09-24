"""
Standby Donor Ranking & Activation Engine.
Activates backup donors when an active journey encounters a donation issue
(e.g., medical rejection or no-show).
"""

import logging
from django.utils import timezone
from datetime import timedelta
from api.models import StandbyOffer, DonorProfile
from api.services.compat import get_compatible_donor_groups
from api.services.eligibility import evaluate_donor_eligibility
from api.services.geo import haversine_distance

logger = logging.getLogger(__name__)

STANDBY_TIMEOUT_MINUTES = 10


def trigger_standby_donor_offer(blood_request, exclude_donor_ids: list = None) -> StandbyOffer:
    """
    Selects the best available backup donor, creates a StandbyOffer with a 10-minute timeout,
    and dispatches an alert.
    """
    if exclude_donor_ids is None:
        exclude_donor_ids = []

    # Include existing acceptances in exclusion list
    existing_accepted_donors = list(blood_request.acceptances.values_list('donor_id', flat=True))
    exclude_donor_ids.extend(existing_accepted_donors)

    # Exclude donors who already have pending or declined standby offers for this request
    existing_standby_donors = list(blood_request.standby_offers.values_list('donor_id', flat=True))
    exclude_donor_ids.extend(existing_standby_donors)

    compatible_groups = get_compatible_donor_groups(
        blood_request.blood_group,
        blood_request.component or 'WHOLE'
    )

    donors_qs = DonorProfile.objects.filter(
        blood_group__in=compatible_groups,
        is_available=True,
    ).exclude(id__in=exclude_donor_ids).select_related('user')

    if blood_request.requester_id:
        donors_qs = donors_qs.exclude(user_id=blood_request.requester_id)

    req_lat = blood_request.lat or (blood_request.hospital.lat if blood_request.hospital else None)
    req_lng = blood_request.lng or (blood_request.hospital.lng if blood_request.hospital else None)

    candidates = []
    for donor in donors_qs:
        eligibility = evaluate_donor_eligibility(donor, blood_request.component)
        if not eligibility['is_eligible']:
            continue

        donor_lat = donor.last_lat or donor.latitude
        donor_lng = donor.last_lng or donor.longitude

        dist_km = None
        if req_lat is not None and req_lng is not None and donor_lat is not None and donor_lng is not None:
            dist_km = haversine_distance(req_lat, req_lng, donor_lat, donor_lng)

        # Proximity score (prefer < 30km)
        proximity_score = max(0.0, 1.0 - (dist_km / 30.0)) if dist_km is not None else 0.5
        
        response_rate = 1.0
        if (donor.alert_count or 0) > 0:
            response_rate = min(1.0, (donor.response_count or 0) / float(donor.alert_count))
        reliability_score = response_rate * (1.0 if (donor.no_show_count or 0) == 0 else 0.4)

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
            'distance_km': dist_km,
            'rank_score': rank_score,
        })

    if not candidates:
        logger.warning(f"No standby donor candidates found for Request #{blood_request.id}")
        return None

    # Pick top-ranked candidate
    candidates.sort(key=lambda c: c['rank_score'], reverse=True)
    top_candidate = candidates[0]['donor']

    now = timezone.now()
    offer = StandbyOffer.objects.create(
        request=blood_request,
        donor=top_candidate,
        status='PENDING',
        expires_at=now + timedelta(minutes=STANDBY_TIMEOUT_MINUTES),
    )

    logger.info(f"Standby offer #{offer.id} created for Donor #{top_candidate.id} on Request #{blood_request.id}")
    return offer
