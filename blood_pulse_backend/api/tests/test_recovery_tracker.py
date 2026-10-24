# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from api.models import DonorProfile, DailyHydrationLog

class RecoveryTrackerTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='donor1', password='Password123!', email='donor1@example.com')
        self.client.force_authenticate(user=self.user)

    def test_never_donated(self):
        """Asserts empty state when user has never donated blood (no percentage, clear message)."""
        profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='01711111111',
            last_donation_date=None,
            is_profile_complete=True,
        )

        res = self.client.get('/api/health-hub/recovery-status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertFalse(data['has_donated'])
        self.assertIsNone(data['recovery_percentage'])
        self.assertEqual(data['status_message'], 'Your recovery tracker starts after your first donation.')

    def test_24_hours_recovery(self):
        """Asserts 24 hours recovery shows plasma volume replenishment stage."""
        yesterday = timezone.now().date() - timedelta(days=1)
        DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            district='Chittagong',
            phone_number='01722222222',
            last_donation_date=yesterday,
            is_profile_complete=True,
        )

        res = self.client.get('/api/health-hub/recovery-status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['has_donated'])
        self.assertIsNotNone(data['recovery_percentage'])
        self.assertEqual(data['elapsed_days'], 1)
        self.assertIn('Plasma Volume Replenishment', data['stage'])
        self.assertIn('24 hours', data['status_message'])

    def test_7_days_recovery(self):
        """Asserts 7 days recovery shows cellular/platelet regeneration stage."""
        seven_days_ago = timezone.now().date() - timedelta(days=7)
        DonorProfile.objects.create(
            user=self.user,
            blood_group='B+',
            district='Sylhet',
            phone_number='01733333333',
            last_donation_date=seven_days_ago,
            is_profile_complete=True,
        )

        res = self.client.get('/api/health-hub/recovery-status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['has_donated'])
        self.assertEqual(data['elapsed_days'], 7)
        self.assertIn('Erythropoiesis', data['stage'])
        self.assertGreater(data['recovery_percentage'], 50)

    def test_56_days_full_recovery(self):
        """Asserts 56 days recovery achieves 100% full biological recovery and donation readiness."""
        fifty_six_days_ago = timezone.now().date() - timedelta(days=56)
        DonorProfile.objects.create(
            user=self.user,
            blood_group='AB+',
            district='Rajshahi',
            phone_number='01744444444',
            last_donation_date=fifty_six_days_ago,
            is_profile_complete=True,
        )

        res = self.client.get('/api/health-hub/recovery-status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['has_donated'])
        self.assertEqual(data['recovery_percentage'], 100)
        self.assertEqual(data['elapsed_days'], 56)
        self.assertTrue(data['is_eligible'])
        self.assertIn('Full Recovery Completed', data['stage'])

    def test_hydration_storage_per_day(self):
        """Asserts hydration glasses can be logged, incremented, and retrieved per day on backend."""
        # 1. Fetch initial count (0)
        res = self.client.get('/api/health-hub/hydration/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()['glasses'], 0)

        # 2. Add a glass
        res_add = self.client.post('/api/health-hub/hydration/', {'action': 'add'}, format='json')
        self.assertEqual(res_add.status_code, 200)
        self.assertEqual(res_add.json()['glasses'], 1)

        # 3. Add second glass
        res_add2 = self.client.post('/api/health-hub/hydration/', {'action': 'add'}, format='json')
        self.assertEqual(res_add2.json()['glasses'], 2)

        # 4. Verify persisted in DB
        today = timezone.now().date()
        log = DailyHydrationLog.objects.get(user=self.user, date=today)
        self.assertEqual(log.glasses, 2)
