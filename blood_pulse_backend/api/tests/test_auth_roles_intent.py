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

    def test_profile_complete_matrix(self):
        # 1. DONATE_AND_REQUEST without blood group is incomplete
        user1 = User.objects.create_user(username='u_matrix1', email='m1@example.com')
        p1 = DonorProfile.objects.create(
            user=user1,
            phone_number='+8801711223344',
            district='Dhaka',
            blood_group='',
            user_intent='DONATE_AND_REQUEST',
        )
        complete1, missing1 = p1.check_is_complete()
        self.assertFalse(complete1)
        self.assertIn('blood_group', missing1)

        # 2. ONLY_REQUEST without blood group IS complete if phone and district are set
        user2 = User.objects.create_user(username='u_matrix2', email='m2@example.com', first_name='Requester')
        p2 = DonorProfile.objects.create(
            user=user2,
            phone_number='+8801711223355',
            district='Dhaka',
            blood_group='',
            user_intent='ONLY_REQUEST',
        )
        complete2, missing2 = p2.check_is_complete()
        self.assertTrue(complete2)
        self.assertNotIn('blood_group', missing2)

    def test_request_only_excluded_from_search_map_wave_eligibility(self):
        from api.services.eligibility import evaluate_donor_eligibility
        from api.services.waves import get_candidate_donors_for_wave
        from api.models import BloodRequest

        # Donor who only requests blood
        user_req = User.objects.create_user(username='only_req_user', email='req_user@example.com', first_name='OnlyReq')
        profile_req = DonorProfile.objects.create(
            user=user_req,
            phone_number='+8801799887766',
            district='Dhaka',
            blood_group='O+',
            user_intent='ONLY_REQUEST',
            is_available=True,
            is_searchable=False,
            latitude=23.8103,
            longitude=90.4125,
        )

        # Eligibility check
        elig = evaluate_donor_eligibility(profile_req)
        self.assertFalse(elig['is_eligible'])
        self.assertIn('User has registered to only request blood', elig['reason'])

        # Wave candidates check
        br = BloodRequest.objects.create(
            patient_name='Patient 1',
            blood_group='O+',
            units_needed=1,
            hospital_location='Dhaka Medical',
            contact_number='+8801700000000',
        )
        candidates = get_candidate_donors_for_wave(br)
        candidate_ids = [c.id for c in candidates]
        self.assertNotIn(profile_req.id, candidate_ids)

        # Donor search view check
        res_search = self.client.get('/api/donors/search/', {'blood_group': 'O+'})
        self.assertEqual(res_search.status_code, 200)
        search_ids = [d['id'] for d in res_search.data.get('results', res_search.data)]
        self.assertNotIn(profile_req.id, search_ids)

        # Donor map view check
        res_map = self.client.get('/api/donors/map/', {'blood_group': 'O+'})
        self.assertEqual(res_map.status_code, 200)
        map_donors = res_map.data.get('results', res_map.data.get('donors', []))
        map_ids = [d['id'] for d in map_donors]
        self.assertNotIn(profile_req.id, map_ids)

    def test_google_user_without_password_completes_profile(self):
        # Create Google user without usable password
        user = User.objects.create_user(username='google_user', email='google@example.com')
        user.set_unusable_password()
        user.save()
        profile = DonorProfile.objects.create(user=user)

        self.client.force_authenticate(user=user)

        # First PATCH: completes profile, sets blood_group, no password required
        patch_data = {
            'phone_number': '+8801812345678',
            'district': 'Dhaka',
            'blood_group': 'B+',
            'full_name': 'Google Donor',
            'user_intent': 'DONATE_AND_REQUEST',
        }
        res = self.client.patch('/api/donors/me/', patch_data, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        profile.refresh_from_db()
        self.assertEqual(user.first_name, 'Google')
        self.assertEqual(user.last_name, 'Donor')
        self.assertEqual(profile.blood_group, 'B+')

        # Second PATCH: user cannot change blood_group once set
        res_bg = self.client.patch('/api/donors/me/', {'blood_group': 'A+'}, format='json')
        self.assertEqual(res_bg.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('blood_group', res_bg.data)

        # Third PATCH: user cannot set admin-locked is_verified (silently ignored per D3 intent, profile remains unverified)
        res_locked = self.client.patch('/api/donors/me/', {'is_verified': True}, format='json')
        self.assertEqual(res_locked.status_code, status.HTTP_200_OK)
        profile.refresh_from_db()
        self.assertFalse(profile.is_verified)

        # Admin-only field modification (e.g. total_bags_donated) is rejected with 400
        res_admin = self.client.patch('/api/donors/me/', {'total_bags_donated': 5}, format='json')
        self.assertEqual(res_admin.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('total_bags_donated', res_admin.data)
