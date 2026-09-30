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
        self.user_incomplete = User.objects.create_user(username='inc', password='123', email='inc@t.com')
        self.profile_incomplete = DonorProfile.objects.create(user=self.user_incomplete, blood_group='', phone_number='+88000000000')
        
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
        # We need an endpoint protected by IsRegistrationComplete. Let's use /api/requests/
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_incomplete)
        response = self.client.get('/api/requests/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(response.data['code'], 'REGISTRATION_INCOMPLETE')

    def test_blood_hub_access_complete(self):
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + self.token_complete)
        response = self.client.get('/api/requests/')
        # Should be 200 OK (or 404/others, but not 403 REGISTRATION_INCOMPLETE)
        self.assertNotEqual(response.status_code, status.HTTP_403_FORBIDDEN)

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

