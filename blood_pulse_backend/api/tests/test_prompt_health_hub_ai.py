# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from unittest.mock import patch, MagicMock
from django.core.files.uploadedfile import SimpleUploadedFile
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

    def test_reject_raw_image_upload(self):
        """Asserts 400 when client attempts to upload raw image file instead of on-device OCR text."""
        img_file = SimpleUploadedFile("report.jpg", b"fake image bytes", content_type="image/jpeg")
        res = self.client.post('/api/health-hub/analyze-report/', {'report': img_file}, format='multipart')
        self.assertEqual(res.status_code, 400)
        self.assertIn('Raw image uploads are not supported', res.json().get('error', ''))

    @patch('google.genai.Client')
    def test_redact_py_runs_on_report_text_before_gemini(self, MockClient):
        """Asserts server runs redact_text on report_text and sends redacted text to Gemini."""
        mock_instance = MockClient.return_value
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "summary": "Patient hemoglobin is normal.",
            "dietary_action_plan": ["Normal diet"],
            "results": [{"test_name": "Hemoglobin", "value": "13.5", "unit": "g/dL", "reference_range": "12-16", "status": "Normal"}]
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

        # Find the safe_text payload passed to Gemini
        gemini_text_payload = " ".join([c for c in contents if isinstance(c, str)])

        # Assert raw sensitive numbers are NOT present
        self.assertNotIn("01712345678", gemini_text_payload, "Raw phone number leaked to Gemini!")
        self.assertNotIn("19901234567890123", gemini_text_payload, "Raw NID leaked to Gemini!")

        # Assert redaction tokens ARE present
        self.assertIn("[REDACTED_PHONE]", gemini_text_payload)
        self.assertIn("[REDACTED_ID]", gemini_text_payload)
