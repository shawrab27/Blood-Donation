# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from unittest.mock import patch, MagicMock
import time

class RateLimitTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='rateuser', password='pw')
        self.client.force_authenticate(user=self.user)

    def test_emergency_broadcast_throttle(self):
        # Limit is 3/min
        for i in range(3):
            res = self.client.post('/api/emergency/requests/', {})
            
        res = self.client.post('/api/emergency/requests/', {})
        self.assertEqual(res.status_code, 429)

    @patch('google.genai.Client')
    def test_chat_throttle(self, MockClient):
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = '{"reply": "Hello!"}'
        mock_instance.models.generate_content.return_value = mock_response

        # Limit is 10/min
        for i in range(10):
            res = self.client.post('/api/assistant/chat/', {'message': 'hi'})
            
        res = self.client.post('/api/assistant/chat/', {'message': 'hi'})
        self.assertEqual(res.status_code, 429)
