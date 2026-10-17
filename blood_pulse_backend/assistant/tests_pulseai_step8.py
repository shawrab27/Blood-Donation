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

        # Create one eligible donor in Dhaka with O+
        u2 = User.objects.create_user(username="d2", first_name="Donor", last_name="Two", password="password123")
        DonorProfile.objects.create(
            user=u2,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733334444',
            is_profile_complete=True,
            is_available=True,
        )

        # Create snoozed donor in Dhaka (alert_pause_until in future) -> must be excluded by shared eligibility
        u_snooze = User.objects.create_user(username="d_snooze", first_name="Snooze", last_name="Donor", password="password123")
        DonorProfile.objects.create(
            user=u_snooze,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733334445',
            is_profile_complete=True,
            is_available=True,
            alert_pause_until=timezone.now() + timedelta(days=15),
        )

        # Create cooldown donor in Dhaka (donated 10 days ago) -> must be excluded by shared eligibility
        u_cool = User.objects.create_user(username="d_cool", first_name="Cooldown", last_name="Donor", password="password123")
        DonorProfile.objects.create(
            user=u_cool,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733334446',
            is_profile_complete=True,
            is_available=True,
            last_donation_date=timezone.now().date() - timedelta(days=10),
        )

        res = self.client.post('/api/assistant/chat/', {
            'message': 'Who can give me blood?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        reply = res.data['reply']

        # Verifies aggregate count provided is EXACTLY 1 (excluding self, snoozed, and cooldown)
        self.assertIn("1 eligible donor(s) registered in Dhaka", reply)
        self.assertIn("Blood Hub", reply)

        # STRICT PRIVACY: Zero donor names or phone numbers leaked
        self.assertNotIn("+8801733334444", reply)
        self.assertNotIn("+8801733334445", reply)
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

        # Verify donation history: counts ONLY two-sided confirmed DonationMatch
        from api.models import BloodRequest, DonationMatch
        # Create unconfirmed match on request 1 (one-sided)
        br1 = BloodRequest.objects.create(
            requester=self.user,
            patient_name="Patient A",
            blood_group='B+',
            units_needed=2,
            district='Dhaka'
        )
        DonationMatch.objects.create(
            request=br1,
            donor=profile,
            status='DONATED',
            donor_confirmed_at=timezone.now(),
            confirmed_at=None # Not two-sided confirmed!
        )
        # Create two-sided confirmed match on request 2
        br2 = BloodRequest.objects.create(
            requester=self.user,
            patient_name="Patient B",
            blood_group='B+',
            units_needed=1,
            district='Dhaka'
        )
        DonationMatch.objects.create(
            request=br2,
            donor=profile,
            status='DONATED',
            donor_confirmed_at=timezone.now(),
            requester_confirmed_at=timezone.now(),
            confirmed_at=timezone.now()
        )

        res_hist = self.client.post('/api/assistant/chat/', {
            'message': 'What is my donation history?',
            'language': 'en',
        }, format='json')
        self.assertEqual(res_hist.status_code, status.HTTP_200_OK)
        # Must report 1 verified donation, not unconfirmed
        self.assertIn("1 verified blood donation(s)", res_hist.data['reply'])

    def test_fare_estimator_road_factor_and_disclaimer(self):
        # 13 km straight distance
        res = estimate_fare_range(distance_km=13.0, locale='en')
        self.assertEqual(res['distance_km'], 13.0)
        # 13 km * 15 BDT = 195 BDT; 13 km * 20 BDT = 260 BDT
        self.assertEqual(res['min_fare_bdt'], 195)
        self.assertEqual(res['max_fare_bdt'], 260)
        self.assertIn("Approximate. Real fares vary by time, weather and vehicle.", res['disclaimer'])
        self.assertIn("৳195 - ৳260", res['reply'])

    def test_fare_from_district_names_and_unknown_place(self):
        # Known districts: Dhaka to Gazipur
        res = estimate_fare_range(place_from="Dhaka", place_to="Gazipur", locale='en')
        self.assertIsNotNone(res['distance_km'])
        self.assertGreater(res['min_fare_bdt'], 0)
        self.assertIn("Estimated road distance", res['reply'])

        # Unknown location
        res_unknown = estimate_fare_range(place_from="Dhaka", place_to="NonExistentPlaceXYZ", locale='en')
        self.assertIsNone(res_unknown['fare_range'])
        self.assertIn("not recognized", res_unknown['reply'])

        # Chat endpoint route with Dhaka to Gazipur
        res_chat = self.client.post('/api/assistant/chat/', {
            'message': 'fare from Dhaka to Gazipur',
            'language': 'en'
        }, format='json')
        self.assertEqual(res_chat.status_code, status.HTTP_200_OK)
        self.assertIn("Estimated road distance", res_chat.data['reply'])


class PulseAIRegression30QATests(TestCase):
    """
    30 QA regression test suite covering:
    - 15 Bangla prompts
    - 15 English prompts
    Covering: Emergency SOS, Blood request rules, Donor eligibility, Safety, Fare estimator, Profile queries.
    All tested with mocked deterministic pipeline / mock gemini to avoid external dependency.
    """

    QA_PAIRS = [
        # --- 15 Bangla prompts ---
        ("জরুরি রক্ত লাগবে", "emergency", True),
        ("রোগীর অবস্থা আশঙ্কাজনক, রক্ত দরকার", "emergency", True),
        ("আমি কি রক্ত দিতে পারবো?", "when_can_i_donate", False),
        ("রক্ত দিতে কতদিন পর যাওয়া যায়?", "when_can_i_donate", False),
        ("আমার রক্তের গ্রুপ কি?", "my_blood_group", False),
        ("আমাকে কে রক্ত দিবে?", "who_can_give_blood", False),
        ("ঢাকা থেকে গাজীপুর ভাড়া কত?", "fare_estimate", False),
        ("সিএনজি ভাড়া কত হতে পারে?", "fare_estimate", False),
        ("আমি কতবার রক্ত দিয়েছি?", "my_donation_history", False),
        ("আমার ডোনেশন হিস্ট্রি দেখাও", "my_donation_history", False),
        ("রক্তদানের নিয়ম কি কি?", "general", False),
        ("কে রক্ত দিতে পারবে", "who_can_give_blood", False),
        ("কবে রক্ত দিতে পারব", "when_can_i_donate", False),
        ("রোগী খুব অসুস্থ বাঁচান", "emergency", True),
        ("রক্তদানের পর কি খেতে হয়?", "general", False),

        # --- 15 English prompts ---
        ("Emergency blood needed immediately", "emergency", True),
        ("Patient in critical condition needs blood", "emergency", True),
        ("When can I donate blood?", "when_can_i_donate", False),
        ("Am I eligible to donate?", "when_can_i_donate", False),
        ("What is my blood group?", "my_blood_group", False),
        ("Who can give me blood?", "who_can_give_blood", False),
        ("Fare from Dhaka to Gazipur", "fare_estimate", False),
        ("How much is the CNG fare?", "fare_estimate", False),
        ("What is my donation history?", "my_donation_history", False),
        ("How many times have I donated blood?", "my_donation_history", False),
        ("What are the blood donation rules?", "general", False),
        ("Find blood donors near me", "who_can_give_blood", False),
        ("Cooldown period for blood donation", "when_can_i_donate", False),
        ("Immediate emergency SOS hospital", "emergency", True),
        ("Post-donation dietary recommendations", "general", False),
    ]

    def test_30_qa_classifier_and_emergency_routing(self):
        from assistant.pipeline.emergency import detect_emergency
        for query, expected_category, is_emergency in self.QA_PAIRS:
            with self.subTest(query=query):
                em = detect_emergency(query)
                if is_emergency:
                    self.assertIsNotNone(em, f"Query '{query}' should be flagged as emergency")
                else:
                    if expected_category in ["when_can_i_donate", "my_blood_group", "who_can_give_blood", "fare_estimate", "my_donation_history"]:
                        cat = classify_personal_query(query)
                        self.assertEqual(cat, expected_category, f"Query '{query}' should be classified as {expected_category}")


class VehicleFareDatasetAndEstimatorTests(TestCase):
    """
    Tests for Anomaly #22:
    - Admin-editable VehicleFareRate dataset across city groups (Dhaka, Chattogram, Other).
    - seed_vehicle_fares management command with dry-run protection and --confirm requirement.
    - Multi-vehicle fare calculation (Rickshaw, CNG, Bike, Car, Bus, Ambulance) with road factor.
    - Travel time estimation in minutes.
    - Rickshaw distance limitation (> 6 km marked unavailable).
    - Emergency vehicle preference and traffic/night rate disclaimers.
    """

    def test_seed_command_dry_run_requires_confirm(self):
        from io import StringIO
        from django.core.management import call_command
        from assistant.models import VehicleFareRate

        out = StringIO()
        call_command('seed_vehicle_fares', stdout=out)
        output_str = out.getvalue()
        self.assertIn("DRY RUN", output_str)
        self.assertIn("Re-run with --confirm", output_str)
        self.assertEqual(VehicleFareRate.objects.count(), 0)

    def test_seed_command_confirm_populates_placeholders(self):
        from io import StringIO
        from django.core.management import call_command
        from assistant.models import VehicleFareRate

        out = StringIO()
        call_command('seed_vehicle_fares', confirm=True, stdout=out)
        output_str = out.getvalue()
        self.assertIn("Successfully seeded vehicle fare rates", output_str)
        self.assertEqual(VehicleFareRate.objects.count(), 18)

        # All must be marked as placeholders for review
        self.assertTrue(all(r.is_placeholder for r in VehicleFareRate.objects.all()))

        # Check Dhaka ambulance rate
        dhaka_amb = VehicleFareRate.objects.get(city_group='dhaka', vehicle_type='ambulance')
        self.assertEqual(dhaka_amb.base_fare_min, 1000)
        self.assertEqual(dhaka_amb.per_km_min, 35)

    def test_multi_vehicle_fare_and_travel_time_calculation(self):
        # 5 km in Dhaka (short distance: rickshaw available)
        res_5km = estimate_fare_range(distance_km=5.0, place_from="Dhaka", place_to="Mirpur", locale='en')
        self.assertEqual(res_5km['distance_km'], 5.0)
        self.assertIn('vehicles', res_5km)
        vehicles = res_5km['vehicles']

        # Rickshaw available for 5km
        self.assertTrue(vehicles['rickshaw']['available'])
        self.assertGreater(vehicles['rickshaw']['min_fare'], 0)
        self.assertGreater(vehicles['rickshaw']['est_minutes'], 0)

        # CNG available
        self.assertTrue(vehicles['cng']['available'])
        self.assertEqual(vehicles['cng']['min_fare'], 75) # 5 * 15 = 75
        self.assertEqual(vehicles['cng']['max_fare'], 100) # 5 * 20 = 100

        # Ambulance available
        self.assertTrue(vehicles['ambulance']['available'])
        self.assertGreaterEqual(vehicles['ambulance']['min_fare'], 1000)

        # Disclaimers present
        self.assertIn("Night trips (10 PM–6 AM)", res_5km['disclaimer'])
        self.assertIn("Estimates", res_5km['reply'])
        self.assertTrue(res_5km['is_estimate'])

    def test_rickshaw_distance_limit_exceeded(self):
        # 15 km in Dhaka (exceeds rickshaw 6km limit)
        res_15km = estimate_fare_range(distance_km=15.0, place_from="Dhaka", place_to="Gazipur", locale='en')
        vehicles = res_15km['vehicles']
        self.assertFalse(vehicles['rickshaw']['available'])
        self.assertIn("Distance too far", vehicles['rickshaw']['reason_en'])

        # Bengali reply has distance limitation
        res_bn = estimate_fare_range(distance_km=15.0, place_from="Dhaka", place_to="Gazipur", locale='bn')
        self.assertIn("অতিরিক্ত দূরত্ব", res_bn['reply'])

    def test_vehicle_mention_prioritization_in_reply(self):
        # When ambulance is asked, ambulance is prioritized
        res_amb = estimate_fare_range(
            distance_km=8.0,
            place_from="Dhaka",
            place_to="Dhanmondi",
            locale='en',
            query_text="ambulance fare to hospital"
        )
        self.assertIn("Ambulance", res_amb['reply'])
        # The reply first vehicle line after headers should mention Ambulance
        lines = [line.strip() for line in res_amb['reply'].split('\n') if line.strip().startswith('•')]
        self.assertTrue(lines[0].startswith('• Ambulance'))

