# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.core.management import call_command
from rest_framework.test import APIClient
from io import StringIO

from api.models import DonorProfile
from api.phone_utils import normalize_phone_number, mask_phone, get_phone_variants

User = get_user_model()


class PhoneAuthenticationTests(TestCase):
    """
    Validates canonical phone normalization and login with:
      - All 4 input formats (+8801..., 8801..., 01..., 1...)
      - Email login
      - Wrong password -> generic 401 'Invalid credentials'
      - Unknown phone -> generic 401 'Invalid credentials'
      - Inactive user -> generic 401 'Invalid credentials'
      - Read-only diagnose_phone_accounts command
      - Backfill command dry-run safety
    """

    def setUp(self):
        self.client = APIClient()
        self.password = "StrongPass123!"
        self.canonical_phone = "+8801712345678"
        self.email = "donor.test@example.com"

        # Create active user with canonical phone on DonorProfile
        self.user = User.objects.create_user(
            username=self.canonical_phone,
            email=self.email,
            password=self.password,
            first_name="Rahim",
            last_name="Uddin",
            is_active=True,
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            blood_group="A+",
            district="Dhaka",
            phone_number=self.canonical_phone,
            is_profile_complete=True,
        )

        # Inactive user
        self.inactive_phone = "+8801812345678"
        self.inactive_user = User.objects.create_user(
            username=self.inactive_phone,
            email="inactive@example.com",
            password=self.password,
            is_active=False,
        )
        self.inactive_profile = DonorProfile.objects.create(
            user=self.inactive_user,
            blood_group="B+",
            district="Chittagong",
            phone_number=self.inactive_phone,
            is_profile_complete=True,
        )

    def test_login_with_canonical_format(self):
        resp = self.client.post('/api/token/', {
            'username': '+8801712345678',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('access', resp.data)
        self.assertIn('refresh', resp.data)
        self.assertTrue(resp.data.get('is_profile_complete'))

    def test_login_with_local_01_format(self):
        resp = self.client.post('/api/token/', {
            'username': '01712345678',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('access', resp.data)

    def test_login_with_international_880_format(self):
        resp = self.client.post('/api/token/', {
            'username': '8801712345678',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('access', resp.data)

    def test_login_with_core_10_digits(self):
        resp = self.client.post('/api/token/', {
            'username': '1712345678',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('access', resp.data)

    def test_login_with_email(self):
        resp = self.client.post('/api/token/', {
            'username': self.email,
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 200)
        self.assertIn('access', resp.data)

    def test_wrong_password_gives_generic_401(self):
        resp = self.client.post('/api/token/', {
            'username': '01712345678',
            'password': 'WrongPassword999',
        }, format='json')
        self.assertEqual(resp.status_code, 401)
        self.assertEqual(resp.data.get('detail'), 'Invalid credentials')

    def test_unknown_phone_gives_generic_401_no_enumeration(self):
        resp = self.client.post('/api/token/', {
            'username': '01799999999',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 401)
        self.assertEqual(resp.data.get('detail'), 'Invalid credentials')

    def test_inactive_user_gives_generic_401(self):
        resp = self.client.post('/api/token/', {
            'username': '01812345678',
            'password': self.password,
        }, format='json')
        self.assertEqual(resp.status_code, 401)
        self.assertEqual(resp.data.get('detail'), 'Invalid credentials')

    def test_diagnose_phone_accounts_masks_pii(self):
        out = StringIO()
        call_command('diagnose_phone_accounts', '01712345678', stdout=out)
        output = out.getvalue()

        # Must contain masked suffix
        self.assertIn('***...678', output)
        self.assertIn('Account ID:', output)
        # Must NEVER contain the full unmasked phone or email
        self.assertNotIn('01712345678', output)
        self.assertNotIn(self.email, output)

    def test_backfill_command_dry_run_safety(self):
        # Create a profile with local 01 format
        raw_phone = "01987654321"
        test_user = User.objects.create_user(
            username=raw_phone,
            password="testpassword",
        )
        test_profile = DonorProfile.objects.create(
            user=test_user,
            blood_group="O+",
            district="Sylhet",
            phone_number=raw_phone,
        )

        out = StringIO()
        call_command('backfill_canonical_phones', stdout=out)

        # In dry run, database must remain unchanged
        test_profile.refresh_from_db()
        self.assertEqual(test_profile.phone_number, raw_phone)
