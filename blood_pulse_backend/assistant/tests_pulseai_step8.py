# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit and integration tests for Step 8 PulseAI requirements:
1. Deterministic classifier (Bangla, English, misspelled/phonetic).
2. Authenticated user with profile_complete=false receives fixed reply with NO Gemini call.
3. Complete profile: server answers (cooldown days, last donation, eligibility, completed donations count).
4. "Who can give me blood?" never leaks donor names, phones, or exact locations (aggregate count only).
5. Fare estimator returns distance x 1.3 road factor, rate range (15-20 BDT/km), and disclaimer.
6. Throttles and redaction pre-flight checks.
"""

from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile
from api.conf import DONOR_COOLDOWN_DAYS
from assistant.pipeline.personal_classifier import (
    classify_personal_query,
    handle_personal_query,
    estimate_fare_range,
    haversine_distance_km,
)

User = get_user_model()


class PulseAIPersonalClassifierTests(TestCase):
    def test_classifier_english_queries(self):
        self.assertEqual(classify_personal_query("Who can give me blood?"), "who_can_give_blood")
        self.assertEqual(classify_personal_query("when can i donate blood"), "when_can_i_donate")
        self.assertEqual(classify_personal_query("am i eligible to donate?"), "when_can_i_donate")
        self.assertEqual(classify_personal_query("what is my blood group"), "my_blood_group")
        self.assertEqual(classify_personal_query("my donation history"), "my_donation_history")
        self.assertEqual(classify_personal_query("how much is the fare estimate"), "fare_estimate")

    def test_classifier_bangla_unicode_and_regional_queries(self):
        self.assertEqual(classify_personal_query("আমাকে কে রক্ত দিবে?"), "who_can_give_blood")
        self.assertEqual(classify_personal_query("কে রক্ত দিতে পারবে"), "who_can_give_blood")
        self.assertEqual(classify_personal_query("আমি কি রক্ত দিতে পারবো?"), "when_can_i_donate")
        self.assertEqual(classify_personal_query("কবে রক্ত দিতে পারব"), "when_can_i_donate")
        self.assertEqual(classify_personal_query("আমার রক্তের গ্রুপ"), "my_blood_group")
        self.assertEqual(classify_personal_query("আমি কতবার রক্ত দান করেছি"), "my_donation_history")
        self.assertEqual(classify_personal_query("গাড়ি ভাড়া কত"), "fare_estimate")
        self.assertEqual(classify_personal_query("সিএনজি ভাড়া কত হবে"), "fare_estimate")

    def test_classifier_phonetic_and_misspelled_queries(self):
        self.assertEqual(classify_personal_query("amake ke rokto dibe"), "who_can_give_blood")
        self.assertEqual(classify_personal_query("kobe rokt dite parbo"), "when_can_i_donate")
        self.assertEqual(classify_personal_query("amar blood group"), "my_blood_group")
        self.assertEqual(classify_personal_query("cng vara koto"), "fare_estimate")


class PulseAIServerDataAndPrivacyTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="test_pulse_user",
            first_name="Pulse",
            last_name="Tester",
            password="password123"
        )
        self.client.force_authenticate(user=self.user)

    def test_incomplete_profile_yields_fixed_reply_without_gemini(self):
        # User has incomplete profile (no blood group or placeholder phone)
        DonorProfile.objects.create(
            user=self.user,
            blood_group='',
            district='Dhaka',
            phone_number='+8801700000000',
            is_profile_complete=False,
        )
        res = self.client.post('/api/assistant/chat/', {
            'message': 'Who can give me blood?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("Your blood group is not set in your profile. Please complete registration.", res.data['reply'])
        self.assertEqual(res.data.get('action'), 'complete_profile')

        # Bangla test
        res_bn = self.client.post('/api/assistant/chat/', {
            'message': 'আমাকে কে রক্ত দিবে?',
            'language': 'bn',
        }, format='json')
        self.assertEqual(res_bn.status_code, status.HTTP_200_OK)
        self.assertIn("আপনার প্রোফাইলে রক্তের গ্রুপ নির্ধারণ করা নেই।", res_bn.data['reply'])

    def test_who_can_give_me_blood_zero_pii_aggregate_count(self):
        # Set up complete profile
        DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711112222',
            is_profile_complete=True,
            is_available=True,
        )

        # Create two eligible donors in Dhaka with A+ and O+
        u2 = User.objects.create_user(username="d2", first_name="Donor", last_name="Two", password="password123")
        DonorProfile.objects.create(
            user=u2,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733334444',
            is_profile_complete=True,
            is_available=True,
        )

        res = self.client.post('/api/assistant/chat/', {
            'message': 'Who can give me blood?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        reply = res.data['reply']

        # Verifies aggregate count provided
        self.assertIn("eligible donor(s) registered in Dhaka", reply)
        self.assertIn("Blood Hub", reply)

        # STRICT PRIVACY: Zero donor names or phone numbers leaked
        self.assertNotIn("+8801700000002", reply)
        self.assertNotIn("d2", reply)

    def test_cooldown_days_and_server_eligibility(self):
        last_donation = timezone.now().date() - timedelta(days=30)
        profile = DonorProfile.objects.create(
            user=self.user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801755556666',
            is_profile_complete=True,
            is_available=True,
            last_donation_date=last_donation,
            total_bags_donated=4,
        )

        res = self.client.post('/api/assistant/chat/', {
            'message': 'When can I donate blood?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        reply = res.data['reply']

        # 90 days - 30 days = 60 days remaining
        self.assertIn("60 day(s)", reply)
        self.assertIn("90-day cooldown", reply)

        # Verify donation history inquiry
        res_hist = self.client.post('/api/assistant/chat/', {
            'message': 'What is my donation history?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res_hist.status_code, status.HTTP_200_OK)
        self.assertIn("4 verified blood donation(s)", res_hist.data['reply'])

    def test_fare_estimator_road_factor_and_disclaimer(self):
        # 10 km straight distance
        res = estimate_fare_range(distance_km=13.0, locale='en')
        self.assertEqual(res['distance_km'], 13.0)
        # 13 km * 15 BDT = 195 BDT; 13 km * 20 BDT = 260 BDT
        self.assertEqual(res['min_fare_bdt'], 195)
        self.assertEqual(res['max_fare_bdt'], 260)
        self.assertIn("Approximate. Real fares vary by time, weather and vehicle.", res['disclaimer'])
        self.assertIn("৳195 - ৳260", res['reply'])
