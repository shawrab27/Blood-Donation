from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.contrib.auth.models import User
from api.models import DonorProfile
from rest_framework_simplejwt.tokens import RefreshToken
import urllib.request
import json
from unittest.mock import patch, MagicMock

class CP2Tests(APITestCase):
    def setUp(self):
        self.user_incomplete = User.objects.create_user(username='inc', password='123', email='inc@t.com', first_name="Test")
        self.profile_incomplete = DonorProfile.objects.create(user=self.user_incomplete, blood_group='', phone_number='+88000000000', district="Dhaka")
        
        self.user_complete = User.objects.create_user(username='com', password='123', email='com@t.com', first_name='John')
        self.profile_complete = DonorProfile.objects.create(
            user=self.user_complete,
            blood_group='O+',
            phone_number='1234567890',
            district='Dhaka'
        )

        refresh1 = RefreshToken.for_user(self.user_incomplete)
        self.token_incomplete = str(refresh1.access_token)

        refresh2 = RefreshToken.for_user(self.user_complete)
        self.token_complete = str(refresh2.access_token)

    def test_blood_hub_access_incomplete(self):
        # Protected endpoint returns 403 with code 'profile_incomplete'
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_incomplete)
        response = self.client.get('/api/requests/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(response.data['code'], 'profile_incomplete')

    def test_blood_hub_access_complete(self):
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_complete)
        response = self.client.get('/api/requests/')
        self.assertNotEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_google_user_blood_group_missing_personal_endpoint(self):
        # (a) Google-style user with blood_group missing gets 403, code "profile_incomplete", on a personal endpoint.
        google_user = User.objects.create_user(username='guser_a', email='guser_a@gmail.com', first_name='GUserA')
        DonorProfile.objects.create(
            user=google_user,
            phone_number='+88099999991',
            district='Dhaka',
            blood_group='',
            auth_provider='google'
        )
        refresh = RefreshToken.for_user(google_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        res = self.client.post('/api/requests/', {'patient_name': 'Patient A', 'blood_group': 'A+'})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(res.data['code'], 'profile_incomplete')
        self.assertIn('blood_group', res.data['missing_fields'])

    def test_google_user_feed_read_allowed(self):
        # (b) Same user gets 200 on public feed read.
        google_user = User.objects.create_user(username='guser_b', email='guser_b@gmail.com', first_name='GUserB')
        DonorProfile.objects.create(
            user=google_user,
            phone_number='+88099999992',
            district='Dhaka',
            blood_group='',
            auth_provider='google'
        )
        refresh = RefreshToken.for_user(google_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        res = self.client.get('/api/posts/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_google_user_profile_update_sets_blood_group(self):
        # (c) Same user gets 200 on profile update that sets blood group.
        google_user = User.objects.create_user(username='guser_c', email='guser_c@gmail.com', first_name='GUserC')
        profile = DonorProfile.objects.create(
            user=google_user,
            phone_number='+88099999993',
            district='Dhaka',
            blood_group='',
            auth_provider='google'
        )
        refresh = RefreshToken.for_user(google_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        res = self.client.patch(f'/api/donors/{profile.id}/', {'blood_group': 'B+'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        profile.refresh_from_db()
        self.assertEqual(profile.blood_group, 'B+')
        self.assertTrue(profile.is_profile_complete)

    def test_placeholder_phone_counts_as_missing(self):
        # (d) Placeholder phone (+8801700000000) counts as missing.
        user = User.objects.create_user(username='ph_user_d', email='ph_d@example.com', first_name='PhoneUser')
        profile = DonorProfile.objects.create(
            user=user,
            phone_number='+8801700000000',
            district='Dhaka',
            blood_group='A+'
        )
        is_comp, missing = profile.check_is_complete()
        self.assertFalse(is_comp)
        self.assertIn('phone_number', missing)

    @patch('assistant.views.call_gemini')
    def test_pulseai_personal_question_incomplete_profile(self, mock_gemini):
        # (e) PulseAI personal question with incomplete profile returns the fixed reply, and AI mock is NOT called.
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_incomplete)
        res = self.client.post('/api/assistant/chat/', {
            'message': 'can I donate blood?',
            'language': 'en'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data.get('action'), 'complete_profile')
        self.assertEqual(res.data.get('response'), "Your profile is not complete yet. Please complete your registration to get a personal answer.")
        self.assertIn('blood_group', res.data.get('missing_fields', []))
        mock_gemini.assert_not_called()

    def test_complete_profile_user_normal_behavior(self):
        # (f) Complete profile user gets normal behavior.
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_complete)
        res = self.client.get('/api/requests/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res_me = self.client.get('/api/donors/me/')
        self.assertEqual(res_me.status_code, status.HTTP_200_OK)
        self.assertTrue(res_me.data['is_profile_complete'])
        self.assertEqual(res_me.data['missing_fields'], [])

    @patch('urllib.request.urlopen')
    def test_repeat_google_login(self, mock_urlopen):
        # mock google tokeninfo
        mock_resp = MagicMock()
        mock_resp.status = 200
        mock_resp.read.return_value = json.dumps({
            "email": "testg@gmail.com",
            "email_verified": True,
            "name": "Test G",
            "sub": "12345google",
            "picture": "http://photo.com/1.png"
        }).encode('utf-8')
        mock_urlopen.return_value.__enter__.return_value = mock_resp

        # First login
        response = self.client.post('/api/auth/google/', {'id_token': 'fake'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(User.objects.filter(email='testg@gmail.com').count(), 1)
        self.assertEqual(DonorProfile.objects.filter(google_uid='12345google').count(), 1)

        # Second login
        response = self.client.post('/api/auth/google/', {'id_token': 'fake'})
        self.assertEqual(response.status_code, 200)
        # Verify no duplicate user
        self.assertEqual(User.objects.filter(email='testg@gmail.com').count(), 1)
        self.assertEqual(DonorProfile.objects.filter(google_uid='12345google').count(), 1)

