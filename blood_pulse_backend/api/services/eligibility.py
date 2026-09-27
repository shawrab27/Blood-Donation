# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

# To be reviewed by qualified medical staff before real-world use.
"""
Donor Eligibility Evaluation Service.
Calculates donation cooldowns (120 days for whole blood), enforces active medical deferrals,
and evaluates pause periods and availability.
"""

from datetime import date, timedelta
from django.utils import timezone
from api.conf import WHOLE_BLOOD_COOLDOWN_DAYS, PLATELET_COOLDOWN_DAYS, PLASMA_COOLDOWN_DAYS


def evaluate_donor_eligibility(donor, component: str = 'WHOLE') -> dict:
    """
    Evaluates whether a donor is eligible to donate the specified blood component today.
    Returns:
    {
        'is_eligible': bool,
        'reason': str,
        'days_remaining': int,
        'deferred_until': date/datetime or None
    }
    """
    now = timezone.now()
    today = now.date()

    # 1. Profile completeness & availability
    if not donor.is_available:
        return {
            'is_eligible': False,
            'reason': 'Donor has marked their status as temporarily unavailable.',
            'days_remaining': 0,
            'deferred_until': None,
        }

    # 2. Alert pause window (e.g. donor paused notifications)
    if donor.alert_pause_until and donor.alert_pause_until > now:
        delta = (donor.alert_pause_until.date() - today).days
        return {
            'is_eligible': False,
            'reason': 'Donor alerts are currently paused.',
            'days_remaining': max(1, delta),
            'deferred_until': donor.alert_pause_until,
        }

    # 3. Explicit Medical / Travel Deferral
    if donor.deferral_until:
        deferral_date = donor.deferral_until.date() if hasattr(donor.deferral_until, 'date') else donor.deferral_until
        if deferral_date > today:
            delta = (deferral_date - today).days
            return {
                'is_eligible': False,
                'reason': 'Donor is under an active medical deferral.',
                'days_remaining': delta,
                'deferred_until': donor.deferral_until,
            }

    # Check DeferralRecord active records if related manager exists
    if hasattr(donor, 'deferrals'):
        active_deferral = donor.deferrals.filter(is_active=True).first()
        if active_deferral:
            if active_deferral.expires_at is None:
                return {
                    'is_eligible': False,
                    'reason': f'Indefinite medical deferral: {active_deferral.reason}',
                    'days_remaining': 9999,
                    'deferred_until': None,
                }
            elif active_deferral.expires_at > now:
                delta = (active_deferral.expires_at.date() - today).days
                return {
                    'is_eligible': False,
                    'reason': f'Medical deferral: {active_deferral.reason}',
                    'days_remaining': max(1, delta),
                    'deferred_until': active_deferral.expires_at,
                }

    # 4. Standard Cooldown Interval
    cooldown_days = WHOLE_BLOOD_COOLDOWN_DAYS
    norm_comp = (component or 'WHOLE').upper()
    if norm_comp == 'PLATELETS':
        cooldown_days = PLATELET_COOLDOWN_DAYS
    elif norm_comp == 'PLASMA':
        cooldown_days = PLASMA_COOLDOWN_DAYS

    if donor.last_donation_date:
        days_since_donation = (today - donor.last_donation_date).days
        if days_since_donation < cooldown_days:
            remaining = cooldown_days - days_since_donation
            eligible_date = donor.last_donation_date + timedelta(days=cooldown_days)
            return {
                'is_eligible': False,
                'reason': f'Recovery cooldown in progress ({remaining} days remaining of {cooldown_days}-day period).',
                'days_remaining': remaining,
                'deferred_until': eligible_date,
            }

    return {
        'is_eligible': True,
        'reason': 'Eligible to donate.',
        'days_remaining': 0,
        'deferred_until': None,
    }
