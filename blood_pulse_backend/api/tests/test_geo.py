from django.test import TestCase
from api.services.geo import (
    haversine_distance,
    fuzz_coordinates,
    estimate_eta_minutes,
    encode_geohash,
)


class GeoServiceTests(TestCase):
    def test_haversine_distance(self):
        # Dhaka (23.8103, 90.4125) to Chattogram (22.3569, 91.7832) is ~215-225 km
        dist = haversine_distance(23.8103, 90.4125, 22.3569, 91.7832)
        self.assertGreater(dist, 210)
        self.assertLess(dist, 230)

        # Same point distance is 0
        self.assertEqual(haversine_distance(23.8103, 90.4125, 23.8103, 90.4125), 0.0)

    def test_coordinate_fuzzing(self):
        lat, lng = 23.8103, 90.4125
        f_lat, f_lng = fuzz_coordinates(lat, lng, seed_id=42)

        # Should not be identical to exact original
        self.assertNotEqual((lat, lng), (f_lat, f_lng))

        # Distance should be approximately between 350m and 700m (~0.35km - 0.70km)
        dist = haversine_distance(lat, lng, f_lat, f_lng)
        self.assertGreater(dist, 0.30)
        self.assertLess(dist, 0.75)

        # Fuzzing should be deterministic for the same seed_id
        f_lat_2, f_lng_2 = fuzz_coordinates(lat, lng, seed_id=42)
        self.assertEqual((f_lat, f_lng), (f_lat_2, f_lng_2))

    def test_estimate_eta(self):
        # 10 km distance at 20 km/h with 1.4 detour factor
        # 10 * 1.4 = 14 km -> 14 / 20 = 0.7 hrs = 42 minutes
        eta = estimate_eta_minutes(10.0, speed_kmh=20.0, detour_factor=1.4)
        self.assertEqual(eta, 42)

    def test_encode_geohash(self):
        gh = encode_geohash(23.8103, 90.4125, precision=7)
        self.assertIsInstance(gh, str)
        self.assertEqual(len(gh), 7)
