# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient

class CommunitiesIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_clubs_empty_query(self):
        res = self.client.get('/api/local-clubs/')
        self.assertEqual(res.status_code, 200)

    def test_clubs_no_match(self):
        res = self.client.get('/api/local-clubs/', {'search': 'NonExistentClub123'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()), 0)

    def test_hospitals_empty_query(self):
        res = self.client.get('/api/medical-partners/')
        self.assertIn(res.status_code, [200, 400])

    def test_hospitals_no_match(self):
        res = self.client.get('/api/medical-partners/', {'search': 'NonExistentHospital123'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()), 0)
