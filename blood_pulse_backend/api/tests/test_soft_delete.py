# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from api.models import DonorProfile, BloodRequest, DonationHistory
from rest_framework.test import APIClient
from django.utils import timezone

class UserDeletionRetentionTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='deluser', email='test@test.com', password='pw', first_name='John', last_name='Doe')
        self.profile = DonorProfile.objects.create(user=self.user, blood_group='A+', phone_number='123123123')
        
        self.req = BloodRequest.objects.create(
            requester=self.user,
            patient_name='Patient A',
            blood_group='A+',
            units_needed=1,
            status='ACTIVE'
        )
        
        for i in range(5):
            DonationHistory.objects.create(
                donor=self.profile,
                date=timezone.now().date(),
                location='Hospital X'
            )
            
    def test_soft_delete(self):
        client = APIClient()
        client.force_authenticate(user=self.user)
        
        response = client.delete('/api/donors/me/')
        self.assertEqual(response.status_code, 204)
        
        # Reload from db
        self.profile.refresh_from_db()
        self.user.refresh_from_db()
        
        self.assertFalse(self.user.is_active)
        self.assertFalse(self.profile.is_available)
        self.assertEqual(self.user.first_name, 'Deleted')
        self.assertIn('deleted_', self.user.email)
        self.assertIn('deleted_', self.profile.phone_number)
        
        # Check relations still exist
        self.assertEqual(DonationHistory.objects.filter(donor=self.profile).count(), 5)
        self.assertEqual(BloodRequest.objects.filter(requester=self.user).count(), 1)
