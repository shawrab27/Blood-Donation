# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Wave Tick & State Machine Progression Service.
Processes active emergency requests, triggers wave progression when timeouts expire,
and expires stale requests.
"""

from datetime import timedelta
from django.utils import timezone
from api.conf import WAVE_TIMEOUT_MINUTES
from api.services.waves import get_candidate_donors_for_wave
from api.services.notify import dispatch_wave_notifications


def process_wave_tick() -> dict:
    """
    Evaluates all active blood requests and advances wave states or expires old requests.
    Returns:
    {
        'advanced': int,
        'expired': int,
        'escalated': int
    }
    """
    from api.models import BloodRequest

    now = timezone.now()
    advanced_count = 0
    expired_count = 0
    escalated_count = 0

    active_requests = BloodRequest.objects.filter(
        status='ACTIVE',
        is_active=True,
    )

    for req in active_requests:
        # Check overall expiration
        if req.expires_at and req.expires_at <= now:
            req.status = 'EXPIRED'
            req.is_active = False
            req.save(update_fields=['status', 'is_active'])
            expired_count += 1
            continue

        # Check wave transition for emergency requests
        if req.mode == 'EMERGENCY' and req.next_wave_at and req.next_wave_at <= now:
            if req.current_wave < 4:
                next_wave = req.current_wave + 1
                candidates = get_candidate_donors_for_wave(req, wave_number=next_wave)
                
                # Check if candidates were found within effective scope
                if candidates:
                    dispatch_wave_notifications(req, candidates, wave_number=next_wave)

                req.current_wave = next_wave
                
                # Compute next timeout
                timeout_map = WAVE_TIMEOUT_MINUTES.get(req.urgency, WAVE_TIMEOUT_MINUTES['CRITICAL_2H'])
                delay_mins = timeout_map.get(next_wave, 30)
                req.next_wave_at = now + timedelta(minutes=delay_mins)
                req.save(update_fields=['current_wave', 'next_wave_at'])
                advanced_count += 1

            elif req.current_wave >= 4:
                # Top wave reached without fulfillment -> escalate to admin
                if not req.escalated_to_admin:
                    req.escalated_to_admin = True
                    req.save(update_fields=['escalated_to_admin'])
                    escalated_count += 1

    return {
        'advanced': advanced_count,
        'expired': expired_count,
        'escalated': escalated_count
    }
