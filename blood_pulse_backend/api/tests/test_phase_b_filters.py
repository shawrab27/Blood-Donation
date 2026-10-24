# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from api.models import DonorProfile, District, Division, Upazila


class PhaseBFilterTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Divisions & Districts
        self.div_rajshahi = Division.objects.create(name='Rajshahi')
        self.dist_bogura = District.objects.create(name='Bogura', division=self.div_rajshahi)

        self.div_dhaka = Division.objects.create(name='Dhaka')
        self.dist_dhaka = District.objects.create(name='Dhaka', division=self.div_dhaka)

        # Create donors: one A+, one O+, one B+
        self.u1 = User.objects.create_user(username='donor_a_pos', password='password123')
        self.p1 = DonorProfile.objects.create(
            user=self.u1,
            blood_group='A+',
            district='Bogura',
            phone_number='+8801700333331',
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
        )

        self.u2 = User.objects.create_user(username='donor_o_pos', password='password123')
        self.p2 = DonorProfile.objects.create(
            user=self.u2,
            blood_group='O+',
            district='Bogura',
            phone_number='+8801700333332',
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
        )

        self.u3 = User.objects.create_user(username='donor_b_pos', password='password123')
        self.p3 = DonorProfile.objects.create(
            user=self.u3,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801700333333',
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
        )

    def test_donor_search_exact_blood_group_matching(self):
        """B1: Searching for A+ must return ONLY A+ donors, not O+ (even though O+ is compatible for transfusions)."""
        res = self.client.get('/api/donors/search/?blood_group=A%2B&district=Bogura&exact_match=true')
        self.assertEqual(res.status_code, 200)
        results = res.json()['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['blood_group'], 'A+')

    def test_donors_viewset_query_param_filtering(self):
        """B1: /api/donors/ list endpoint filters by query params (blood_group, district, division)."""
        # Filter by blood_group B+
        res = self.client.get('/api/donors/?blood_group=B%2B')
        self.assertEqual(res.status_code, 200)
        results = res.json()
        b_donors = [d for d in results if d.get('blood_group') == 'B+']
        self.assertTrue(len(b_donors) >= 1)

        # Filter by district Bogura
        res_dist = self.client.get('/api/donors/?district=Bogura')
        self.assertEqual(res_dist.status_code, 200)
        bogura_ids = [d['id'] for d in res_dist.json()]
        self.assertEqual(len(bogura_ids), 2)
        self.assertIn(self.p1.id, bogura_ids)
        self.assertIn(self.p2.id, bogura_ids)
        self.assertNotIn(self.p3.id, bogura_ids)

    def test_upazila_search_returns_non_empty_list_for_district(self):
        """B2: Upazila search returns canonical upazilas for district even when q is empty."""
        res = self.client.get('/api/locations/upazila-search/?district=Bogura')
        self.assertEqual(res.status_code, 200)
        upazilas = res.json()
        self.assertTrue(len(upazilas) > 0)
        names = [u['name'] for u in upazilas]
        self.assertIn('Bogura Sadar', names)
