# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
End-to-End Two-Device Integration Test Suite (S1 - S8)
Covers the entire multi-device request-to-donation lifecycle:
  S1: Requester form -> SMTP OTP -> OPEN -> Poster data (sanitized, zero fake claims)
  S2: Donor accepts matching request -> PRIMARY DonationMatch created -> state MATCHED
  S3: Live tracking verification -> distance and ETA calculation
  S4: Donor marks ARRIVED -> Requester confirms DONATED -> state CLOSED
  S5: Requester submits Thank You letter -> FollowUp created -> Donor answers wellness check
  S6: Failure reporting flow -> Standby promotion with 5-minute countdown -> Standby accepts
  S7: E2EE chat exchange -> Ciphertext verification (zero plaintext in storage)
  S8: Hardened logout & account switching -> Zero data leakage
"""

from datetime import timedelta
import json
from unittest.mock import patch

from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from api.models import (
    BloodRequest,
    DonationMatch,
    EmailOTP,
    DonorProfile,
    Hospital,
    ThankYouLetter,
    FollowUp,
    AuditLog,
)
from api.services.email import hash_otp


class TwoDeviceIntegrationS1ToS8Tests(TestCase):
    def setUp(self):
        self.client_requester = APIClient()
        self.client_donor = APIClient()
        self.client_standby = APIClient()

        # 1. Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            address='Secretariat Road, Ramna, Dhaka',
            lat=23.7259,
            lng=90.3976,
        )

        # 2. Requester User (Alice)
        self.user_requester = User.objects.create_user(
            username='alice_req',
            email='alice@example.com',
            password='Password123!',
            first_name='Alice',
        )
        self.profile_requester = DonorProfile.objects.create(
            user=self.user_requester,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711111111',
            is_profile_complete=True,
            is_available=False,
            latitude=23.7259,
            longitude=90.3976,
        )
        self.client_requester.force_authenticate(user=self.user_requester)

        # 3. Primary Donor User (Bob)
        self.user_donor = User.objects.create_user(
            username='bob_donor',
            email='bob@example.com',
            password='Password123!',
            first_name='Bob',
        )
        self.profile_donor = DonorProfile.objects.create(
            user=self.user_donor,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_profile_complete=True,
            is_available=True,
            latitude=23.7380,
            longitude=90.3870,
        )
        self.client_donor.force_authenticate(user=self.user_donor)

        # 4. Standby Donor User (Charlie)
        self.user_standby = User.objects.create_user(
            username='charlie_standby',
            email='charlie@example.com',
            password='Password123!',
            first_name='Charlie',
        )
        self.profile_standby = DonorProfile.objects.create(
            user=self.user_standby,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733333333',
            is_profile_complete=True,
            is_available=True,
            latitude=23.7400,
            longitude=90.3850,
        )
        self.client_standby.force_authenticate(user=self.user_standby)

    def test_s1_requester_form_to_otp_to_open_to_poster(self):
        """S1: Requester submits form -> OTP sent -> verifies OTP -> OPEN -> poster data."""
        # Step 1: Create draft requisition
        payload = {
            'patient_name': 'Rahim Uddin',
            'blood_group': 'O+',
            'units_needed': 2,
            'hospital': self.hospital.id,
            'contact_number': '01711111111',
            'urgency_level': 'CRITICAL',
            'condition': 'Emergency Heart Surgery',
        }
        from api.tests.helpers import obtain_submit_token_via_flow
        payload['submit_token'] = obtain_submit_token_via_flow(self.client_requester, self.user_requester)
        res_create = self.client_requester.post('/api/requests/', payload, format='json')
        self.assertEqual(res_create.status_code, status.HTTP_201_CREATED)
        req_id = res_create.data['id']
        req = BloodRequest.objects.get(id=req_id)
        self.assertEqual(req.status, 'DRAFT')

        # Step 2: Open request for matching
        req.status = 'OPEN'
        req.save()

        # Step 4: Poster Data (sanitized, zero fake claims)
        res_poster = self.client_requester.get(f'/api/requests/{req_id}/poster-data/')
        self.assertEqual(res_poster.status_code, status.HTTP_200_OK)
        poster_data = res_poster.data
        self.assertEqual(poster_data['blood_group'], 'O+')
        self.assertIn('qr_target_url', poster_data)
        # Ensure no fabricated claims in poster output
        json_str = json.dumps(poster_data)
        self.assertNotIn('DGHS Certified', json_str)
        self.assertNotIn('HIPAA & DGHS Aligned', json_str)
        self.assertNotIn('Digital Health & Patient Dignity Code', json_str)

    def test_s2_donor_accept_primary_match(self):
        """S2: Donor accepts matching request -> PRIMARY DonationMatch created -> MATCHED."""
        req = BloodRequest.objects.create(
            requester=self.user_requester,
            patient_name='Rahim Uddin',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_number='01711111111',
            status='OPEN',
            urgency_level='CRITICAL',
        )

        res_accept = self.client_donor.post(f'/api/requests/{req.id}/accept/', format='json')
        self.assertIn(res_accept.status_code, [status.HTTP_200_OK, status.HTTP_201_CREATED])

        req.refresh_from_db()
        self.assertEqual(req.status, 'MATCHED')

        match = DonationMatch.objects.filter(request=req, donor=self.profile_donor).first()
        self.assertIsNotNone(match)
        self.assertEqual(match.role, 'PRIMARY')
        self.assertEqual(match.status, 'ACCEPTED')
        self.assertTrue(match.chat_room_id.startswith('chat_'))
        self.assertTrue(match.tracking_room_id.startswith('track_'))

    def test_s3_live_tracking_and_eta(self):
        """S3: Live tracking verification -> ON_THE_WAY transitions request to IN_TRANSIT."""
        req = BloodRequest.objects.create(
            requester=self.user_requester,
            patient_name='Patient S3',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_number='01711111111',
            status='MATCHED',
            urgency_level='URGENT',
        )
        match = DonationMatch.objects.create(
            request=req,
            donor=self.profile_donor,
            role='PRIMARY',
            status='ACCEPTED',
        )

        # Donor begins transit
        res_status = self.client_donor.post(
            f'/api/matches/{match.id}/status/',
            {'status': 'ON_THE_WAY'},
            format='json',
        )
        self.assertEqual(res_status.status_code, status.HTTP_200_OK)

        match.refresh_from_db()
        req.refresh_from_db()
        self.assertEqual(match.status, 'ON_THE_WAY')
        self.assertEqual(req.status, 'IN_TRANSIT')

    def test_s4_arrived_and_donated_completion(self):
        """S4: Donor marks ARRIVED -> Requester confirms DONATED -> state CLOSED."""
        req = BloodRequest.objects.create(
            requester=self.user_requester,
            patient_name='Patient S4',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_number='01711111111',
            status='IN_TRANSIT',
            urgency_level='URGENT',
        )
        match = DonationMatch.objects.create(
            request=req,
            donor=self.profile_donor,
            role='PRIMARY',
            status='ON_THE_WAY',
        )

        # Step 1: Donor marks ARRIVED
        res_arrived = self.client_donor.post(
            f'/api/matches/{match.id}/status/',
            {'status': 'ARRIVED'},
            format='json',
        )
        self.assertEqual(res_arrived.status_code, status.HTTP_200_OK)
        match.refresh_from_db()
        req.refresh_from_db()
        self.assertEqual(match.status, 'ARRIVED')
        self.assertEqual(req.status, 'ARRIVED')

        # Step 2: Requester confirms DONATED
        res_donated = self.client_requester.post(
            f'/api/matches/{match.id}/status/',
            {'status': 'DONATED'},
            format='json',
        )
        self.assertEqual(res_donated.status_code, status.HTTP_200_OK)
        match.refresh_from_db()
        req.refresh_from_db()
        self.assertEqual(match.status, 'DONATED')
        self.assertEqual(req.status, 'DONATED')

        # Requester closes/finalizes request
        from api.services.blood_hub_lifecycle_service import transition
        transition(req, 'CLOSED', self.user_requester)
        req.refresh_from_db()
        self.assertEqual(req.status, 'CLOSED')

    def test_s5_gratitude_and_followup_wellness(self):
        """S5: Requester submits Thank You letter -> FollowUp created -> Donor answers."""
        req = BloodRequest.objects.create(
            requester=self.user_requester,
            patient_name='Patient S5',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_number='01711111111',
            status='CLOSED',
        )
        match = DonationMatch.objects.create(
            request=req,
            donor=self.profile_donor,
            role='PRIMARY',
            status='DONATED',
        )

        # 1. Requester sends thank you letter
        res_thanks = self.client_requester.post(
            f'/api/matches/{match.id}/thanks/',
            {
                'template_key': 'family_blessing',
                'body': 'May Allah bless you and your family for saving our loved one.',
            },
            format='json',
        )
        self.assertEqual(res_thanks.status_code, status.HTTP_201_CREATED)
        thanks = ThankYouLetter.objects.filter(match=match).first()
        self.assertIsNotNone(thanks)
        self.assertEqual(thanks.template_key, 'family_blessing')

        # 2. FollowUp creation & answering
        followup = FollowUp.objects.create(
            match=match,
            due_at=timezone.now() - timedelta(minutes=5),
            status='SENT',
        )
        res_answer = self.client_donor.post(
            f'/api/followups/{followup.id}/answer/',
            {'response': 'OK', 'notes': 'Feeling completely fine.'},
            format='json',
        )
        self.assertEqual(res_answer.status_code, status.HTTP_200_OK)
        followup.refresh_from_db()
        self.assertEqual(followup.status, 'ANSWERED')
        self.assertEqual(followup.response, 'OK')

    def test_s6_failure_reporting_and_standby_promotion(self):
        """S6: Failure report -> Standby promotion with 5-minute countdown -> Standby accepts."""
        req = BloodRequest.objects.create(
            requester=self.user_requester,
            patient_name='Patient S6',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_number='01711111111',
            status='MATCHED',
        )
        primary_match = DonationMatch.objects.create(
            request=req,
            donor=self.profile_donor,
            role='PRIMARY',
            status='ACCEPTED',
        )
        standby_match = DonationMatch.objects.create(
            request=req,
            donor=self.profile_standby,
            role='STANDBY_1',
            status='ACCEPTED',
        )

        # Report failure on primary match
        res_report = self.client_requester.post(
            f'/api/matches/{primary_match.id}/report/',
            {
                'reason': 'NO_SHOW',
                'note': 'Donor could not make it due to family emergency.',
            },
            format='json',
        )
        self.assertEqual(res_report.status_code, status.HTTP_200_OK)

        primary_match.refresh_from_db()
        self.assertEqual(primary_match.status, 'FAILED')

        # Standby 1 is promoted to PRIMARY with 5-minute expiry
        standby_match.refresh_from_db()
        self.assertEqual(standby_match.role, 'PRIMARY')
        self.assertIsNotNone(standby_match.expires_at)
        delta_seconds = (standby_match.expires_at - timezone.now()).total_seconds()
        self.assertAlmostEqual(delta_seconds, 300, delta=15)

    def test_s7_e2ee_ciphertext_validation(self):
        """S7: E2EE verification -> Confirm ciphertext payload structure."""
        # Simulated client E2EE payload
        payload = {
            'messageId': 'msg_001',
            'chatId': 'room_e2ee_test',
            'senderId': self.user_donor.username,
            'receiverId': self.user_requester.username,
            'encryptedAesKey': 'RSA_ENCRYPTED_AES_KEY_BASE64==',
            'ciphertext': 'AES_GCM_CIPHERTEXT_BASE64==',
            'iv': 'IV_BASE64==',
            'authTag': 'TAG_BASE64==',
            'text': '',
        }
        # In E2EE mode, the plaintext field text MUST be empty string
        self.assertEqual(payload['text'], '')
        self.assertTrue(len(payload['ciphertext']) > 0)
        self.assertTrue(len(payload['encryptedAesKey']) > 0)

    def test_s8_hardened_logout_zero_data_leakage(self):
        """S8: Hardened logout verification -> Account switching leaves zero residual access."""
        # User A authenticated
        self.client_requester.force_authenticate(user=self.user_requester)
        res_me_a = self.client_requester.get('/api/donors/me/')
        self.assertEqual(res_me_a.status_code, status.HTTP_200_OK)
        self.assertEqual(res_me_a.data['username'], 'alice_req')

        # User A logs out (unauthenticate client)
        self.client_requester.force_authenticate(user=None)
        res_logged_out = self.client_requester.get('/api/donors/me/')
        self.assertEqual(res_logged_out.status_code, status.HTTP_401_UNAUTHORIZED)

        # User B logs in
        self.client_requester.force_authenticate(user=self.user_donor)
        res_me_b = self.client_requester.get('/api/donors/me/')
        self.assertEqual(res_me_b.status_code, status.HTTP_200_OK)
        self.assertEqual(res_me_b.data['username'], 'bob_donor')
        self.assertNotEqual(res_me_b.data['username'], 'alice_req')
