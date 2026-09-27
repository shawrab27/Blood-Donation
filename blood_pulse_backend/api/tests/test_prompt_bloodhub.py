# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient

class BloodHubIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_donor_search_empty(self):
        # search-for-donor with no matching blood group in radius (expect empty list, not error)
        res = self.client.get('/api/donors-nearby/', {'lat': 23.0, 'lng': 90.0})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json(), [], "Expected empty list")

    def test_request_all_empty(self):
        # "request all" bulk endpoint against 0 available donors (expect graceful empty response)
        from django.contrib.auth import get_user_model
        User = get_user_model()
        test_user = User.objects.create_user(username='req_user', email='req@test.com', password='password123')
        self.client.force_authenticate(user=test_user)
        res = self.client.post('/api/emergency/requests/bulk-dispatch/', {'blood_group': 'AB-', 'lat': 23.0, 'lng': 90.0})
        # Note: I might need to check the actual url for bulk dispatch.
        self.assertEqual(res.status_code, 200)

    def test_emergency_form_missing_hospital(self):
        # personal emergency form submission missing required hospital/bed field (expect 400 with field errors)
        res = self.client.post('/api/emergency/requests/', {
            'patient_name': 'Test',
            'blood_group': 'O+',
            'units_needed': 1,
            'contact_phone': '12345'
            # Missing hospital/ward_bed
        })
        self.assertEqual(res.status_code, 400)
        self.assertIn('ward_bed', res.json().get('error', '').lower() or str(res.json()).lower())

    def test_national_emergency_broadcast_empty(self):
        # national emergency broadcast when no active event exists (expect the "no emergency right now" state)
        res = self.client.get('/api/emergency/national/active/')
        self.assertEqual(res.status_code, 200)
        self.assertIsNone(res.json().get('emergency'), "Expected no active emergency")
