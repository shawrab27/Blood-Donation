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

# Wave radius limits (in kilometers)
WAVE_RADIUS_KM = {
    1: 5.0,     # Local / Campus / immediate vicinity
    2: 25.0,    # District / metro area
    3: 100.0,   # Division / regional
    4: 1000.0,  # Nationwide
}

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
