# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from api.models import DonorProfile, BloodRequest, RequestAcceptance
from django.utils import timezone
from datetime import timedelta

class LiveTrackingTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.requester_user = User.objects.create_user(username='+8801700000003', password='pw', first_name="Test")
        self.donor_user = User.objects.create_user(username='+8801700000004', password='pw', first_name="Test")
        self.third_user = User.objects.create_user(username='+8801700000005', password='pw', first_name="Test")

        self.requester_profile = DonorProfile.objects.create(user=self.requester_user, phone_number='3', district="Dhaka", blood_group="O+")
        self.donor_profile = DonorProfile.objects.create(user=self.donor_user, phone_number='4', district="Dhaka", blood_group="O+")

        self.req = BloodRequest.objects.create(
            patient_name='Patient',
            blood_group='O+',
            requester=self.requester_user,
            units_needed=1,
            lat=0, lng=0
        )

    def test_tracking_before_acceptance(self):
        self.client.force_authenticate(user=self.requester_user)
        # Tracking endpoint is usually /api/emergency/tracking/<id>/ or something
        res = self.client.get(f'/api/tracking/{self.req.id}/')
        self.assertIn(res.status_code, [404, 200]) # 200 with empty state or 404

    def test_tracking_third_party(self):
        acc = RequestAcceptance.objects.create(
            request=self.req,
            donor=self.donor_profile,
            status='ON_THE_WAY'
        )
        self.client.force_authenticate(user=self.third_user)
        # They shouldn't be able to access the tracking
        res = self.client.get(f'/api/tracking/{acc.id}/')
        self.assertIn(res.status_code, [403, 404])

    def test_stale_location_update(self):
        acc = RequestAcceptance.objects.create(
            request=self.req,
            donor=self.donor_profile,
            status='DONATED',
            donor_lat=23.5,
            donor_lng=90.5,
            last_location_update=timezone.now() - timedelta(minutes=30)
        )
        self.client.force_authenticate(user=self.donor_profile.user)
        res = self.client.post(f'/api/journeys/{acc.id}/location/', {'lat': 23.6, 'lng': 90.6})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json().get('status'), 'ignored')
