# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Geospatial calculation and privacy fuzzing service.
Implements Haversine distance, deterministic ~500m coordinate fuzzing,
geohash encoding, and ETA estimation.
"""

import math
import hashlib
from api.conf import COORDINATE_FUZZ_DEGREE, FALLBACK_SPEED_KMH, FALLBACK_DETOUR_FACTOR


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Computes great-circle distance between two GPS coordinates in kilometers.
    """
    if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
        return float('inf')

    # Earth radius in kilometers
    r = 6371.0

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    return r * c


def fuzz_coordinates(lat: float, lng: float, seed_id: str or int = None) -> tuple:
    """
    Deterministically fuzzes GPS coordinates to approximately 500 meters (~0.0045 deg).
    Using a hash seed guarantees consistent position representation across requests
    without revealing the donor's exact home or real-time location.
    """
    if lat is None or lng is None:
        return (None, None)

    if seed_id is not None:
        hash_digest = hashlib.md5(f"fuzz_salt_{seed_id}".encode()).hexdigest()
        # Derive angle and normalized radius
        int_angle = int(hash_digest[:4], 16) % 360
        int_offset = int(hash_digest[4:8], 16) % 1000  # 0 to 999
        radius_deg = (0.0035 + (int_offset / 1000.0) * 0.0020)  # ~380m to 600m
        angle_rad = math.radians(int_angle)
        d_lat = radius_deg * math.cos(angle_rad)
        d_lng = radius_deg * math.sin(angle_rad) / max(0.1, math.cos(math.radians(lat)))
        return (round(lat + d_lat, 5), round(lng + d_lng, 5))

    # Grid snap fallback (~500m)
    grid_size = 0.0045
    return (round(round(lat / grid_size) * grid_size, 5),
            round(round(lng / grid_size) * grid_size, 5))


def estimate_eta_minutes(distance_km: float, speed_kmh: float = FALLBACK_SPEED_KMH, detour_factor: float = FALLBACK_DETOUR_FACTOR) -> int:
    """
    Computes road ETA estimate in minutes given great-circle distance.
    Applies detour factor for urban transit in Bangladesh.
    """
    if distance_km <= 0 or distance_km == float('inf'):
        return 0
    effective_distance = distance_km * detour_factor
    hours = effective_distance / max(1.0, speed_kmh)
    return max(1, math.ceil(hours * 60))


# Standard Base32 character map for Geohash
_GEOHASH_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"

def encode_geohash(latitude: float, longitude: float, precision: int = 7) -> str:
    """
    Pure Python geohash encoder without native C dependencies.
    Precision 7 ~ 150m x 150m bounding box.
    """
    if latitude is None or longitude is None:
        return ""

    lat_interval = [-90.0, 90.0]
    lon_interval = [-180.0, 180.0]

    geohash = []
    bits = [16, 8, 4, 2, 1]
    bit = 0
    ch = 0
    even = True

    while len(geohash) < precision:
        if even:
            mid = (lon_interval[0] + lon_interval[1]) / 2.0
            if longitude > mid:
                ch |= bits[bit]
                lon_interval[0] = mid
            else:
                lon_interval[1] = mid
        else:
            mid = (lat_interval[0] + lat_interval[1]) / 2.0
            if latitude > mid:
                ch |= bits[bit]
                lat_interval[0] = mid
            else:
                lat_interval[1] = mid

        even = not even
        if bit < 4:
            bit += 1
        else:
            geohash.append(_GEOHASH_BASE32[ch])
            bit = 0
            ch = 0

    return "".join(geohash)
