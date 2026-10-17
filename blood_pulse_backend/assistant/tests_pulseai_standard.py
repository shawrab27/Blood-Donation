# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from assistant.pipeline.response_validator import (
    validate_and_format_response,
    detect_red_flags,
    detect_out_of_scope,
    is_bangla_text
)
from assistant.pipeline.limits import check_limits, LimitsExceeded
from api.models import DonorProfile

class PulseAIStandardResponseTests(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='pulseai_tester',
            password='Password123!',
            first_name='Test',
            last_name='Donor'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='+8801712345678',
            blood_group='O+',
            district='Dhaka',
            is_available=True,
            is_verified=True,
            email_verified=True
        )

    # 1. Guest access to PulseAI is allowed (Task 10C requirement)
    def test_guest_access_allowed(self):
        anon_client = APIClient()
        response = anon_client.post(
            '/api/assistant/chat/',
            {'message': 'how can I donate blood', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)

    # 2. Logged-in user access succeeds
    def test_authenticated_user_access_succeeds(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': 'how can I donate blood', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('reply', data)
        self.assertIsNotNone(data.get('conversation_id'))

    # 3. Guest rate limit per device/IP triggers 429
    def test_guest_rate_limiting_by_ip(self):
        test_ip = '198.51.100.99'
        # Limit is 15/hour for guest
        for _ in range(15):
            check_limits(user_id=None, message_text='ping', client_ip=test_ip)
            from assistant.pipeline.limits import record_usage
            record_usage(user_id=None, client_ip=test_ip)

        with self.assertRaises(LimitsExceeded) as ctx:
            check_limits(user_id=None, message_text='ping', client_ip=test_ip)
        self.assertEqual(ctx.exception.code, 'RATE_LIMITED')

    # 4. Response validator: language match (Bangla)
    def test_response_validator_bangla_match(self):
        user_query = "রক্তদানের নিয়ম কী?"
        raw_reply = "রক্তদানের সাধারণ নিয়মাবলী:\n• বয়স ১৮-৬০ বছর হতে হবে।\n• ওজন কমপক্ষে ৫০ কেজি হতে হবে।"
        res = validate_and_format_response(raw_reply, user_query, locale='bn')
        self.assertEqual(res['language'], 'bn')
        self.assertIn('বয়স ১৮-৬০', res['reply'])

    # 5. Response validator: bullet limit <= 6
    def test_response_validator_bullet_limit_enforced(self):
        user_query = "What are the rules?"
        raw_reply = "Here are the requirements:\n" + "\n".join([f"• Point {i}" for i in range(1, 12)])
        res = validate_and_format_response(raw_reply, user_query, locale='en')
        bullet_lines = [l for l in res['reply'].split('\n') if l.strip().startswith('•')]
        self.assertLessEqual(len(bullet_lines), 6)

    # 6. Response validator: Red-flag message appears first (999)
    def test_response_validator_red_flag_alert_first(self):
        user_query = "I have severe chest pain and difficulty breathing after donating"
        raw_reply = "You can rest a bit."
        res = validate_and_format_response(raw_reply, user_query, locale='en')
        self.assertTrue(res['emergency'])
        self.assertTrue(res['reply'].startswith("🚨 Emergency Alert"))
        self.assertIn("999", res['reply'])
        self.assertIn("call_999", res['action_ids'])

    # 7. Response validator: Out-of-scope redirection
    def test_response_validator_out_of_scope_redirect(self):
        user_query = "Write me a python script for binary search"
        raw_reply = "Sure, def binary_search..."
        res = validate_and_format_response(raw_reply, user_query, locale='en')
        self.assertTrue(res['out_of_scope'])
        self.assertIn("outside my scope", res['reply'])
        self.assertIn("eligibility", res['reply'])

    # 8. Empty query returns 400
    def test_empty_query_returns_400(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': '   '},
            format='json'
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json().get('code'), 'EMPTY_MESSAGE')

    # 9. Anomaly #17: Pasted CBC Blood Report in PulseAI Chat
    def test_pasted_cbc_blood_report_parsing_in_pulseai(self):
        self.client.force_authenticate(user=self.user)
        query = (
            "Please check my CBC report:\n"
            "Hemoglobin: 11.2 g/dL\n"
            "Platelets: 130,000 /mcL\n"
            "WBC: 7,500 /mcL\n"
            "RBC: 4.5 million/mcL"
        )
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': query, 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        reply = data.get('reply', '')
        self.assertIn("Blood Report (CBC) Analysis", reply)
        self.assertIn("Hemoglobin", reply)
        self.assertIn("Platelets", reply)
        self.assertIn("WBC", reply)
        self.assertIn("RBC", reply)
        self.assertIn("NOT CURRENTLY ELIGIBLE", reply)
        self.assertIn("Medical Disclaimer", reply)

    def test_pasted_cbc_eligible_donor_report(self):
        self.client.force_authenticate(user=self.user)
        query = (
            "CBC results:\n"
            "Hemoglobin: 14.2 g/dL\n"
            "Platelets: 260,000 /mcL\n"
            "WBC: 6,800 /mcL\n"
            "RBC: 4.9 million/mcL"
        )
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': query, 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        reply = data.get('reply', '')
        self.assertIn("ELIGIBLE", reply)
        self.assertIn("Medical Disclaimer", reply)

    # 10. Anomaly #20: Bangla / Banglish / English language support
    def test_language_support_english_query(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': 'What is the mandatory interval between blood donations?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get('language'), 'en')
        self.assertIn('90 days', data.get('reply', '').lower())

    def test_language_support_bangla_query(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': 'কত দিন পর রক্ত দেওয়া যায়?', 'locale': 'bn'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get('language'), 'bn')
        reply = data.get('reply', '')
        self.assertTrue('90 দিন' in reply or '৯০ দিন' in reply, f"90 days in Bangla not found in: {reply}")

    def test_language_support_banglish_query(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            '/api/assistant/chat/',
            {'message': 'kobe rokto dite parbo?', 'locale': 'en'},
            format='json'
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        # Banglish must resolve to Bangla script response!
        self.assertEqual(data.get('language'), 'bn')
        reply = data.get('reply', '')
        # Must be in Bengali Unicode script
        import re
        self.assertTrue(bool(re.search(r'[\u0980-\u09FF]', reply)), "Banglish reply was not in Bengali script!")


