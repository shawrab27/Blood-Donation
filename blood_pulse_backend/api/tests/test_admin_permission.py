# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from api.models import DonorProfile

class AdminEndpointPermissionTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='normaluser', password='pw', is_staff=False, first_name="Test")
        self.profile = DonorProfile.objects.create(user=self.user, district="Dhaka", phone_number="01700000000", blood_group="O+")
        self.client.force_authenticate(user=self.user)

    def test_admin_broadcast_permission(self):
        response = self.client.get('/api/admin-actions/')
        self.assertEqual(response.status_code, 403)
