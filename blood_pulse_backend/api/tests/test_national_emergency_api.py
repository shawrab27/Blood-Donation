# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from api.models import BloodRequest, Division, District


class NationalEmergencyRequestsAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='emergency_requester',
            email='requester@example.com',
            password='password123',
        )

        self.div_dhaka, _ = Division.objects.get_or_create(name='Dhaka')
        self.div_chattogram, _ = Division.objects.get_or_create(name='Chattogram')

        self.req_dhaka = BloodRequest.objects.create(
            requester=self.user,
            patient_name='Patient Alpha',
            blood_group='A+',
            units_needed=2,
            urgency='CRITICAL_2H',
            urgency_level='CRITICAL_2H',
            division=self.div_dhaka,
            district='Dhaka',
            hospital_name_other='Dhaka Medical College Hospital',
            contact_phone='+8801712345678',
            status='ACTIVE',
            is_active=True,
            trust_band='HIGH',
            trust_score=85,
        )

        self.req_ctg = BloodRequest.objects.create(
            requester=self.user,
            patient_name='Patient Beta',
            blood_group='B+',
            units_needed=1,
            urgency='CRITICAL_2H',
            urgency_level='CRITICAL_2H',
            division=self.div_chattogram,
            district='Chattogram',
            hospital_name_other='Chittagong Medical College Hospital',
            contact_phone='+8801812345678',
            status='ACTIVE',
            is_active=True,
            trust_band='MEDIUM',
            trust_score=70,
        )

    def test_guest_can_list_emergency_requests_with_privacy(self):
        """Unauthenticated guests can view active emergency requests with masked PII."""
        response = self.client.get('/api/emergency/national/requests/')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(len(data) >= 2)

        # Verify privacy: raw phone, email, raw coordinates must NOT be exposed
        first = data[0]
        self.assertIn('contact_phone_masked', first)
        self.assertNotIn('contact_phone', first)
        self.assertNotIn('requester_email', first)
        self.assertTrue('****' in first['contact_phone_masked'] or '***' in first['contact_phone_masked'])

    def test_filter_by_blood_group(self):
        """Filtering by blood_group returns only matching requests."""
        response = self.client.get('/api/emergency/national/requests/?blood_group=A+')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(len(data) >= 1)
        for item in data:
            self.assertEqual(item['blood_group'], 'A+')

    def test_filter_by_division(self):
        """Filtering by division returns only matching division requests."""
        response = self.client.get('/api/emergency/national/requests/?division=Chattogram')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(len(data) >= 1)
        for item in data:
            self.assertEqual(item['district'], 'Chattogram')
