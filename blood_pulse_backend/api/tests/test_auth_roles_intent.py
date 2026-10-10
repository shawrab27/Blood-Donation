# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from unittest.mock import patch

from api.models import DonorProfile
from api.serializers import DonorProfileSerializer
from api.services.targeting_service import get_base_eligible_donor_queryset


class AuthRolesIntentTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_default_intent_is_donate_and_request(self):
        user = User.objects.create_user(username='donor1', email='donor1@example.com')
        profile = DonorProfile.objects.create(
            user=user,
            phone_number='+8801711111111',
            blood_group='O+',
            district='Dhaka',
            is_searchable=True,
        )
        self.assertEqual(profile.user_intent, 'DONATE_AND_REQUEST')
        serializer = DonorProfileSerializer(profile)
        self.assertEqual(serializer.data['user_intent'], 'DONATE_AND_REQUEST')

    def test_only_request_intent_forces_not_searchable(self):
        user = User.objects.create_user(username='requester1', email='req1@example.com')
        profile = DonorProfile.objects.create(
            user=user,
            phone_number='+8801722222222',
            blood_group='O+',
            district='Dhaka',
            user_intent='ONLY_REQUEST',
            is_searchable=True, # Attempting to mark true
        )
        # Should be forced to false or stay false
        profile.refresh_from_db()
        self.assertFalse(profile.is_searchable)
        self.assertEqual(profile.user_intent, 'ONLY_REQUEST')

    def test_only_request_excluded_from_targeting_query(self):
        # 1 donor with DONATE_AND_REQUEST
        user1 = User.objects.create_user(username='donor_ok', email='ok@example.com')
        DonorProfile.objects.create(
            user=user1,
            phone_number='+8801733333333',
            blood_group='O+',
            district='Dhaka',
            is_available=True,
            is_searchable=True,
            user_intent='DONATE_AND_REQUEST',
        )

        # 1 user with ONLY_REQUEST
        user2 = User.objects.create_user(username='req_only', email='req@example.com')
        DonorProfile.objects.create(
            user=user2,
            phone_number='+8801744444444',
            blood_group='O+',
            district='Dhaka',
            is_available=True,
            is_searchable=False,
            user_intent='ONLY_REQUEST',
        )

        qs = get_base_eligible_donor_queryset('O+')
        donor_usernames = [d.user.username for d in qs]
        self.assertIn('donor_ok', donor_usernames)
        self.assertNotIn('req_only', donor_usernames)

    def test_registration_endpoint_with_only_request(self):
        payload = {
            'username': 'req_api_user',
            'phone_number': '+8801755555555',
            'blood_group': 'B+',
            'district': 'Chittagong',
            'user_intent': 'ONLY_REQUEST',
            'full_name': 'Receiver Only',
        }
        response = self.client.post('/api/donors/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data.get('user_intent'), 'ONLY_REQUEST')
        profile = DonorProfile.objects.get(phone_number='+8801755555555')
        self.assertEqual(profile.user_intent, 'ONLY_REQUEST')
        self.assertFalse(profile.is_searchable)

    def test_pulseai_guard_for_incomplete_profile(self):
        from api.services.assistant_service import PulseAIAssistant
        assistant = PulseAIAssistant.get_instance()

        # Incomplete profile context with missing blood group
        incomplete_context = {
            'is_profile_complete': False,
            'blood_group': '',
        }
        res_en = assistant.answer_query(
            "Who can give me blood?",
            lang='en',
            profile_context=incomplete_context
        )
        self.assertEqual(
            res_en.get('answer_en'),
            "Your blood group is not set in your profile. Please complete registration."
        )

        res_bn = assistant.answer_query(
            "আমাকে কে রক্ত দিতে পারবে?",
            lang='bn',
            profile_context=incomplete_context
        )
        self.assertEqual(
            res_bn.get('answer_bn'),
            "আপনার প্রোফাইলে রক্তের গ্রুপ নির্ধারণ করা নেই। অনুগ্রহ করে রেজিস্ট্রেশন সম্পূর্ণ করুন।"
        )
