# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Standby Donor Ranking & Activation Engine (Anomaly #31, N5).
Activates backup donors when an active journey encounters a donation issue
(e.g., medical rejection, no-show, donor cancel, stale location).
"""

import logging
from django.utils import timezone
from datetime import timedelta
from api.models import StandbyOffer, DonorProfile, Notification
from api.conf import (
    STANDBY_TIMEOUT_MINUTES,
    STANDBY_MAX_ATTEMPTS,
    STANDBY_RADIUS_LADDER_KM,
)
from api.services.compat import get_compatible_donor_groups
from api.services.eligibility import evaluate_donor_eligibility
from api.services.geo import haversine_distance

logger = logging.getLogger(__name__)


def trigger_standby_donor_offer(blood_request, exclude_donor_ids: list = None) -> StandbyOffer:
    """
    Selects the best available backup donor, creates a StandbyOffer with a timeout,
    and dispatches an alert.
    Idempotent: If an active PENDING offer already exists, returns it without creating a duplicate.
    Enforces STANDBY_MAX_ATTEMPTS and escalating radius ladder [5, 25, 100, 1000] km.
    """
    now = timezone.now()

    # 1. Idempotency guard: Return existing pending unexpired offer
    existing_pending = StandbyOffer.objects.filter(
        request=blood_request,
        status='PENDING',
        expires_at__gt=now,
    ).first()
    if existing_pending:
        logger.info(f"Active standby offer #{existing_pending.id} already pending for Request #{blood_request.id}")
        return existing_pending

    # 2. Max attempts guard
    past_offers_count = StandbyOffer.objects.filter(request=blood_request).count()
    if past_offers_count >= STANDBY_MAX_ATTEMPTS:
        logger.warning(f"Max standby attempts ({STANDBY_MAX_ATTEMPTS}) reached for Request #{blood_request.id}")
        return None

    if exclude_donor_ids is None:
        exclude_donor_ids = []

    # Include existing acceptances in exclusion list
    existing_accepted_donors = list(blood_request.acceptances.values_list('donor_id', flat=True))
    exclude_donor_ids.extend(existing_accepted_donors)

    # Exclude donors who already have standby offers for this request
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

    # Radius ladder escalation: pick top candidate within smallest radius that has candidates
    top_candidate = None
    for radius in STANDBY_RADIUS_LADDER_KM:
        radius_pool = [c for c in candidates if c['distance_km'] is None or c['distance_km'] <= radius]
        if radius_pool:
            radius_pool.sort(key=lambda c: c['rank_score'], reverse=True)
            top_candidate = radius_pool[0]['donor']
            logger.info(f"Standby candidate found within {radius} km ladder for Request #{blood_request.id}")
            break

    if not top_candidate:
        candidates.sort(key=lambda c: c['rank_score'], reverse=True)
        top_candidate = candidates[0]['donor']

    offer = StandbyOffer.objects.create(
        request=blood_request,
        donor=top_candidate,
        status='PENDING',
        expires_at=now + timedelta(minutes=STANDBY_TIMEOUT_MINUTES),
    )

    try:
        from api.services.notify import notify_standby_offer
        notify_standby_offer(offer)
    except Exception as notif_err:
        logger.warning(f"Could not dispatch standby notification for user {top_candidate.user_id}: {notif_err}")

    logger.info(f"Standby offer #{offer.id} created for Donor #{top_candidate.id} on Request #{blood_request.id}")
    return offer


def process_stale_tracking_and_standby_tick(timeout_minutes=None, stale_tracking_minutes=None, dry_run=False) -> dict:
    """
    Idempotent tick sweeping stale tracking states and expired standby offers.
    Triggers:
    1. Unresponded standby offers exceeding timeout -> expire & promote next candidate.
    2. Stale journeys (no start movement in timeout_minutes or location stale > stale_tracking_minutes)
       -> fail journey & trigger standby replacement.
    """
    from django.db import transaction
    from api.models import RequestAcceptance, BloodRequest
    from api.conf import JOURNEY_NO_SHOW_TIMEOUT_MINUTES, DONOR_TRACKING_STALE_MINUTES
    from api.services.blood_hub_lifecycle_service import transition

    timeout_m = timeout_minutes or JOURNEY_NO_SHOW_TIMEOUT_MINUTES
    stale_loc_m = stale_tracking_minutes or DONOR_TRACKING_STALE_MINUTES
    now = timezone.now()

    # 1. Expire stale standby offers
    expired_offers = StandbyOffer.objects.filter(
        status='PENDING',
        expires_at__lte=now,
    ).select_related('request', 'donor')

    expired_count = expired_offers.count()
    promoted_count = 0
    if not dry_run:
        for offer in expired_offers:
            with transaction.atomic():
                offer.status = 'EXPIRED'
                offer.save(update_fields=['status'])
                next_offer = trigger_standby_donor_offer(offer.request, exclude_donor_ids=[offer.donor_id])
                if next_offer:
                    promoted_count += 1

    # 2. Sweep inactive / stale journeys
    no_movement_cutoff = now - timedelta(minutes=timeout_m)
    stale_loc_cutoff = now - timedelta(minutes=stale_loc_m)

    stale_journeys = (
        RequestAcceptance.objects.filter(
            status='ACCEPTED',
            started_at__lte=no_movement_cutoff,
            last_location_update__isnull=True,
        ) |
        RequestAcceptance.objects.filter(
            status='ON_THE_WAY',
            last_location_update__lte=stale_loc_cutoff,
        )
    ).select_related('request', 'donor')

    stale_count = stale_journeys.count()
    replaced_count = 0
    if not dry_run:
        for acc in stale_journeys:
            with transaction.atomic():
                locked_acc = RequestAcceptance.objects.select_for_update().get(pk=acc.pk)
                if locked_acc.status not in ('ACCEPTED', 'ON_THE_WAY'):
                    continue

                locked_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)
                locked_acc.status = 'FAILED'
                locked_acc.cancellation_reason = f"Automated timeout (inactivity > {timeout_m}m or location stale > {stale_loc_m}m)"
                locked_acc.completed_at = now
                locked_acc.save(update_fields=['status', 'cancellation_reason', 'completed_at'])

                donor = locked_acc.donor
                donor.no_show_count = (donor.no_show_count or 0) + 1
                donor.save(update_fields=['no_show_count'])

                if not locked_acc.is_standby and locked_req.units_pending > 0:
                    locked_req.units_pending = max(0, locked_req.units_pending - max(1, locked_acc.units_pledged or 1))
                    locked_req.save(update_fields=['units_pending'])

                try:
                    transition(locked_req, 'STANDBY_SEARCHING', None, note="Donor inactive; searching for standby replacement")
                except Exception:
                    pass

                replacement = trigger_standby_donor_offer(locked_req, exclude_donor_ids=[donor.id])
                if replacement:
                    replaced_count += 1

    return {
        'expired_offers': expired_count,
        'promoted_offers': promoted_count,
        'stale_journeys': stale_count,
        'replaced_journeys': replaced_count,
    }
