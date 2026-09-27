# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from api.models import DonorProfile, BloodRequest, RequestAcceptance
from rest_framework.test import APIClient

class BloodHubFulfillmentTests(TestCase):
    def setUp(self):
        self.donor_user = User.objects.create(username='donor1')
        self.donor = DonorProfile.objects.create(user=self.donor_user, phone_number='011', blood_group='A+')
        
        self.requester_user = User.objects.create(username='req1')
        self.requester = DonorProfile.objects.create(user=self.requester_user, phone_number='012', blood_group='O+')
        
        self.blood_req = BloodRequest.objects.create(requester=self.requester_user, is_active=True, status='PENDING')
        self.acceptance = RequestAcceptance.objects.create(request=self.blood_req, donor=self.donor, status='ACCEPTED')
        
    def test_donor_cannot_fulfill_own_donation(self):
        client = APIClient()
        client.force_authenticate(user=self.donor_user)
        
        resp = client.post(f'/api/journeys/{self.acceptance.id}/status/', {'status': 'DONATED'})
        self.assertEqual(resp.status_code, 200)
        
        self.acceptance.refresh_from_db()
        self.blood_req.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'DONATED')
        self.assertNotEqual(self.blood_req.status, 'FULFILLED')
        
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.last_donation_date)

    def test_requester_can_confirm_donation(self):
        self.acceptance.status = 'DONATED'
        self.acceptance.save()
        
        client = APIClient()
        client.force_authenticate(user=self.requester_user)
        resp = client.post(f'/api/journeys/{self.acceptance.id}/status/', {'status': 'CONFIRMED'})
        self.assertEqual(resp.status_code, 200)
        
        self.blood_req.refresh_from_db()
        self.assertEqual(self.blood_req.status, 'FULFILLED')
        
        self.donor.refresh_from_db()
        self.assertIsNotNone(self.donor.last_donation_date)
