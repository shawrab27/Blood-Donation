"""
64 Bangladesh District Centroids (WGS-84 coordinates).
Single source of truth for location-aware feed district resolution and geo-mapping.
Matches BD_DIVISIONS_AND_DISTRICTS canonical names.
"""

from typing import Dict, Tuple, Optional
import math
from api.services.geo import haversine_distance

DISTRICT_CENTROIDS: Dict[str, Tuple[float, float]] = {
    # Dhaka Division (13)
    'Dhaka': (23.8103, 90.4125),
    'Faridpur': (23.6070, 89.8429),
    'Gazipur': (24.0022, 90.4264),
    'Gopalganj': (23.0051, 89.8266),
    'Kishoreganj': (24.4449, 90.7766),
    'Madaripur': (23.1641, 90.1897),
    'Manikganj': (23.8617, 90.0003),
    'Munshiganj': (23.5422, 90.5305),
    'Narayanganj': (23.6238, 90.5000),
    'Narsingdi': (23.9193, 90.7176),
    'Rajbari': (23.7574, 89.6445),
    'Shariatpur': (23.2423, 90.3540),
    'Tangail': (24.2513, 89.9167),

    # Chattogram Division (11)
    'Bandarban': (22.1953, 92.2184),
    'Brahmanbaria': (23.9571, 91.1115),
    'Chandpur': (23.2333, 90.6667),
    'Chattogram': (22.3569, 91.7832),
    "Cox's Bazar": (21.4272, 92.0058),
    'Cumilla': (23.4607, 91.1809),
    'Feni': (23.0186, 91.3966),
    'Khagrachhari': (23.1193, 91.9847),
    'Lakshmipur': (22.9425, 90.8412),
    'Noakhali': (22.8696, 91.0994),
    'Rangamati': (22.6533, 92.1753),

    # Rajshahi Division (8)
    'Bogura': (24.8465, 89.3770),
    'Chapai Nawabganj': (24.5965, 88.2775),
    'Joypurhat': (25.1015, 89.0277),
    'Naogaon': (24.8109, 88.9416),
    'Natore': (24.4206, 88.9324),
    'Pabna': (24.0064, 89.2372),
    'Rajshahi': (24.3745, 88.6042),
    'Sirajganj': (24.4534, 89.7008),

    # Khulna Division (10)
    'Bagerhat': (22.6516, 89.7859),
    'Chuadanga': (23.6402, 88.8418),
    'Jashore': (23.1664, 89.2081),
    'Jhenaidah': (23.5450, 89.1726),
    'Khulna': (22.8456, 89.5403),
    'Kushtia': (23.9013, 89.1204),
    'Magura': (23.4873, 89.4198),
    'Meherpur': (23.7622, 88.6318),
    'Narail': (23.1725, 89.5127),
    'Satkhira': (22.7185, 89.0705),

    # Barishal Division (6)
    'Barguna': (22.1570, 90.1256),
    'Barishal': (22.7010, 90.3535),
    'Bhola': (22.6859, 90.6481),
    'Jhalokati': (22.6406, 90.1987),
    'Patuakhali': (22.3596, 90.3299),
    'Pirojpur': (22.5841, 89.9720),

    # Sylhet Division (4)
    'Habiganj': (24.3749, 91.4155),
    'Moulvibazar': (24.4829, 91.7774),
    'Sunamganj': (25.0658, 91.3950),
    'Sylhet': (24.8949, 91.8687),

    # Rangpur Division (8)
    'Dinajpur': (25.6217, 88.6355),
    'Gaibandha': (25.3288, 89.5406),
    'Kurigram': (25.8054, 89.6362),
    'Lalmonirhat': (25.9923, 89.2847),
    'Nilphamari': (25.9318, 88.8560),
    'Panchagarh': (26.3411, 88.5542),
    'Rangpur': (25.7439, 89.2752),
    'Thakurgaon': (26.0337, 88.4617),

    # Mymensingh Division (4)
    'Jamalpur': (24.9375, 89.9378),
    'Mymensingh': (24.7471, 90.4203),
    'Netrokona': (24.8709, 90.7279),
    'Sherpur': (25.0205, 90.0153),
}

def find_nearest_district(lat: float, lng: float) -> Optional[str]:
    """
    Finds the nearest Bangladesh canonical district for the given GPS coordinates
    using haversine distance. Returns canonical district name.
    """
    if lat is None or lng is None:
        return None

    best_dist = float('inf')
    best_district = None

    for district_name, (c_lat, c_lng) in DISTRICT_CENTROIDS.items():
        dist = haversine_distance(lat, lng, c_lat, c_lng)
        if dist < best_dist:
            best_dist = dist
            best_district = district_name

    return best_district
