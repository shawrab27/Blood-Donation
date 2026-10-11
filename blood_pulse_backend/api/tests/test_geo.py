# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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

    @staticmethod
    def _reference_geohash_encode(latitude: float, longitude: float, precision: int = 12) -> str:
        """Independent bit-bisection reference implementation of Geohash (Niemeyer 2008)."""
        alphabet = '0123456789bcdefghjkmnpqrstuvwxyz'
        lat_min, lat_max = -90.0, 90.0
        lon_min, lon_max = -180.0, 180.0
        bits = []
        total_bits = precision * 5
        for i in range(total_bits):
            if i % 2 == 0:
                mid = (lon_min + lon_max) / 2.0
                if longitude >= mid:
                    bits.append(1)
                    lon_min = mid
                else:
                    bits.append(0)
                    lon_max = mid
            else:
                mid = (lat_min + lat_max) / 2.0
                if latitude >= mid:
                    bits.append(1)
                    lat_min = mid
                else:
                    bits.append(0)
                    lat_max = mid
        chars = []
        for idx in range(0, total_bits, 5):
            val = (
                (bits[idx] << 4)
                | (bits[idx + 1] << 3)
                | (bits[idx + 2] << 2)
                | (bits[idx + 3] << 1)
                | bits[idx + 4]
            )
            chars.append(alphabet[val])
        return ''.join(chars)

    def test_geohash_parity_against_reference(self):
        import random
        from api.services.geo import decode_geohash
        try:
            import geohash2
        except ImportError:
            geohash2 = None

        # Test 200 pseudo-random Bangladesh coordinates at precisions 4, 5, 6, 7, 9, 12
        random.seed(42)
        for _ in range(200):
            lat = random.uniform(20.5, 26.5)
            lon = random.uniform(88.0, 92.5)
            for prec in [4, 5, 6, 7, 9, 12]:
                encoded = encode_geohash(lat, lon, precision=prec)
                self.assertEqual(len(encoded), prec)
                self.assertEqual(
                    encoded,
                    self._reference_geohash_encode(lat, lon, precision=prec),
                )
                if geohash2 is not None:
                    self.assertEqual(
                        encoded,
                        geohash2.encode(lat, lon, precision=prec),
                    )
            # Precision 12 decode roundtrip within <= 1e-6 degrees (decode_geohash rounds to 6 decimals)
            dec_lat, dec_lon = decode_geohash(encode_geohash(lat, lon, precision=12))
            self.assertAlmostEqual(lat, dec_lat, delta=1e-6)
            self.assertAlmostEqual(lon, dec_lon, delta=1e-6)

    def test_recompute_stored_geohash_for_all_donor_profiles(self):
        """Recomputes the stored geohash of every DonorProfile row in the test DB and expects equality."""
        from django.contrib.auth.models import User
        from api.models import DonorProfile

        sample_points = [
            ('dhk_geo', 'Dhaka', 23.8103, 90.4125),
            ('ctg_geo', 'Chattogram', 22.3569, 91.7832),
            ('syl_geo', 'Sylhet', 24.8949, 91.8687),
            ('raj_geo', 'Rajshahi', 24.3745, 88.6042),
            ('khl_geo', 'Khulna', 22.8456, 89.5403),
        ]
        for idx, (uname, dist, lat, lng) in enumerate(sample_points):
            u = User.objects.create_user(username=uname, first_name=f'Geo{idx}')
            DonorProfile.objects.create(
                user=u,
                phone_number=f'0189100000{idx}',
                blood_group='O+',
                district=dist,
                latitude=lat,
                longitude=lng,
            )

        rows = list(DonorProfile.objects.all())
        self.assertGreaterEqual(len(rows), 5)
        for profile in rows:
            lat = profile.last_lat if profile.last_lat is not None else profile.latitude
            lng = profile.last_lng if profile.last_lng is not None else profile.longitude
            if lat is not None and lng is not None:
                expected = encode_geohash(lat, lng, precision=12)
                self.assertEqual(profile.geohash, expected)

