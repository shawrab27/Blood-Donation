from django.test import TestCase
from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework.test import APIClient
from api.models import DonorProfile
import pygeohash

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
        self.assertEqual(profile.geohash, pygeohash.encode(23.8103, 90.4125, precision=12))

class NearbyDonorsViewTest(TestCase):
    def setUp(self):
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
