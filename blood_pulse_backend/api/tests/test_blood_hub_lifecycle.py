# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Integration tests for Blood Hub v2 request lifecycle, state machine,
OTP verification, targeting reach, atomic acceptance, and match reporting.
"""

from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    DonationMatch,
    EmailOTP,
    CompatibilityRule,
)
from api.services.blood_hub_lifecycle_service import (
    transition,
    IllegalStateTransitionError,
)
from api.services.email import hash_otp


class BloodHubLifecycleTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='requester_user', password='password123', email='requester@example.com', first_name='Requester'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711111111',
            is_profile_complete=True,
            is_available=False,
        )

        # Donor 1 (Compatible A+)
        self.donor_user1 = User.objects.create_user(
            username='donor_user1', password='password123', email='donor1@example.com', first_name='DonorOne'
        )
        self.donor_profile1 = DonorProfile.objects.create(
            user=self.donor_user1,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_available=True,
            is_profile_complete=True,
            latitude=23.8103,
            longitude=90.4125,
        )

        # Donor 2 (Compatible O+)
        self.donor_user2 = User.objects.create_user(
            username='donor_user2', password='password123', email='donor2@example.com', first_name='DonorTwo'
        )
        self.donor_profile2 = DonorProfile.objects.create(
            user=self.donor_user2,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733333333',
            is_available=True,
            is_profile_complete=True,
            latitude=23.8120,
            longitude=90.4130,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
        )

        # Compatibility rules
        CompatibilityRule.objects.create(blood_group='A+', can_give_to='A+, AB+', can_receive_from='A+, A-, O+, O-')

    def test_state_machine_valid_transitions(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='A+',
            hospital=self.hospital,
            status='DRAFT',
        )
        req = transition(req, 'PENDING_EMAIL_OTP', self.requester_user)
        self.assertEqual(req.status, 'PENDING_EMAIL_OTP')
        req = transition(req, 'OPEN', self.requester_user)
        self.assertEqual(req.status, 'OPEN')
        req = transition(req, 'MATCHED', self.donor_user1)
        self.assertEqual(req.status, 'MATCHED')
        req = transition(req, 'IN_TRANSIT', self.donor_user1)
        self.assertEqual(req.status, 'IN_TRANSIT')
        req = transition(req, 'ARRIVED', self.donor_user1)
        self.assertEqual(req.status, 'ARRIVED')
        req = transition(req, 'DONATED', self.requester_user)
        self.assertEqual(req.status, 'DONATED')
        req = transition(req, 'CLOSED', self.requester_user)
        self.assertEqual(req.status, 'CLOSED')

    def test_state_machine_illegal_transition_raises_409(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='A+',
            hospital=self.hospital,
            status='DRAFT',
        )
        with self.assertRaises(IllegalStateTransitionError):
            transition(req, 'DONATED', self.requester_user)

    def test_request_create_flow(self):
        from api.tests.helpers import obtain_submit_token_via_flow
        token = obtain_submit_token_via_flow(self.client, self.requester_user)
        self.client.force_authenticate(user=self.requester_user)
        res = self.client.post('/api/requests/', {
            'blood_group': 'A+',
            'units_needed': 1,
            'hospital': self.hospital.id,
            'urgency': 'CRITICAL_2H',
            'contact_phone': '+8801711111111',
            'patient_name': 'Rahim Uddin',
            'submit_token': token,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        req_id = res.data['id']
        self.assertEqual(res.data['status'], 'DRAFT')

    def test_targeting_reach_endpoint(self):
        self.client.force_authenticate(user=self.requester_user)
        res = self.client.get('/api/requests/reach/', {'blood_group': 'A+', 'scope': 'NATIONWIDE'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        # Should count both donor1 (A+) and donor2 (O+)
        self.assertEqual(res.data['reach'], 2)

    def test_cooldown_excludes_from_reach(self):
        self.donor_profile2.last_donation_date = timezone.now().date() - timedelta(days=20)
        self.donor_profile2.save()
        self.client.force_authenticate(user=self.requester_user)
        res = self.client.get('/api/requests/reach/', {'blood_group': 'A+', 'scope': 'NATIONWIDE'})
        # donor2 is under 90-day cooldown, so only donor1 is reachable
        self.assertEqual(res.data['reach'], 1)

    def test_atomic_accept_and_privacy_unmasking(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='A+',
            hospital=self.hospital,
            units_needed=1,
            contact_phone='+8801711111111',
            status='OPEN',
        )

        # Donor 1 accepts
        self.client.force_authenticate(user=self.donor_user1)
        res_accept = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res_accept.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_accept.data['role'], 'PRIMARY')

        # Since donor1 accepted, requester's phone is unmasked for donor1
        self.assertEqual(res_accept.data['requester_phone'], '+8801711111111')

        # Requester views match: donor's phone is unmasked for requester
        self.client.force_authenticate(user=self.requester_user)
        match_id = res_accept.data['id']
        match = DonationMatch.objects.get(id=match_id)
        from api.serializers_blood_hub_v2 import DonationMatchDetailSerializer
        serializer_data = DonationMatchDetailSerializer(
            match, context={'request': type('Req', (), {'user': self.requester_user})()}
        ).data
        self.assertEqual(serializer_data['donor_phone'], '+8801722222222')

        # Second accept on 1-unit request must return 409 Conflict
        self.client.force_authenticate(user=self.donor_user2)
        res_conflict = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res_conflict.status_code, status.HTTP_409_CONFLICT)

    def test_match_status_progression_and_failure_reporting(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='A+',
            hospital=self.hospital,
            units_needed=1,
            status='OPEN',
        )
        self.client.force_authenticate(user=self.donor_user1)
        res = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        match_id = res.data['id']

        # Donor marks ON_THE_WAY
        res_otw = self.client.post(f'/api/matches/{match_id}/status/', {'status': 'ON_THE_WAY'}, format='json')
        self.assertEqual(res_otw.status_code, status.HTTP_200_OK)
        req.refresh_from_db()
        self.assertEqual(req.status, 'IN_TRANSIT')

        # Donor reports failure MEDICAL
        res_report = self.client.post(f'/api/matches/{match_id}/report/', {
            'reason': 'MEDICAL',
            'note': 'Hemoglobin below 12.5 g/dL on rapid test.',
        }, format='json')
        self.assertEqual(res_report.status_code, status.HTTP_200_OK)
        self.assertEqual(res_report.data['match_status'], 'FAILED')

        # Standby candidate (donor2) is auto-promoted
        self.assertIsNotNone(res_report.data['promoted_standby'])
        promoted = DonationMatch.objects.get(id=res_report.data['promoted_standby'])
        self.assertEqual(promoted.role, 'PRIMARY')
        self.assertEqual(promoted.donor, self.donor_profile2)
        self.assertIsNotNone(promoted.expires_at)
