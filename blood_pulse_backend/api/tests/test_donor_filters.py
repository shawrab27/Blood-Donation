# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from api.models import DonorProfile, District, Division

User = get_user_model()

class DonorFilterD9TestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Divisions
        self.div_dhaka = Division.objects.create(name='Dhaka')
        self.div_chattogram = Division.objects.create(name='Chattogram')

        # Districts
        self.dist_dhaka = District.objects.create(name='Dhaka', division=self.div_dhaka)
        self.dist_gazipur = District.objects.create(name='Gazipur', division=self.div_dhaka)
        self.dist_cumilla = District.objects.create(name='Cumilla', division=self.div_chattogram)

        # Donor 1: A+, Dhaka, Dhaka
        u1 = User.objects.create_user(username='donor1', password='pw')
        self.d1 = DonorProfile.objects.create(
            user=u1, phone_number='01700000001', blood_group='A+', district='Dhaka', is_profile_complete=True
        )

        # Donor 2: B+, Gazipur, Dhaka
        u2 = User.objects.create_user(username='donor2', password='pw')
        self.d2 = DonorProfile.objects.create(
            user=u2, phone_number='01700000002', blood_group='B+', district='Gazipur', is_profile_complete=True
        )

        # Donor 3: A+, Cumilla, Chattogram
        u3 = User.objects.create_user(username='donor3', password='pw')
        self.d3 = DonorProfile.objects.create(
            user=u3, phone_number='01700000003', blood_group='A+', district='Cumilla', is_profile_complete=True
        )

        # Donor 4: O+, Cumilla, Chattogram
        u4 = User.objects.create_user(username='donor4', password='pw')
        self.d4 = DonorProfile.objects.create(
            user=u4, phone_number='01700000004', blood_group='O+', district='Cumilla', is_profile_complete=True
        )

    def test_nothing_chosen_returns_everything(self):
        """Nothing chosen -> returns all donors."""
        response = self.client.get('/api/donors/')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        self.assertEqual(len(results), 4)

    def test_no_blood_group_returns_all_donors_in_area(self):
        """No blood group specified -> returns all donors across the chosen area or all."""
        response = self.client.get('/api/donors/?division=Dhaka')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        # Dhaka division has donor1 (Dhaka) and donor2 (Gazipur)
        donor_ids = [d['id'] for d in results]
        self.assertIn(self.d1.id, donor_ids)
        self.assertIn(self.d2.id, donor_ids)
        self.assertNotIn(self.d3.id, donor_ids)

    def test_blood_group_exact_group_only(self):
        """Blood group chosen -> exact group only (no compatible/other groups included)."""
        response = self.client.get('/api/donors/?blood_group=A+')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        self.assertEqual(len(results), 2)
        donor_ids = [d['id'] for d in results]
        self.assertIn(self.d1.id, donor_ids)
        self.assertIn(self.d3.id, donor_ids)
        for d in results:
            self.assertEqual(d['blood_group'], 'A+')

    def test_zila_chosen_returns_that_zila(self):
        """Zila chosen -> returns only that zila's donors."""
        response = self.client.get('/api/donors/?district=Gazipur')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['id'], self.d2.id)

    def test_no_zila_returns_whole_chosen_division(self):
        """No zila chosen -> whole chosen division returned."""
        response = self.client.get('/api/donors/?division=Chattogram')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        self.assertEqual(len(results), 2)
        donor_ids = [d['id'] for d in results]
        self.assertIn(self.d3.id, donor_ids)
        self.assertIn(self.d4.id, donor_ids)

    def test_blood_group_and_area_together(self):
        """Blood group and area together -> filters by both exact blood group AND area."""
        response = self.client.get('/api/donors/?blood_group=A+&division=Dhaka')
        self.assertEqual(response.status_code, 200)
        results = response.json()
        if isinstance(results, dict) and 'results' in results:
            results = results['results']
        # In Dhaka division, only donor1 is A+
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['id'], self.d1.id)
        self.assertEqual(results[0]['blood_group'], 'A+')
