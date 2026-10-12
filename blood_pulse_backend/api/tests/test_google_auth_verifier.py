import json
import time
from unittest.mock import patch, MagicMock
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from api.models import DonorProfile

class GoogleAuthVerifierTests(TestCase):
    def setUp(self):
        self.url = '/api/auth/google/'

    @patch('google.oauth2.id_token.verify_oauth2_token')
    def test_valid_google_token_new_user(self, mock_verify):
        mock_verify.return_value = {
            'email': 'new_google_donor@gmail.com',
            'name': 'New Google Donor',
            'sub': 'google_sub_12345',
            'picture': 'https://example.com/photo.jpg',
            'email_verified': True,
            'exp': int(time.time()) + 3600,
            'aud': 'expected-client-id.apps.googleusercontent.com'
        }

        res = self.client.post(self.url, {'id_token': 'valid_jwt'}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertIn('access', res.data)
        self.assertIn('refresh', res.data)
        self.assertEqual(res.data['user']['email'], 'new_google_donor@gmail.com')
        # Check profile completeness rule: new user without blood_group & district has incomplete profile
        self.assertFalse(res.data['user']['is_profile_complete'])

    @patch.dict('os.environ', {'GOOGLE_OAUTH_CLIENT_IDS': 'allowed-client-id-1,allowed-client-id-2'})
    @patch('google.oauth2.id_token.verify_oauth2_token')
    def test_wrong_audience_rejected(self, mock_verify):
        mock_verify.return_value = {
            'email': 'donor@gmail.com',
            'name': 'Donor',
            'sub': 'google_sub_wrong_aud',
            'picture': 'https://example.com/photo.jpg',
            'email_verified': True,
            'exp': int(time.time()) + 3600,
            'aud': 'malicious-client-id.apps.googleusercontent.com'
        }

        res = self.client.post(self.url, {'id_token': 'wrong_aud_jwt'}, format='json')
        self.assertEqual(res.status_code, 401)
        self.assertIn('audience', res.data['error'].lower())

    @patch('google.oauth2.id_token.verify_oauth2_token')
    def test_expired_token_rejected(self, mock_verify):
        mock_verify.return_value = {
            'email': 'donor@gmail.com',
            'name': 'Donor',
            'sub': 'google_sub_exp',
            'picture': 'https://example.com/photo.jpg',
            'email_verified': True,
            'exp': int(time.time()) - 100, # expired
            'aud': 'some-client-id'
        }

        res = self.client.post(self.url, {'id_token': 'expired_jwt'}, format='json')
        self.assertEqual(res.status_code, 401)
        self.assertIn('expired', res.data['error'].lower())

    @patch('google.oauth2.id_token.verify_oauth2_token')
    def test_unverified_email_rejected(self, mock_verify):
        mock_verify.return_value = {
            'email': 'unverified@gmail.com',
            'name': 'Unverified Donor',
            'sub': 'google_sub_unver',
            'picture': 'https://example.com/photo.jpg',
            'email_verified': False,
            'exp': int(time.time()) + 3600,
            'aud': 'some-client-id'
        }

        res = self.client.post(self.url, {'id_token': 'unverified_jwt'}, format='json')
        self.assertEqual(res.status_code, 401)
        self.assertIn('not verified', res.data['error'].lower())
