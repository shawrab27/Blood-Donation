# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from unittest.mock import patch
from django.core.cache import cache
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from api.models import DonorProfile, DonorReview, BloodRequest, District, Division
from api.throttles import UserLocationAnonThrottle


class UserLocationAndReviewsH1Tests(TestCase):
    """
    Tests H-1 Item 3:
    1. users/location (AllowAny):
       - Anonymous throttle
       - Validate lat/lng ranges (-90 to 90, -180 to 180)
    2. profile/<donor_id>/reviews GET:
       - Public viewers see reviewer first name + initial only
       - No phone, no email, no reviewer user id leaked
    """

    def setUp(self):
        cache.clear()
        self.client = APIClient()

        # Divisions and Districts
        self.division, _ = Division.objects.get_or_create(name='Dhaka')
        self.district, _ = District.objects.get_or_create(
            name='Dhaka',
            defaults={'division': self.division}
        )

        # Donor to be reviewed
        self.donor_user = User.objects.create_user(
            username='01700000001',
            email='donor@example.com',
            password='Password123!',
            first_name='Rahim',
            last_name='Uddin'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='01700000001',
            is_available=True,
            is_profile_complete=True
        )

        # Reviewer 1 (First name + Last name)
        self.reviewer_user1 = User.objects.create_user(
            username='01700000002',
            email='reviewer1@example.com',
            password='Password123!',
            first_name='Arman',
            last_name='Khan'
        )

        # Reviewer 2 (Phone as username, empty first/last name)
        self.reviewer_user2 = User.objects.create_user(
            username='01799998888',
            email='secret@example.com',
            password='Password123!',
            first_name='',
            last_name=''
        )

        # Staff user
        self.staff_user = User.objects.create_superuser(
            username='staff_admin',
            email='staff@example.com',
            password='Password123!'
        )

        # Blood request for reviews
        from api.models import Hospital
        self.hospital = Hospital.objects.create(name='Dhaka Medical College', district='Dhaka')
        self.blood_req = BloodRequest.objects.create(
            requester=self.reviewer_user1,
            patient_name='Patient A',
            blood_group='B+',
            district='Dhaka',
            hospital=self.hospital,
            status='DONATED'
        )

        # Create review 1
        self.review1 = DonorReview.objects.create(
            donor=self.donor_profile,
            reviewer=self.reviewer_user1,
            blood_request=self.blood_req,
            stars=5,
            tag='Punctual',
            comment='Excellent donor, on time.'
        )

        # Create review 2
        blood_req2 = BloodRequest.objects.create(
            requester=self.reviewer_user2,
            patient_name='Patient B',
            blood_group='B+',
            district='Dhaka',
            hospital_name_other='Square Hospital',
            status='DONATED'
        )
        self.review2 = DonorReview.objects.create(
            donor=self.donor_profile,
            reviewer=self.reviewer_user2,
            blood_request=blood_req2,
            stars=4,
            tag='Helpful',
            comment='Very helpful person.'
        )

    def tearDown(self):
        cache.clear()

    # --- users/location Tests ---

    def test_location_sync_valid_lat_lng_returns_district(self):
        resp = self.client.post('/api/users/location/', {'lat': 23.8103, 'lng': 90.4125}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['district_name'], 'Dhaka')

    def test_location_sync_rejects_out_of_range_latitude(self):
        # Lat > 90
        resp = self.client.post('/api/users/location/', {'lat': 95.0, 'lng': 90.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Latitude must be between -90 and 90', resp.data.get('error', ''))

        # Lat < -90
        resp = self.client.post('/api/users/location/', {'lat': -95.0, 'lng': 90.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_location_sync_rejects_out_of_range_longitude(self):
        # Lng > 180
        resp = self.client.post('/api/users/location/', {'lat': 23.0, 'lng': 185.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('longitude between -180 and 180', resp.data.get('error', ''))

        # Lng < -180
        resp = self.client.post('/api/users/location/', {'lat': 23.0, 'lng': -185.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_location_sync_rejects_missing_pair_or_malformed(self):
        resp = self.client.post('/api/users/location/', {'lat': 23.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

        resp = self.client.post('/api/users/location/', {'lat': 'invalid', 'lng': 'numbers'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_location_anon_throttle_configured(self):
        throttle = UserLocationAnonThrottle()
        self.assertEqual(throttle.scope, 'user_location_anon')
        self.assertEqual(throttle.get_rate(), '60/hour')

    # --- profile/<donor_id>/reviews GET Tests ---

    def test_public_view_reviews_masks_reviewer_names_to_first_plus_initial(self):
        """Public viewer gets first name + initial only, no phone/email/user id leaked."""
        resp = self.client.get(f'/api/profile/{self.donor_profile.id}/reviews/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        results = resp.data['results']
        self.assertEqual(len(results), 2)

        # Review 1: Arman Khan -> "Arman K."
        rev1 = next(r for r in results if r['id'] == self.review1.id)
        self.assertEqual(rev1['reviewer_name'], 'Arman K.')
        self.assertNotIn('01700000002', str(rev1))
        self.assertNotIn('reviewer1@example.com', str(rev1))
        self.assertNotIn('reviewer_id', rev1)
        self.assertNotIn('user_id', rev1)

        # Review 2: username is phone 01799998888, empty name -> "Donor" (never phone)
        rev2 = next(r for r in results if r['id'] == self.review2.id)
        self.assertEqual(rev2['reviewer_name'], 'Donor')
        self.assertNotIn('01799998888', str(rev2))
        self.assertNotIn('secret@example.com', str(rev2))
        self.assertNotIn('reviewer_id', rev2)

    def test_staff_view_reviews_can_see_full_name(self):
        """Staff viewer can view full reviewer name."""
        self.client.force_authenticate(user=self.staff_user)
        resp = self.client.get(f'/api/profile/{self.donor_profile.id}/reviews/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        results = resp.data['results']

        rev1 = next(r for r in results if r['id'] == self.review1.id)
        self.assertEqual(rev1['reviewer_name'], 'Arman Khan')
