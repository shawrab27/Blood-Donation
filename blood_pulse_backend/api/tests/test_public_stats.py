# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth import get_user_model
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile
from api.conf import PUBLIC_STATS_MIN_DONORS

User = get_user_model()


class PublicStatsAPITests(TestCase):
    def setUp(self):
        # Excluded 8: +880 demo phone number prefix and case-insensitive demo email
        u11 = User.objects.create_user(username='tester11@test.com', email='DemoTester@test.com')
        DonorProfile.objects.create(
            user=u11,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Comilla',
            phone_number='+880170000099',
        )

        cache.clear()
        self.client = APIClient()

    def test_public_stats_allow_any_and_schema(self):
        """Anonymous client can fetch stats; response contains ONLY registered_donors and districts_covered."""
        response = self.client.get('/api/public/stats/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(set(response.data.keys()), {'registered_donors', 'districts_covered'})
        self.assertNotIn('donations_completed', response.data)
        self.assertNotIn('phone', response.data)
        self.assertNotIn('name', response.data)

    def test_public_stats_filters_accurately(self):
        """Only complete profiles with DONATE_AND_REQUEST, non-staff, non-demo are counted."""
        # Valid donor 1 (Dhaka)
        u1 = User.objects.create_user(username='donor1@test.com', email='donor1@test.com', first_name='Donor', last_name='One')
        DonorProfile.objects.create(
            user=u1,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Dhaka',
            phone_number='01811111111',
        )

        # Valid donor 2 (Chittagong)
        u2 = User.objects.create_user(username='donor2@test.com', email='donor2@test.com', first_name='Donor', last_name='Two')
        DonorProfile.objects.create(
            user=u2,
            user_intent='DONATE_AND_REQUEST',
            blood_group='A+',
            district='Chattogram',
            phone_number='01822222222',
        )

        # Valid donor 3 (Dhaka - duplicate district)
        u3 = User.objects.create_user(username='donor3@test.com', email='donor3@test.com', first_name='Donor', last_name='Three')
        DonorProfile.objects.create(
            user=u3,
            user_intent='DONATE_AND_REQUEST',
            blood_group='B+',
            district='Dhaka',
            phone_number='01833333333',
        )

        # Excluded 1: ONLY_REQUEST intent
        u4 = User.objects.create_user(username='requester@test.com', email='requester@test.com')
        DonorProfile.objects.create(
            user=u4,
            user_intent='ONLY_REQUEST',
            district='Sylhet',
            phone_number='01844444444',
        )

        # Excluded 2: Incomplete profile (missing district)
        u5 = User.objects.create_user(username='incomplete@test.com', email='incomplete@test.com')
        DonorProfile.objects.create(
            user=u5,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='',
            phone_number='01855555555',
        )

        # Excluded 3: Staff member
        u6 = User.objects.create_user(username='staff@test.com', email='staff@test.com', is_staff=True)
        DonorProfile.objects.create(
            user=u6,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Khulna',
            phone_number='01866666666',
        )

        # Excluded 4: Superuser
        u7 = User.objects.create_user(username='admin@test.com', email='admin@test.com', is_superuser=True)
        DonorProfile.objects.create(
            user=u7,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Barishal',
            phone_number='01877777777',
        )

        # Excluded 5: Demo user (username starts with demo_)
        u8 = User.objects.create_user(username='demo_donor@test.com', email='demo_donor@test.com')
        DonorProfile.objects.create(
            user=u8,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Rangpur',
            phone_number='01888888888',
        )

        # Excluded 6: Demo user (email ends with @bloodpulse.com)
        u9 = User.objects.create_user(username='demo9@test.com', email='zahir.raihan@bloodpulse.com')
        DonorProfile.objects.create(
            user=u9,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Mymensingh',
            phone_number='01899999999',
        )

        # Excluded 7: Demo phone number prefix
        u10 = User.objects.create_user(username='demo10@test.com', email='demo10@test.com')
        DonorProfile.objects.create(
            user=u10,
            user_intent='DONATE_AND_REQUEST',
            blood_group='O+',
            district='Gazipur',
            phone_number='01700000001',
        )

        cache.clear()
        response = self.client.get('/api/public/stats/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Exactly 3 valid donors (u1, u2, u3) across 2 distinct districts (Dhaka, Chattogram)
        self.assertEqual(response.data['registered_donors'], 3)
        self.assertEqual(response.data['districts_covered'], 2)

    def test_public_stats_min_donors_constant(self):
        """Assert PUBLIC_STATS_MIN_DONORS is 10."""
        self.assertEqual(PUBLIC_STATS_MIN_DONORS, 10)
