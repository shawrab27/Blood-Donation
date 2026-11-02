import os
from django.conf import settings
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
            content = f.read()
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
