from unittest.mock import patch
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from api.models import DonorProfile, Division, District, Upazila


class H01RegistrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.payload = {
            'blood_group': 'A+',
            'district': 'Dhaka',
            'phone_number': '01712345678',
            'full_name': 'Test Donor User',
            'email': 'testdonor_h01@example.com',
            'age': 25,
            'gender': 'male',
            'category': 'student',
            'user_intent': 'DONATE_AND_REQUEST',
            'password': 'StrongPassword123!',
            'is_verified': True,
        }

    def test_reproduction_mirrors_flutter_registration_with_password(self):
        """
        Mirror exact Flutter registration payload with 'password'.
        Before fix: raises TypeError: DonorProfile() got unexpected keyword arguments: 'password' (500).
        After fix: returns 201, User + DonorProfile created, password hashed.
        """
        response = self.client.post('/api/donors/', data=self.payload, format='json')
        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            f"Expected 201 CREATED but got {response.status_code}: {response.data}"
        )
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertNotIn('password', response.data)

        # Verify User created and password correctly hashed
        user = User.objects.filter(email='testdonor_h01@example.com').first()
        self.assertIsNotNone(user)
        self.assertTrue(user.check_password('StrongPassword123!'))

        # Verify DonorProfile created and linked
        profile = DonorProfile.objects.filter(user=user).first()
        self.assertIsNotNone(profile)
        self.assertEqual(profile.blood_group, 'A+')
        self.assertEqual(profile.district, 'Dhaka')

        # Verify login succeeds with the registered credentials
        login_resp = self.client.post('/api/token/', data={
            'username': user.username,
            'password': 'StrongPassword123!',
        }, format='json')
        self.assertEqual(login_resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', login_resp.data)

    def test_password_never_in_response(self):
        """Ensure password is never returned in registration or profile responses."""
        response = self.client.post('/api/donors/', data=self.payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertNotIn('password', response.data)

        # Authenticate and inspect me endpoint
        access_token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        profile_resp = self.client.get('/api/profile/me/')
        self.assertEqual(profile_resp.status_code, status.HTTP_200_OK)
        self.assertNotIn('password', profile_resp.data)

    def test_registration_atomic_rollback_on_failure(self):
        """
        Ensure atomic transaction: if profile creation fails,
        no orphan User is left in the database.
        """
        initial_user_count = User.objects.count()
        initial_profile_count = DonorProfile.objects.count()

        bad_payload = dict(self.payload)
        bad_payload['phone_number'] = '01799887766'
        bad_payload['email'] = 'orphan_check@example.com'

        # Force a failure during profile save
        with patch.object(DonorProfile, 'save', side_effect=RuntimeError('Forced DB failure')):
            try:
                response = self.client.post('/api/donors/', data=bad_payload, format='json')
            except RuntimeError:
                pass

        # Zero orphan user or profile created
        self.assertEqual(User.objects.count(), initial_user_count)
        self.assertEqual(DonorProfile.objects.count(), initial_profile_count)
        self.assertFalse(User.objects.filter(email='orphan_check@example.com').exists())

    def test_duplicate_phone_returns_400(self):
        """Registering with an already existing phone number returns 400 Bad Request."""
        res1 = self.client.post('/api/donors/', data=self.payload, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        dup_payload = dict(self.payload)
        dup_payload['email'] = 'different_email@example.com'
        res2 = self.client.post('/api/donors/', data=dup_payload, format='json')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('phone_number', res2.data)

    def test_duplicate_email_returns_400(self):
        """Registering with an already existing email returns 400 Bad Request and creates no orphan user."""
        res1 = self.client.post('/api/donors/', data=self.payload, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        dup_payload = dict(self.payload)
        dup_payload['phone_number'] = '01711223344'
        users_before = User.objects.count()
        res2 = self.client.post('/api/donors/', data=dup_payload, format='json')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', res2.data)
        # Verify no orphan user created for 01711223344
        self.assertEqual(User.objects.count(), users_before)

    def test_upazila_search_returns_results_for_sadar_and_prefixes(self):
        """Verify upazila search returns expected results for 'sadar' and prefix queries."""
        div, _ = Division.objects.get_or_create(name='Dhaka')
        dist, _ = District.objects.get_or_create(name='Faridpur', division=div)
        up1, _ = Upazila.objects.get_or_create(name='Faridpur Sadar', district=dist)
        up2, _ = Upazila.objects.get_or_create(name='Sadarpur', district=dist)
        up3, _ = Upazila.objects.get_or_create(name='Laksam', district=dist)

        # Test sadar
        res = self.client.get('/api/locations/upazila-search/?q=sadar')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        names = [item['name'] for item in res.data]
        self.assertIn('Faridpur Sadar', names)
        self.assertIn('Sadarpur', names)

        # Test prefixes
        for prefix in ['la', 'lak', 'laks', 'sa', 'sada', 'sadar']:
            r = self.client.get(f'/api/locations/upazila-search/?q={prefix}')
            self.assertEqual(r.status_code, status.HTTP_200_OK)
            self.assertGreater(len(r.data), 0, f"Expected results for prefix '{prefix}'")
