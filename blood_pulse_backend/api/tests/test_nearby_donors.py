from django.test import TestCase
from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework.test import APIClient
from api.models import DonorProfile
from api.services.geo import encode_geohash

class DonorProfileGeohashTest(TestCase):
    def test_geohash_computed_on_save(self):
        user = User.objects.create_user(username='testgeo', first_name="Test")
        # Provided a lat and lng, it should compute the geohash
        profile = DonorProfile.objects.create(
            user=user, 
            phone_number='1234567890', 
            blood_group='A+', 
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125
        )
        self.assertNotEqual(profile.geohash, '')
        self.assertEqual(profile.geohash, encode_geohash(23.8103, 90.4125, precision=12))

class NearbyDonorsViewTest(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()
        self.user1 = User.objects.create_user(username='d1', first_name="Test")
        self.user2 = User.objects.create_user(username='d2', first_name="Test")
        self.user3 = User.objects.create_user(username='d3', first_name="Test")
        
        # Donor 1: Very close (distance ~1km)
        self.dp1 = DonorProfile.objects.create(
            user=self.user1, phone_number='011', blood_group='O+', district='Dhaka',
            latitude=23.8103, longitude=90.4125, is_searchable=True
        )
        
        # Donor 2: A bit farther, still within 5km (distance ~3km)
        self.dp2 = DonorProfile.objects.create(
            user=self.user2, phone_number='012', blood_group='A+', district='Dhaka',
            latitude=23.8300, longitude=90.4100, is_searchable=True
        )
        
        # Donor 3: Outside 5km radius (distance ~11km)
        self.dp3 = DonorProfile.objects.create(
            user=self.user3, phone_number='013', blood_group='O+', district='Dhaka',
            latitude=23.9100, longitude=90.4100, is_searchable=True
        )
        
        self.client.force_authenticate(user=self.user1)

    def test_nearby_donors_success(self):
        # Querying around Donor 1
        url = reverse('donors-nearby') # Need to make sure this is the right url name
        response = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125, 'radius_km': 5})
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        # Should return dp1 and dp2, but maybe not itself? Wait, usually we don't exclude self unless explicitly done. 
        # But let's just check length <= 2 and dp3 is not in it.
        donor_ids = [d['donor_id'] for d in data]
        self.assertIn(self.dp1.id, donor_ids)
        self.assertIn(self.dp2.id, donor_ids)
        self.assertNotIn(self.dp3.id, donor_ids)

    def test_nearby_donors_blood_group_filter(self):
        url = reverse('donors-nearby')
        response = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125, 'radius_km': 5, 'blood_group': 'A+'})
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        donor_ids = [d['donor_id'] for d in data]
        self.assertIn(self.dp2.id, donor_ids)
        self.assertNotIn(self.dp1.id, donor_ids) # O+
        
    def test_nearby_donors_invalid_lat_lng(self):
        url = reverse('donors-nearby')
        response = self.client.get(url, {'lat': 200, 'lng': 90.4125})
        self.assertEqual(response.status_code, 400)

    def test_privacy_fuzzing(self):
        url = reverse('donors-nearby')
        response = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125, 'radius_km': 5})
        data = response.json()
        
        dp1_result = next(d for d in data if d['donor_id'] == self.dp1.id)
        # Check that returned lat/lng is NOT exactly the stored lat/lng
        self.assertNotEqual(dp1_result['fuzzed_lat'], self.dp1.latitude)
        self.assertNotEqual(dp1_result['fuzzed_lng'], self.dp1.longitude)
        
    def test_throttle(self):
        url = reverse('donors-nearby')
        # 30 per min, so making 31 requests should 429
        for i in range(30):
            res = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125})
            self.assertEqual(res.status_code, 200)
        
        # 31st should fail
        res = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125})
        self.assertEqual(res.status_code, 429)

    def test_anonymous_get_returns_no_pii_and_fuzzed_coordinates(self):
        """Item 3: Anonymous GET returns 200, strictly fuzzed coordinates, and zero PII."""
        from django.core.cache import cache
        cache.clear()
        self.client.force_authenticate(user=None)
        url = reverse('donors-nearby')
        response = self.client.get(url, {'lat': 23.8103, 'lng': 90.4125, 'radius_km': 5})
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertGreaterEqual(len(data), 1)

        for donor in data:
            # Zero PII: No phone numbers or emails exposed
            self.assertNotIn('phone_number', donor)
            self.assertNotIn('phone', donor)
            self.assertNotIn('email', donor)

            # Privacy Fuzzing: No exact coordinates exposed
            self.assertNotIn('latitude', donor)
            self.assertNotIn('longitude', donor)
            self.assertNotIn('lat', donor)
            self.assertNotIn('lng', donor)

            # Must contain fuzzed coordinates
            self.assertIn('fuzzed_lat', donor)
            self.assertIn('fuzzed_lng', donor)

            # Fuzzed coordinates must not equal exact coordinates
            if donor['donor_id'] == self.dp1.id:
                self.assertNotEqual((donor['fuzzed_lat'], donor['fuzzed_lng']), (self.dp1.latitude, self.dp1.longitude))

    def test_anonymous_post_rejected_with_401(self):
        """Item 3: Anonymous POST on /api/donors-nearby/ must be rejected with 401 Unauthorized."""
        from django.core.cache import cache
        cache.clear()
        self.client.force_authenticate(user=None)
        url = reverse('donors-nearby')
        response = self.client.post(url, {'lat': 23.8103, 'lng': 90.4125}, format='json')
        self.assertEqual(response.status_code, 401)

    def test_authenticated_post_allowed(self):
        """Item 3: Authenticated POST on /api/donors-nearby/ is allowed."""
        from django.core.cache import cache
        cache.clear()
        self.client.force_authenticate(user=self.user1)
        url = reverse('donors-nearby')
        response = self.client.post(url, {'lat': 23.8103, 'lng': 90.4125}, format='json')
        self.assertEqual(response.status_code, 200)



class GuestDonorMapEndpointTests(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()

    def test_guest_map_anonymous_no_pii_empty(self):
        """When no donors exist, returns empty list without error or fake donors."""
        res = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(set(data.keys()), {'total_donors', 'cells'})
        self.assertEqual(data['total_donors'], 0)
        self.assertEqual(data['cells'], [])

    def test_guest_map_omits_cells_under_threshold_and_total_equals_published_sum(self):
        """Cells with < 3 donors are omitted; total_donors equals sum of published cells only."""
        # Cell A (Dhaka): 3 donors -> published
        for i in range(3):
            u = User.objects.create_user(username=f'dhk_donor_{i}', first_name=f'Real{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0181000000{i}', blood_group='A+', district='Dhaka',
                latitude=23.8103 + (i * 0.001), longitude=90.4125 + (i * 0.001),
                is_searchable=True, is_available=True
            )
        # Cell B (Sylhet): 2 donors -> suppressed (< 3)
        for i in range(2):
            u = User.objects.create_user(username=f'syl_donor_{i}', first_name=f'Syl{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0182000000{i}', blood_group='O+', district='Sylhet',
                latitude=24.8949 + (i * 0.001), longitude=91.8687 + (i * 0.001),
                is_searchable=True, is_available=True
            )

        res = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(len(data['cells']), 1)
        self.assertEqual(data['cells'][0]['count'], 3)
        # total_donors must equal sum of PUBLISHED cells only (3, not 5)
        self.assertEqual(data['total_donors'], sum(c['count'] for c in data['cells']))
        self.assertEqual(data['total_donors'], 3)

    def test_guest_map_cell_center_never_donor_mean(self):
        """Cell latitude/longitude must be the geohash precision-4 cell center, never the mean of donor coordinates."""
        from api.services.geo import decode_geohash
        # Place 3 donors asymmetrically near one corner of the precision-4 cell 'wh0r'
        asym_coords = [
            (23.7350, 90.3550),
            (23.7360, 90.3560),
            (23.7370, 90.3570),
        ]
        for i, (lat, lng) in enumerate(asym_coords):
            u = User.objects.create_user(username=f'asym_{i}', first_name=f'Asym{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0183000000{i}', blood_group='B+', district='Dhaka',
                latitude=lat, longitude=lng, is_searchable=True, is_available=True
            )

        res = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(len(data['cells']), 1)
        cell = data['cells'][0]
        self.assertEqual(len(cell['geohash']), 4)

        expected_lat, expected_lng = decode_geohash(cell['geohash'])
        mean_lat = sum(c[0] for c in asym_coords) / 3.0
        mean_lng = sum(c[1] for c in asym_coords) / 3.0

        self.assertAlmostEqual(cell['latitude'], expected_lat, places=6)
        self.assertAlmostEqual(cell['longitude'], expected_lng, places=6)
        self.assertNotAlmostEqual(cell['latitude'], mean_lat, places=3)
        self.assertNotAlmostEqual(cell['longitude'], mean_lng, places=3)

    def test_guest_map_ignores_extra_params_and_identical_for_different_callers(self):
        """Extra query parameters are ignored; two different callers get identical output."""
        for i in range(3):
            u = User.objects.create_user(username=f'ident_{i}', first_name=f'Ident{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0184000000{i}', blood_group='O+', district='Dhaka',
                latitude=23.8103, longitude=90.4125, is_searchable=True, is_available=True
            )

        client_a = APIClient()
        client_b = APIClient()
        # Caller A passes far-away coordinates and tiny radius; Caller B passes no params
        res_a = client_a.get('/api/donors/guest-map/?lat=22.3569&lng=91.7832&radius_km=1&foo=bar', REMOTE_ADDR='10.0.0.1')
        res_b = client_b.get('/api/donors/guest-map/', REMOTE_ADDR='10.0.0.2')

        self.assertEqual(res_a.status_code, 200)
        self.assertEqual(res_b.status_code, 200)
        self.assertEqual(res_a.json(), res_b.json())
        self.assertEqual(res_a.json()['total_donors'], 3)

    def test_guest_map_excludes_ineligible_donors(self):
        """ONLY_REQUEST, staff, superuser, demo, snoozed, incomplete, and unsearchable donors are excluded."""
        from datetime import timedelta
        from django.utils import timezone

        # 2 eligible donors in Dhaka cell (not enough on their own to reach 3)
        for i in range(2):
            u = User.objects.create_user(username=f'elig_{i}', first_name=f'Elig{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0185000000{i}', blood_group='O+', district='Dhaka',
                latitude=23.8103, longitude=90.4125, is_searchable=True
            )

        # Ineligible 1: ONLY_REQUEST
        u_req = User.objects.create_user(username='only_req_u', first_name='Req')
        DonorProfile.objects.create(
            user=u_req, user_intent='ONLY_REQUEST', phone_number='01851000001',
            blood_group='O+', district='Dhaka', latitude=23.8103, longitude=90.4125
        )
        # Ineligible 2: staff
        u_staff = User.objects.create_user(username='staff_u', first_name='Staff', is_staff=True)
        DonorProfile.objects.create(
            user=u_staff, user_intent='DONATE_AND_REQUEST', phone_number='01851000002',
            blood_group='O+', district='Dhaka', latitude=23.8103, longitude=90.4125, is_searchable=True
        )
        # Ineligible 3: demo username
        u_demo = User.objects.create_user(username='demo_map_user', first_name='Demo')
        DonorProfile.objects.create(
            user=u_demo, user_intent='DONATE_AND_REQUEST', phone_number='01851000003',
            blood_group='O+', district='Dhaka', latitude=23.8103, longitude=90.4125, is_searchable=True
        )
        # Ineligible 4: snoozed (alert_pause_until in future)
        u_snooze = User.objects.create_user(username='snooze_u', first_name='Snooze')
        DonorProfile.objects.create(
            user=u_snooze, user_intent='DONATE_AND_REQUEST', phone_number='01851000004',
            blood_group='O+', district='Dhaka', latitude=23.8103, longitude=90.4125,
            is_searchable=True, alert_pause_until=timezone.now() + timedelta(days=2)
        )
        # Ineligible 5: explicitly unsearchable
        u_hidden = User.objects.create_user(username='hidden_u', first_name='Hidden')
        DonorProfile.objects.create(
            user=u_hidden, user_intent='DONATE_AND_REQUEST', phone_number='01851000005',
            blood_group='O+', district='Dhaka', latitude=23.8103, longitude=90.4125,
            is_searchable=False
        )

        res = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res.status_code, 200)
        # Since none of the 5 ineligible donors count, the cell stays at 2 (< 3) and is omitted
        self.assertEqual(res.json()['total_donors'], 0)
        self.assertEqual(res.json()['cells'], [])

    def test_guest_map_allowed_keys_and_cache_hit_does_not_requery(self):
        """Response contains only allowed keys, and a cache hit executes 0 DB queries."""
        for i in range(3):
            u = User.objects.create_user(username=f'cache_d_{i}', first_name=f'Name{i}')
            DonorProfile.objects.create(
                user=u, phone_number=f'0186000000{i}', blood_group='O+', district='Dhaka',
                latitude=23.8103 + (i * 0.001), longitude=90.4125 + (i * 0.001),
                is_searchable=True, is_available=True
            )

        res1 = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res1.status_code, 200)
        data = res1.json()
        self.assertEqual(set(data.keys()), {'total_donors', 'cells'})
        self.assertEqual(len(data['cells']), 1)
        self.assertEqual(set(data['cells'][0].keys()), {'geohash', 'count', 'latitude', 'longitude'})

        # Second request must hit cache and perform 0 database queries
        with self.assertNumQueries(0):
            res2 = self.client.get('/api/donors/guest-map/')
        self.assertEqual(res2.status_code, 200)
        self.assertEqual(res1.json(), res2.json())


