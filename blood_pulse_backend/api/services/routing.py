# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
OpenStreetMap / OSRM Free Routing Service (Anomaly #28).
Provides zero-cost routing using OSRM public router with caching,
falling back to haversine straight-line distance with a 1.4 detour factor
and 20 km/h average city speed (per BloodHub Rule 9).
Requires zero paid Google Maps or Mapbox API keys.
"""

import logging
import requests
from django.core.cache import cache
from api.services.geo import haversine_distance

logger = logging.getLogger(__name__)

FALLBACK_SPEED_KMH = 20.0
DETOUR_FACTOR = 1.4
CACHE_TTL_SECONDS = 300  # 5 minutes for dynamic route queries


def get_route_or_fallback(from_lat: float, from_lng: float, to_lat: float, to_lng: float, overview: bool = False) -> dict:
    """
    Computes driving distance, duration, and geometry between two coordinates
    without any paid APIs.
    Tries OSRM public router first; if down or timed out, falls back gracefully
    to haversine straight-line distance with a 1.4 detour factor at 20 km/h.
    """
    cache_key = f"osrm_route_{round(float(from_lat), 4)}_{round(float(from_lng), 4)}_{round(float(to_lat), 4)}_{round(float(to_lng), 4)}_{overview}"
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    # Attempt OSRM public driving API
    try:
        coords = f"{float(from_lng)},{float(from_lat)};{float(to_lng)},{float(to_lat)}"
        overview_param = 'full' if overview else 'false'
        res = requests.get(
            f'https://router.project-osrm.org/route/v1/driving/{coords}',
            params={'overview': overview_param, 'geometries': 'geojson'},
            headers={'User-Agent': 'BloodPulse/1.0 (com.bloodpulse.app)'},
            timeout=3.5,
        )
        if res.status_code == 200:
            data = res.json()
            routes = data.get('routes', [])
            if routes:
                distance_meters = routes[0].get('distance', 0.0)
                duration_seconds = routes[0].get('duration', 0.0)
                geometry = routes[0].get('geometry', {}).get('coordinates', []) if overview else []
                result = {
                    'distance_km': round(distance_meters / 1000.0, 2),
                    'duration_min': max(1, round(duration_seconds / 60.0)),
                    'provider': 'osrm',
                    'is_fallback': False,
                    'coordinates': geometry if geometry else [[float(from_lng), float(from_lat)], [float(to_lng), float(to_lat)]],
                }
                cache.set(cache_key, result, CACHE_TTL_SECONDS)
                return result
    except Exception as exc:
        logger.warning(f"OSRM routing failed: {exc}, using straight-line fallback.")

    # Rule 9 fallback: straight-line distance with 1.4 detour factor at 20 km/h
    straight_line_km = haversine_distance(float(from_lat), float(from_lng), float(to_lat), float(to_lng))
    estimated_distance_km = round(straight_line_km * DETOUR_FACTOR, 2)
    estimated_duration_min = max(1, round((estimated_distance_km / FALLBACK_SPEED_KMH) * 60.0))

    fallback_result = {
        'distance_km': estimated_distance_km,
        'duration_min': estimated_duration_min,
        'provider': 'straight_line_fallback',
        'is_fallback': True,
        'coordinates': [[float(from_lng), float(from_lat)], [float(to_lng), float(to_lat)]],
    }
    cache.set(cache_key, fallback_result, 60)
    return fallback_result


def estimate_eta_and_distance(from_lat: float, from_lng: float, to_lat: float, to_lng: float) -> tuple[float, int]:
    """
    Convenience helper returning (distance_km, eta_minutes) with fallback support.
    """
    route = get_route_or_fallback(from_lat, from_lng, to_lat, to_lng, overview=False)
    return route['distance_km'], route['duration_min']
