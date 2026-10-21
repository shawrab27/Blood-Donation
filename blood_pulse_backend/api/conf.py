# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Configuration constants for BloodPulse Blood Hub engine.
Centralized parameters for wave delays, geofencing, trust scoring, and cooldowns.
"""

# Donation cooldowns (in days) - Fixed 90 Days Standard
DONOR_COOLDOWN_DAYS = 90
WHOLE_BLOOD_COOLDOWN_DAYS = 90
PLATELET_COOLDOWN_DAYS = 14
PLASMA_COOLDOWN_DAYS = 28

# Coordinate privacy fuzzing (approx ~500 meters in degrees)
# 1 degree latitude ~ 111 km -> 0.0045 degrees ~ 500m
COORDINATE_FUZZ_DEGREE = 0.0045

# Deterministic HMAC Location Fuzzing (Step 4 Privacy)
LOCATION_FUZZ_MIN_METERS = 500.0
LOCATION_FUZZ_MAX_METERS = 1000.0
LOCATION_RECOMPUTE_THRESHOLD_METERS = 500.0
LOCATION_GEOHASH_PRECISION = 7  # ~150m cell

import os

# Wave radius limits (in kilometers) - Ladder: 5 -> 25 -> 100 -> 1000 km
# Single list overridable by WAVE_RADIUS_KM env var (e.g. "5,25,100,1000")
def _parse_and_validate_wave_radius_km():
    raw_env = os.environ.get('WAVE_RADIUS_KM', '').strip()
    if raw_env:
        try:
            parsed = [float(x.strip()) for x in raw_env.split(',') if x.strip()]
        except ValueError as e:
            raise ValueError(f"Invalid WAVE_RADIUS_KM environment variable format: '{raw_env}'. Must be comma-separated numbers.") from e
    else:
        parsed = [5.0, 25.0, 100.0, 1000.0]

    # Startup validation: must be list of numbers, positive, strictly ascending
    if not isinstance(parsed, list) or len(parsed) < 1:
        raise ValueError(f"WAVE_RADIUS_KM must be a non-empty list. Got: {parsed}")
    for idx, val in enumerate(parsed):
        if not isinstance(val, (int, float)) or val <= 0:
            raise ValueError(f"WAVE_RADIUS_KM[{idx}] = {val} is invalid. All radii must be positive numbers.")
        if idx > 0 and val <= parsed[idx - 1]:
            raise ValueError(
                f"WAVE_RADIUS_KM must be strictly ascending. Element at index {idx} ({val}) "
                f"<= previous element ({parsed[idx - 1]})."
            )
    return parsed

WAVE_RADIUS_KM = _parse_and_validate_wave_radius_km()

# Quiet hours settings (Asia/Dhaka: 22:00 to 07:00 next day)
QUIET_HOURS_START = int(os.environ.get('QUIET_HOURS_START', '22'))
QUIET_HOURS_END = int(os.environ.get('QUIET_HOURS_END', '7'))
QUIET_HOURS_TZ = os.environ.get('QUIET_HOURS_TZ', 'Asia/Dhaka')

# Per-step wave candidate batch limit
WAVE_CANDIDATE_BATCH_LIMIT = int(os.environ.get('WAVE_CANDIDATE_BATCH_LIMIT', '200'))


# Wave transition timeouts (in minutes) based on urgency level
WAVE_TIMEOUT_MINUTES = {
    'CRITICAL_2H': {
        1: 15,
        2: 20,
        3: 30,
    },
    'URGENT_6H': {
        1: 30,
        2: 45,
        3: 60,
    },
    'TODAY_24H': {
        1: 60,
        2: 120,
        3: 180,
    },
    'SCHEDULED': {
        1: 120,
        2: 240,
        3: 360,
    },
}

# Trust scoring thresholds
TRUST_SCORE_BASE = 50
TRUST_SCORE_HOSPITAL_VERIFIED = 15
TRUST_SCORE_HOSPITAL_UNVERIFIED = 10
TRUST_SCORE_PRESCRIPTION_SLIP = 20
TRUST_SCORE_PATIENT_PHOTO = 10
TRUST_SCORE_ATTENDANT_INFO = 5
TRUST_SCORE_DONOR_FULFILLED_BONUS = 5
TRUST_SCORE_NO_SHOW_PENALTY = 25

TRUST_BAND_LOW_THRESHOLD = 50
TRUST_BAND_HIGH_THRESHOLD = 80

# Scope ceilings by trust band
SCOPE_PERMITTED_BY_TRUST = {
    'LOW': ['LOCAL'],
    'MEDIUM': ['LOCAL', 'DISTRICT'],
    'HIGH': ['LOCAL', 'DISTRICT', 'DIVISION', 'NATIONWIDE'],
}

# Routing & ETA constants
FALLBACK_SPEED_KMH = 20.0
FALLBACK_DETOUR_FACTOR = 1.4

# FCM Multicast batch size
FCM_BATCH_SIZE = 500

# Minimum donors required to display exact count on public screens (Phase 4)
PUBLIC_STATS_MIN_DONORS = 10

# Guest map privacy & aggregation constants
GUEST_MAP_GEOHASH_PRECISION = 4
GUEST_MAP_MIN_CELL_DONORS = 3
GUEST_MAP_MAX_CELLS = 500
GUEST_MAP_CACHE_TIMEOUT_SECONDS = 300  # 5 minutes
CACHE_KEY_GUEST_MAP = 'bp_guest_map_v1'

# Wave candidate processing batch limit (default 200)
WAVE_CANDIDATE_BATCH_LIMIT = int(os.environ.get('WAVE_CANDIDATE_BATCH_LIMIT', '200'))

# Step 6: Feedback & Requester Trust Score weights
FEEDBACK_MIN_REVIEWS_THRESHOLD = int(os.environ.get('FEEDBACK_MIN_REVIEWS_THRESHOLD', '2'))
FEEDBACK_STAR_MULTIPLIER = float(os.environ.get('FEEDBACK_STAR_MULTIPLIER', '5.0'))
FEEDBACK_TAG_WEIGHTS = {
    'GAVE_TRAVEL_COST': 5,
    'GAVE_FOOD': 5,
    'POLITE': 5,
    'RUDE': -15,
    'NEVER_CONTACTED': -20,
}

# Step 8: PulseAI Fare Estimator Configuration
FARE_ROAD_FACTOR = float(os.environ.get('FARE_ROAD_FACTOR', '1.3'))
FARE_MIN_RATE_PER_KM = int(os.environ.get('FARE_MIN_RATE_PER_KM', '15'))
FARE_MAX_RATE_PER_KM = int(os.environ.get('FARE_MAX_RATE_PER_KM', '20'))
FARE_MIN_BASE_FARE = int(os.environ.get('FARE_MIN_BASE_FARE', '50'))
FARE_MAX_BASE_FARE = int(os.environ.get('FARE_MAX_BASE_FARE', '70'))


def get_donor_title(donations: int):
    """
    Returns the official BloodPulse donor title hierarchy based on verified donation count.
    0 donations: None (Unranked / New Member)
    1 donation: "Newcomer"
    2-4 donations: "Regular"
    5-9 donations: "Lifesaver"
    10+ donations: "Hero"
    """
    if donations is None or donations <= 0:
        return None
    if donations == 1:
        return "Newcomer"
    elif 2 <= donations <= 4:
        return "Regular"
    elif 5 <= donations <= 9:
        return "Lifesaver"
    else:
        return "Hero"


# Step 11: Real-time Journey Tracking & Standby Configuration (#31)
STANDBY_TIMEOUT_MINUTES = int(os.environ.get('STANDBY_TIMEOUT_MINUTES', '10'))
DONOR_LOCATION_UPDATE_INTERVAL_SECONDS = int(os.environ.get('DONOR_LOCATION_UPDATE_INTERVAL_SECONDS', '10'))
JOURNEY_NO_SHOW_TIMEOUT_MINUTES = int(os.environ.get('JOURNEY_NO_SHOW_TIMEOUT_MINUTES', '15'))
DONOR_TRACKING_STALE_MINUTES = int(os.environ.get('DONOR_TRACKING_STALE_MINUTES', '10'))
STANDBY_MAX_ATTEMPTS = int(os.environ.get('STANDBY_MAX_ATTEMPTS', '3'))
STANDBY_RADIUS_LADDER_KM = [5, 25, 100, 1000]

