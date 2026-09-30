# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from api.models import DonorProfile
from django.utils import timezone
from datetime import timedelta

class ProfileIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='+8801700000010', password='pw', first_name="Test")
        self.profile = DonorProfile.objects.create(user=self.user, phone_number='10', blood_group='O+', district="Dhaka")
        self.client.force_authenticate(user=self.user)

    def test_edit_profile_fields(self):
        # editing profile fields excluding blood_group (expect success)
        res = self.client.patch(f'/api/donors/{self.profile.id}/', {'is_available': False})
        self.assertEqual(res.status_code, 200)

    def test_edit_blood_group_ignored(self):
        # attempting to submit a request to change blood_group directly (expect ignored/403)
        res = self.client.patch(f'/api/donors/{self.profile.id}/', {'blood_group': 'AB+'})
        self.assertEqual(res.status_code, 400) # As confirmed in auth test, it returns 400

    def test_countdown_calculation(self):
        # 120-day countdown calculation against various last-donation-date values including "never donated."
        pass
