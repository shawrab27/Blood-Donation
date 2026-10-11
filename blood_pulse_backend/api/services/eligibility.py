# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

# To be reviewed by qualified medical staff before real-world use.
"""
Donor Eligibility Evaluation Service.
Calculates donation cooldowns (90 days for whole blood), enforces active medical deferrals,
and evaluates pause periods and availability.
"""

from datetime import date, timedelta
from zoneinfo import ZoneInfo
from django.utils import timezone
from api.conf import (
    DONOR_COOLDOWN_DAYS,
    WHOLE_BLOOD_COOLDOWN_DAYS,
    PLATELET_COOLDOWN_DAYS,
    PLASMA_COOLDOWN_DAYS,
    QUIET_HOURS_START,
    QUIET_HOURS_END,
    QUIET_HOURS_TZ,
)


def is_in_quiet_hours(dt=None) -> bool:
    """
    Checks if given datetime (defaults to now) is within quiet hours (22:00 to 07:00 in Asia/Dhaka).
    Handles crossing midnight (e.g., 22, 23, 0..6).
    """
    if dt is None:
        dt = timezone.now()
    try:
        tz = ZoneInfo(QUIET_HOURS_TZ)
    except Exception:
        tz = ZoneInfo('Asia/Dhaka')
    local_time = dt.astimezone(tz)
    hour = local_time.hour

    if QUIET_HOURS_START > QUIET_HOURS_END:
        # Crosses midnight: e.g. 22 to 7 -> hour >= 22 or hour < 7
        return hour >= QUIET_HOURS_START or hour < QUIET_HOURS_END
    else:
        return QUIET_HOURS_START <= hour < QUIET_HOURS_END


def evaluate_donor_eligibility(
    donor,
    component: str = 'WHOLE',
    is_critical: bool = False,
    check_quiet_hours: bool = False,
    eval_time=None,
) -> dict:
    """
    Evaluates whether a donor is eligible to donate the specified blood component today.
    If check_quiet_hours is True and not is_critical: checks quiet hours window (22:00-07:00 Asia/Dhaka).
    Critical requests bypass quiet hours check.
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

    # 0a. Suspension check
    if getattr(donor, 'is_suspended', False) or (getattr(donor, 'user', None) and not donor.user.is_active):
        return {
            'is_eligible': False,
            'reason': 'Donor account is currently suspended.',
            'days_remaining': 0,
            'deferred_until': None,
        }

    # 0b. User Intent: ONLY_REQUEST users are not eligible donors
    if getattr(donor, 'user_intent', None) == 'ONLY_REQUEST':
        return {
            'is_eligible': False,
            'reason': 'User has registered to only request blood and does not donate.',
            'days_remaining': 0,
            'deferred_until': None,
        }

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

    # 5. Quiet Hours check (22:00 to 07:00 Asia/Dhaka) - Bypassed for critical requests
    if check_quiet_hours and not is_critical:
        check_dt = eval_time or now
        if is_in_quiet_hours(check_dt):
            return {
                'is_eligible': False,
                'reason': f'Quiet hours active in {QUIET_HOURS_TZ} ({QUIET_HOURS_START}:00 - {QUIET_HOURS_END}:00). Non-critical dispatch withheld.',
                'days_remaining': 0,
                'deferred_until': None,
            }

    return {
        'is_eligible': True,
        'reason': 'Eligible to donate.',
        'days_remaining': 0,
        'deferred_until': None,
    }

