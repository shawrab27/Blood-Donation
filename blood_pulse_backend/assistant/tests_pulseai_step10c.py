# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from unittest.mock import patch
from django.test import TestCase
from rest_framework.test import APIClient
from api.conf import DONOR_COOLDOWN_DAYS

class PulseAIStep10CTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_anonymous_user_can_access_pulseai(self):
        """Anonymous guest users must be allowed without 401/403."""
        res = self.client.post('/api/assistant/chat/', {'message': 'What are the donor eligibility criteria?'}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertIn('reply', res.data)
        self.assertIn('request_id', res.data)
        self.assertTrue(res.data['request_id'].startswith('req_'))
        self.assertIn(res.data.get('source'), ['ai', 'fallback'])

    @patch('assistant.views.call_gemini', side_effect=Exception('Provider down or 503 unavailable'))
    def test_fallback_eligibility_criteria_when_provider_down(self, mock_gemini):
        """Fallback for eligibility includes age 18-60 and weight >= 50kg."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'Who is eligible to donate blood?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        reply = res.data.get('reply', '')
        self.assertIn('18', reply)
        self.assertIn('50', reply)
        self.assertEqual(res.data.get('source'), 'fallback')
        self.assertIn('Offline guidance', reply)

    @patch('assistant.views.call_gemini', side_effect=Exception('Provider timeout 504'))
    def test_fallback_donation_interval_strictly_90_days_when_provider_down(self, mock_gemini):
        """Donation cooldown must strictly reflect DONOR_COOLDOWN_DAYS (90 days)."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'How long do I have to wait between blood donations?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        reply = res.data.get('reply', '')
        self.assertIn(str(DONOR_COOLDOWN_DAYS), reply)
        self.assertEqual(res.data.get('source'), 'fallback')

    @patch('assistant.views.call_gemini', side_effect=Exception('Rate limited 429'))
    def test_fallback_nutrition_and_food_before_donation_when_provider_down(self, mock_gemini):
        """Guidance on what to eat before donation."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'What should I eat before donating blood?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        reply = res.data.get('reply', '').lower()
        self.assertTrue('meal' in reply or 'food' in reply or 'light' in reply or 'fatty' in reply)
        self.assertEqual(res.data.get('source'), 'fallback')

    @patch('assistant.views.call_gemini', side_effect=Exception('Quota exceeded'))
    def test_fallback_hydration_when_provider_down(self, mock_gemini):
        """Guidance on hydration and drinking fluids."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'How much water should I drink before donation?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        reply = res.data.get('reply', '').lower()
        self.assertTrue('water' in reply or 'fluid' in reply or '500' in reply)
        self.assertEqual(res.data.get('source'), 'fallback')

    @patch('assistant.views.call_gemini', side_effect=Exception('Provider unreachable'))
    def test_fallback_aftercare_recovery_when_provider_down(self, mock_gemini):
        """Guidance on aftercare and rest."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'What is the aftercare advice after donating blood?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        reply = res.data.get('reply', '').lower()
        self.assertTrue('rest' in reply or '24 hours' in reply or 'bandage' in reply)
        self.assertEqual(res.data.get('source'), 'fallback')

    def test_urgent_symptoms_safety_guard(self):
        """Urgent symptoms trigger safety warning and 999 referral."""
        res = self.client.post(
            '/api/assistant/chat/',
            {'message': 'I have chest pain and shortness of breath', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data.get('emergency'))
        reply = res.data.get('reply', '')
        self.assertIn('999', reply)
