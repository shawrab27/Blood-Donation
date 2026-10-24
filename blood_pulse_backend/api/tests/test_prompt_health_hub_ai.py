# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from unittest.mock import patch, MagicMock
import json

class AIReportAnalyzerTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_missing_report_text(self):
        """Asserts 400 when report_text is missing or empty."""
        res = self.client.post('/api/health-hub/analyze-report/', {}, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn('report_text is required', res.json().get('error', ''))

        res_empty = self.client.post('/api/health-hub/analyze-report/', {'report_text': '   '}, format='json')
        self.assertEqual(res_empty.status_code, 400)

    @patch('google.genai.Client')
    def test_valid_report_analysis_mocked(self, MockClient):
        """Asserts valid CBC report returns 200, parsed parameters, and ELIGIBLE readiness."""
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "is_blood_report": True,
            "confidence": 0.95,
            "parameters": [
                {"name": "Hemoglobin", "value": "13.5", "unit": "g/dL"},
                {"name": "Platelets", "value": "220,000", "unit": "/mcL"}
            ]
        })
        mock_instance.models.generate_content.return_value = mock_response

        res = self.client.post(
            '/api/health-hub/analyze-report/',
            {'report_text': 'Hemoglobin 13.5 g/dL Platelets 220,000'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get('is_blood_report'))
        self.assertEqual(len(data.get('results', [])), 2)
        self.assertIn('ELIGIBLE', data.get('donor_readiness', ''))
        self.assertIn('Medical Disclaimer', data.get('disclaimer', ''))

    @patch('google.genai.Client')
    def test_non_report_rejected_mocked(self, MockClient):
        """Asserts non-report is rejected with 400 and clear message."""
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "is_blood_report": False,
            "confidence": 0.1,
            "parameters": []
        })
        mock_instance.models.generate_content.return_value = mock_response

        res = self.client.post(
            '/api/health-hub/analyze-report/',
            {'report_text': 'Donor list: Rahim, Karim, O positive'},
            format='json'
        )
        self.assertEqual(res.status_code, 400)
        data = res.json()
        self.assertEqual(data.get('error'), 'This does not look like a blood report. Please upload a clear photo of your CBC report.')
        self.assertEqual(data.get('results'), [])

    @patch('google.genai.Client')
    def test_partial_report_no_guessed_values(self, MockClient):
        """Asserts partial report does not fabricate or guess missing parameters."""
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "is_blood_report": True,
            "confidence": 0.9,
            "parameters": [
                {"name": "WBC", "value": "7,200", "unit": "/mcL"}
            ]
        })
        mock_instance.models.generate_content.return_value = mock_response

        res = self.client.post(
            '/api/health-hub/analyze-report/',
            {'report_text': 'WBC count: 7,200 /mcL'},
            format='json'
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(len(data.get('results', [])), 1)
        self.assertEqual(data['results'][0]['test_name'], 'WBC')
        names = [r['test_name'] for r in data['results']]
        self.assertNotIn('Hemoglobin', names)
        self.assertIn('UNABLE TO EVALUATE', data.get('donor_readiness', ''))

    @patch('google.genai.Client')
    def test_redact_py_runs_on_report_text_before_gemini(self, MockClient):
        """Asserts server runs redact_text on report_text and sends redacted text to Gemini."""
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "is_blood_report": True,
            "confidence": 0.9,
            "parameters": [{"name": "Hemoglobin", "value": "13.5", "unit": "g/dL"}]
        })
        mock_instance.models.generate_content.return_value = mock_response

        raw_report = (
            "Patient: Rahim Uddin\n"
            "Contact: 01712345678\n"
            "NID: 19901234567890123\n"
            "Hemoglobin: 13.5 g/dL (12-16)\n"
            "Platelets: 250,000 /uL (150,000-450,000)"
        )

        res = self.client.post(
            '/api/health-hub/analyze-report/',
            {'report_text': raw_report},
            format='json'
        )

        self.assertEqual(res.status_code, 200)
        self.assertTrue(mock_instance.models.generate_content.called)
        call_args = mock_instance.models.generate_content.call_args
        contents = call_args.kwargs.get('contents', [])
        if not contents and call_args.args:
            contents = call_args.args[0]

        gemini_text_payload = " ".join([c for c in contents if isinstance(c, str)])
        self.assertNotIn("01712345678", gemini_text_payload, "Raw phone number leaked to Gemini!")
        self.assertNotIn("19901234567890123", gemini_text_payload, "Raw NID leaked to Gemini!")
        self.assertIn("[REDACTED_PHONE]", gemini_text_payload)
        self.assertIn("[REDACTED_ID]", gemini_text_payload)
