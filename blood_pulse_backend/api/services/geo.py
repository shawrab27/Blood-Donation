# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Geospatial calculation and privacy fuzzing service.
Implements Haversine distance, deterministic ~500m coordinate fuzzing,
geohash encoding, and ETA estimation.
"""

import math
import hashlib
import hmac
from django.conf import settings
from api.conf import (
    COORDINATE_FUZZ_DEGREE,
    FALLBACK_SPEED_KMH,
    FALLBACK_DETOUR_FACTOR,
    LOCATION_FUZZ_MIN_METERS,
    LOCATION_FUZZ_MAX_METERS,
    LOCATION_RECOMPUTE_THRESHOLD_METERS,
)


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


def should_recompute_fuzzed_location(old_lat: float, old_lng: float, new_lat: float, new_lng: float, threshold_meters: float = LOCATION_RECOMPUTE_THRESHOLD_METERS) -> bool:
    """
    Determines whether a donor's public fuzzed location needs recomputation.
    Recomputes only when the real location moves more than threshold_meters (default 500m)
    or moves into a different geohash cell.
    """
    if old_lat is None or old_lng is None:
        return True
    if new_lat is None or new_lng is None:
        return False

    dist_km = haversine_distance(old_lat, old_lng, new_lat, new_lng)
    if (dist_km * 1000.0) >= threshold_meters:
        return True

    # Also check if moved across geohash cell boundaries
    old_gh = encode_geohash(old_lat, old_lng, precision=7)
    new_gh = encode_geohash(new_lat, new_lng, precision=7)
    return old_gh != new_gh


def compute_deterministic_fuzzed_location(lat: float, lng: float, donor_id: str or int, secret_key: str = None) -> tuple:
    """
    Computes a deterministic fuzzed GPS point with an offset of 500-1000m
    derived from HMAC-SHA256(server secret, donor id).
    Guarantees the exact same donor at the same location receives the exact same offset,
    preventing multi-query triangulation while preserving local search relevance.
    """
    if lat is None or lng is None:
        return (None, None)

    secret = (secret_key or getattr(settings, 'SECRET_KEY', 'bloodpulse_fuzz_fallback_secret')).encode('utf-8')
    msg = f"donor_location_fuzz_{donor_id}".encode('utf-8')
    digest = hmac.new(secret, msg, hashlib.sha256).hexdigest()

    # 1. Derive bearing (0 to 359 degrees) from first 4 hex bytes
    int_bearing = int(digest[:4], 16) % 360
    # Avoid cardinal poles
    if int_bearing % 90 == 0:
        int_bearing = (int_bearing + 17) % 360
    bearing_rad = math.radians(int_bearing)

    # 2. Derive offset distance (500 to 1000 meters) from next 4 hex bytes
    int_dist = int(digest[4:8], 16) % 10000  # 0 to 9999
    distance_meters = LOCATION_FUZZ_MIN_METERS + (int_dist / 10000.0) * (LOCATION_FUZZ_MAX_METERS - LOCATION_FUZZ_MIN_METERS)
    distance_km = distance_meters / 1000.0

    # 3. Project new coordinates using spherical geodesy
    earth_radius_km = 6371.0
    angular_dist = distance_km / earth_radius_km
    lat1 = math.radians(lat)
    lng1 = math.radians(lng)

    fuzz_lat_rad = math.asin(
        math.sin(lat1) * math.cos(angular_dist) +
        math.cos(lat1) * math.sin(angular_dist) * math.cos(bearing_rad)
    )
    fuzz_lng_rad = lng1 + math.atan2(
        math.sin(bearing_rad) * math.sin(angular_dist) * math.cos(lat1),
        math.cos(angular_dist) - math.sin(lat1) * math.sin(fuzz_lat_rad)
    )

    fuzz_lat = round(math.degrees(fuzz_lat_rad), 6)
    fuzz_lng = round(math.degrees(fuzz_lng_rad), 6)
    return (fuzz_lat, fuzz_lng)


def fuzz_coordinates(lat: float, lng: float, seed_id: str or int = None) -> tuple:
    """
    Deterministically fuzzes GPS coordinates to approximately 500-1000 meters.
    Uses HMAC-derived offset when seed_id is provided, or grid-snap fallback.
    """
    if lat is None or lng is None:
        return (None, None)

    if seed_id is not None:
        return compute_deterministic_fuzzed_location(lat, lng, seed_id)

    # Grid snap fallback (~500m)
    grid_size = 0.0045
    return (round(round(lat / grid_size) * grid_size, 6),
            round(round(lng / grid_size) * grid_size, 6))


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


def decode_geohash_bbox(geohash: str):
    """
    Decodes geohash into (lat_interval, lon_interval)
    where each interval is [min, max].
    """
    if not geohash:
        return ([-90.0, 90.0], [-180.0, 180.0])

    lat_interval = [-90.0, 90.0]
    lon_interval = [-180.0, 180.0]
    even = True

    for c in geohash.lower():
        cd = _GEOHASH_BASE32.find(c)
        if cd == -1:
            continue
        for mask in [16, 8, 4, 2, 1]:
            if even:
                mid = (lon_interval[0] + lon_interval[1]) / 2.0
                if cd & mask:
                    lon_interval[0] = mid
                else:
                    lon_interval[1] = mid
            else:
                mid = (lat_interval[0] + lat_interval[1]) / 2.0
                if cd & mask:
                    lat_interval[0] = mid
                else:
                    lat_interval[1] = mid
            even = not even

    return lat_interval, lon_interval


def decode_geohash(geohash: str) -> tuple:
    """
    Decodes a geohash string into latitude and longitude centroid.
    Returns (lat, lon).
    """
    lat_interval, lon_interval = decode_geohash_bbox(geohash)
    lat = (lat_interval[0] + lat_interval[1]) / 2.0
    lon = (lon_interval[0] + lon_interval[1]) / 2.0
    return (round(lat, 6), round(lon, 6))
