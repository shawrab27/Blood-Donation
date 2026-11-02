import os
from unittest.mock import patch, MagicMock
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient, APIRequestFactory
from rest_framework.renderers import JSONRenderer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

class W0aSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.factory = APIRequestFactory()

    def test_item1_json_renderer_only_when_debug_false(self):
        """In production (DEBUG=False), browsable API is disabled and HTML accepts get JSON."""
        # 1. Verify the settings definition file directly contains the production condition
        with open('blood_pulse_backend/blood_pulse_backend/settings.py', 'r', encoding='utf-8') as f:
            content = f.read().replace('\r\n', '\n')
        self.assertIn("if not DEBUG:\n    REST_FRAMEWORK['DEFAULT_RENDERER_CLASSES'] = (\n        'rest_framework.renderers.JSONRenderer',\n    )", content)

        # 2. Test an API view configured with JSONRenderer only (as production sets it)
        class DummyProdView(APIView):
            renderer_classes = [JSONRenderer]
            def get(self, request):
                return Response({'status': 'ok'})

        view = DummyProdView.as_view()
        request = self.factory.get('/dummy/', HTTP_ACCEPT='text/html')
        resp = view(request)
        resp.render()
        # When browsable API is disabled, requesting text/html receives application/json 406, never text/html
        self.assertEqual(resp.status_code, status.HTTP_406_NOT_ACCEPTABLE)
        self.assertIn('application/json', resp['Content-Type'])
        self.assertNotIn('text/html', resp['Content-Type'])

    @patch('api.views_auth_reset.email_service.get_email_service')
    def test_item2_password_reset_anti_enumeration(self, mock_get_email_svc):
        """Google-only accounts and non-existent accounts receive identical generic success responses."""
        mock_svc = MagicMock()
        mock_svc.send_email.return_value = {'success': True}
        mock_get_email_svc.return_value = mock_svc

        # 1. Unknown user receives generic 200
        resp_unknown = self.client.post('/api/auth/password-reset/request/', {'email': 'unknown@example.com'})
        self.assertEqual(resp_unknown.status_code, status.HTTP_200_OK)
        expected_detail = 'If this email is registered, a code has been sent.'
        self.assertEqual(resp_unknown.json().get('detail'), expected_detail)

        # 2. Google OAuth user with unusable password
        google_user = User.objects.create(username='googleuser', email='googleuser@example.com')
        google_user.set_unusable_password()
        google_user.save()

        resp_google = self.client.post('/api/auth/password-reset/request/', {'email': 'googleuser@example.com'})
        # Must NOT return 400 Bad Request
        self.assertEqual(resp_google.status_code, status.HTTP_200_OK)
        # Detail must be identical to unknown user
        self.assertEqual(resp_google.json().get('detail'), expected_detail)
        # Should have sent hint email
        mock_svc.send_email.assert_called()
        self.assertEqual(mock_svc.send_email.call_args[1]['to_email'], 'googleuser@example.com')

    def test_item3_legacy_vercel_cors_removed(self):
        """Legacy Vercel domain must not be in CORS_ALLOWED_ORIGINS or CSRF_TRUSTED_ORIGINS."""
        from django.conf import settings
        self.assertNotIn('https://blood-donation-liard.vercel.app', settings.CORS_ALLOWED_ORIGINS)
        self.assertNotIn('https://blood-donation-liard.vercel.app', settings.CSRF_TRUSTED_ORIGINS)
