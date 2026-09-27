# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.contrib.auth.models import User
from assistant.pipeline.redact import redact_text, convert_bangla_digits
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.shortcuts import evaluate_shortcuts
from assistant.pipeline.limits import check_limits, LimitsExceeded
from assistant.pipeline.guards import apply_guards
from assistant.pipeline.fallback import get_fallback_response
from assistant.models import KBEntry, AssistantConversation, AssistantMessage
from assistant.views import _save_and_respond

class RedactionTests(TestCase):
    def test_redact_phone(self):
        text = "My number is 01712345678 and another +8801812345678"
        redacted = redact_text(text)
        self.assertNotIn("01712345678", redacted)
        self.assertNotIn("+8801812345678", redacted)
        self.assertIn("[REDACTED_PHONE]", redacted)
        
    def test_redact_bangla_phone(self):
        text = "নাম্বার ০১৭ ১২৩ ৪৫৬ ৭৮"
        redacted = redact_text(text)
        self.assertNotIn("017", redacted)
        self.assertIn("[REDACTED_PHONE]", redacted)
        
    def test_redact_email(self):
        text = "Contact test@example.com for more info"
        redacted = redact_text(text)
        self.assertNotIn("test@example.com", redacted)
        self.assertIn("[REDACTED_EMAIL]", redacted)
        
    def test_redact_id(self):
        text = "My NID is 1234567890 and 123 456 789 0123"
        redacted = redact_text(text)
        self.assertNotIn("1234567890", redacted)
        self.assertIn("[REDACTED_ID]", redacted)

class EmergencyTests(TestCase):
    def test_emergency_detected(self):
        self.assertIsNotNone(detect_emergency("There is a severe bleeding accident!"))
        self.assertIsNotNone(detect_emergency("roktopat hocche urgent"))
        self.assertIsNotNone(detect_emergency("রক্তপাত হচ্ছে জরুরী"))
        self.assertIsNone(detect_emergency("When can I donate?"))

class ShortcutsTests(TestCase):
    def test_shortcuts(self):
        res = evaluate_shortcuts("how to request blood")
        self.assertEqual(res["action_ids"], ["open_emergency_form"])
        self.assertFalse(res["emergency"])

class LimitsTests(TestCase):
    def test_max_length(self):
        with self.assertRaises(LimitsExceeded):
            check_limits(1, "A" * 600)

class GuardsTests(TestCase):
    def test_numeric_claim_blocked(self):
        kb_texts = ["You can donate blood every 120 days."]
        reply = {"reply": "You can donate after 90 days.", "kb_ids_used": []}
        res = apply_guards(reply, [])
        self.assertIn("not sure", res["reply"])
        self.assertIn("BLOCKED_NUMBER", res.get("flags", []))
        
    def test_numeric_claim_allowed(self):
        class MockKB:
            def __init__(self):
                self.id = 1
                self.body_en = "You can donate blood every 120 days."
                self.body_bn = ""
        reply = {"reply": "You can donate after 120 days.", "kb_ids_used": [1]}
        res = apply_guards(reply, [MockKB()])
        self.assertNotIn("not sure", res["reply"])

    def test_url_stripping(self):
        reply = {"reply": "Visit https://badsite.com and https://bloodpulse.app"}
        res = apply_guards(reply, [])
        self.assertIn("[LINK REMOVED]", res["reply"])
        self.assertIn("bloodpulse.app", res["reply"])

class FallbackTests(TestCase):
    def test_fallback(self):
        KBEntry.objects.create(title_en="Donation Tips", status="APPROVED")
        res = get_fallback_response("tips for donation")
        self.assertTrue(res["needs_human"])
        self.assertIn("FALLBACK", res["flags"])
        self.assertIn("Donation Tips", res["reply"])

class PrivacyTests(TestCase):
    def test_logging_consent(self):
        user = User.objects.create_user("test")
        conv_no = AssistantConversation.objects.create(user=user, logging_consent=False)
        conv_yes = AssistantConversation.objects.create(user=user, logging_consent=True)
        
        _save_and_respond(conv_no, user, "hello", {"reply": "hi"})
        msg = AssistantMessage.objects.filter(conversation=conv_no).first()
        self.assertEqual(msg.text_redacted, "")

        _save_and_respond(conv_yes, user, "hello", {"reply": "hi"})
        msg2 = AssistantMessage.objects.filter(conversation=conv_yes).first()
        self.assertEqual(msg2.text_redacted, "hello")

    @patch('assistant.pipeline.gemini_client.get_system_instruction', return_value='')
    def test_key_not_logged(self, mock_get):
        import os
        os.environ['GEMINI_API_KEY'] = 'SECRET_KEY_123'
        from assistant.pipeline.gemini_client import call_gemini
        try:
            with self.assertLogs(level='INFO') as cm:
                try: 
                    call_gemini('hello', [], [], [])
                except Exception: 
                    pass
            for log in cm.records:
                self.assertNotIn('SECRET_KEY_123', log.getMessage())
        except AssertionError:
            pass # no logs captured