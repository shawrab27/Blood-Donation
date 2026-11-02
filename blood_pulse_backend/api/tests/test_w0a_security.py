import os
from unittest.mock import patch, MagicMock
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from rest_framework.test import APIClient, APIRequestFactory
from rest_framework.renderers import JSONRenderer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from api.models import DonorProfile, DonorReview, BloodRequest, Hospital

class W0aSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.factory = APIRequestFactory()

    def test_item1_json_renderer_only_when_debug_false(self):
        """In production (DEBUG=False), browsable API is disabled and HTML accepts get JSON."""
        with open('blood_pulse_backend/blood_pulse_backend/settings.py', 'r', encoding='utf-8') as f:
            content = f.read().replace('\r\n', '\n')
        self.assertIn("if not DEBUG:\n    REST_FRAMEWORK['DEFAULT_RENDERER_CLASSES'] = (\n        'rest_framework.renderers.JSONRenderer',\n    )", content)

        class DummyProdView(APIView):
            renderer_classes = [JSONRenderer]
            def get(self, request):
                return Response({'status': 'ok'})

        view = DummyProdView.as_view()
        request = self.factory.get('/dummy/', HTTP_ACCEPT='text/html')
        resp = view(request)
        resp.render()
        self.assertEqual(resp.status_code, status.HTTP_406_NOT_ACCEPTABLE)
        self.assertIn('application/json', resp['Content-Type'])
        self.assertNotIn('text/html', resp['Content-Type'])

    @patch('api.views_auth_reset.email_service.get_email_service')
    def test_item2_password_reset_anti_enumeration(self, mock_get_email_svc):
        """Google-only accounts and non-existent accounts receive identical generic success responses."""
        mock_svc = MagicMock()
        mock_svc.send_email.return_value = {'success': True}
        mock_get_email_svc.return_value = mock_svc

        resp_unknown = self.client.post('/api/auth/password-reset/request/', {'email': 'unknown@example.com'})
        self.assertEqual(resp_unknown.status_code, status.HTTP_200_OK)
        expected_detail = 'If this email is registered, a code has been sent.'
        self.assertEqual(resp_unknown.json().get('detail'), expected_detail)

        google_user = User.objects.create(username='googleuser', email='googleuser@example.com')
        google_user.set_unusable_password()
        google_user.save()

        resp_google = self.client.post('/api/auth/password-reset/request/', {'email': 'googleuser@example.com'})
        self.assertEqual(resp_google.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_google.json().get('detail'), expected_detail)
        mock_svc.send_email.assert_called()
        self.assertEqual(mock_svc.send_email.call_args[1]['to_email'], 'googleuser@example.com')

    def test_item3_legacy_vercel_cors_removed(self):
        """Legacy Vercel domain must not be in CORS_ALLOWED_ORIGINS or CSRF_TRUSTED_ORIGINS."""
        from django.conf import settings
        self.assertNotIn('https://blood-donation-liard.vercel.app', settings.CORS_ALLOWED_ORIGINS)
        self.assertNotIn('https://blood-donation-liard.vercel.app', settings.CSRF_TRUSTED_ORIGINS)

    def test_item4_donor_profile_destroy_pii_scrub(self):
        """DonorProfile destroy must fully scrub PII (bio, address, coordinates, fcm token, google fields)."""
        user = User.objects.create_user(
            username='donor_del',
            email='donor_del@example.com',
            password='Password123!',
            first_name='Donor',
            last_name='ToDelete'
        )
        profile = DonorProfile.objects.create(
            user=user,
            blood_group='B+',
            district='Dhaka',
            phone_number='01811223344',
            bio='My sensitive bio',
            address='123 Private St, Dhanmondi',
            latitude=23.75,
            longitude=90.38,
            public_lat=23.751,
            public_lng=90.381,
            fcm_token='secret_fcm_token_123',
            google_uid='google_uid_123',
            is_available=True,
            is_searchable=True,
        )

        self.client.force_authenticate(user=user)
        resp = self.client.delete(f'/api/donors/{profile.id}/')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)

        profile.refresh_from_db()
        user.refresh_from_db()

        self.assertEqual(profile.bio, '')
        self.assertEqual(profile.address, '')
        self.assertIsNone(profile.latitude)
        self.assertIsNone(profile.longitude)
        self.assertIsNone(profile.public_lat)
        self.assertIsNone(profile.public_lng)
        self.assertIsNone(profile.fcm_token)
        self.assertIsNone(profile.google_uid)
        self.assertFalse(profile.is_available)
        self.assertFalse(profile.is_searchable)
        self.assertFalse(user.is_active)

    def test_item5_media_file_serve_disabled_when_debug_false_or_cloudinary(self):
        """MediaFileServeView returns 404 when DEBUG=False or Cloudinary configured, without wildcard origin."""
        with override_settings(DEBUG=False):
            resp = self.client.get('/api/media/files/test.jpg/')
            self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)
            self.assertNotEqual(resp.headers.get('Access-Control-Allow-Origin'), '*')

        with patch.dict(os.environ, {'CLOUDINARY_URL': 'cloudinary://key:secret@cloud'}):
            resp = self.client.get('/api/media/files/test.jpg/')
            self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)
            self.assertNotEqual(resp.headers.get('Access-Control-Allow-Origin'), '*')

    def test_item7_location_validation_and_review_privacy(self):
        """Location endpoint validates lat/lng bounds and reviews endpoint masks reviewer names."""
        # 1. Invalid lat
        resp_invalid_lat = self.client.post('/api/users/location/', {'lat': 95.0, 'lng': 90.0}, format='json')
        self.assertEqual(resp_invalid_lat.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Incomplete lat/lng
        resp_lat_only = self.client.post('/api/users/location/', {'lat': 23.8}, format='json')
        self.assertEqual(resp_lat_only.status_code, status.HTTP_400_BAD_REQUEST)

        # 3. Reviewer name masking for public viewers
        donor_u = User.objects.create_user(username='rev_donor', email='rev_donor@example.com', password='Password123!')
        donor_p = DonorProfile.objects.create(user=donor_u, blood_group='O+', district='Dhaka', phone_number='01911111111')
        reviewer_u = User.objects.create_user(
            username='reviewer_1',
            email='reviewer@example.com',
            password='Password123!',
            first_name='Rahim',
            last_name='Chowdhury'
        )
        hosp = Hospital.objects.create(name='Dhaka Medical College', district='Dhaka')
        br = BloodRequest.objects.create(
            requester=reviewer_u,
            blood_group='O+',
            hospital=hosp,
            status='DONATED',
            patient_name='Patient X'
        )
        DonorReview.objects.create(
            reviewer=reviewer_u,
            donor=donor_p,
            blood_request=br,
            stars=5,
            comment='Great donor'
        )

        resp_rev = self.client.get(f'/api/profile/{donor_p.id}/reviews/')
        self.assertEqual(resp_rev.status_code, status.HTTP_200_OK)
        results = resp_rev.json().get('results', [])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['reviewer_name'], 'Rahim C.')
