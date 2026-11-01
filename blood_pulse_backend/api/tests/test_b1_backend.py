# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit tests for b1-backend tasks:
1. by-request primary pick: active > completed > standby > cancelled, newest started_at tie-break.
   Test: donor A cancels, standby B promoted, requester sees B.
"""

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
)


class B1Item1Tests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='b1_requester', password='password123', email='req@example.com'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801811111101',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor A
        self.donor_a_user = User.objects.create_user(
            username='donor_a', password='password123', email='a@example.com'
        )
        self.donor_a_profile = DonorProfile.objects.create(
            user=self.donor_a_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711111101',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor B (Standby promoted)
        self.donor_b_user = User.objects.create_user(
            username='donor_b', password='password123', email='b@example.com'
        )
        self.donor_b_profile = DonorProfile.objects.create(
            user=self.donor_b_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801722222202',
            is_profile_complete=True,
            email_verified=True,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

        # Blood Request
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Rahim',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )

    def test_1_donor_a_cancels_standby_b_promoted_requester_sees_b(self):
        """
        Item 1 Test:
        Donor A has acceptance, cancels (status=CANCELLED).
        Standby B is promoted (is_standby flips to False, status=ACCEPTED).
        Requester requests /api/journeys/by-request/<request_id>/ and gets B, never A's cancelled acceptance.
        """
        # Donor A's older acceptance which got cancelled
        acc_a = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_a_profile,
            status='CANCELLED',
            is_standby=False,
            cancellation_reason='Donor emergency',
        )

        # Standby B acceptance which was promoted (is_standby=False, status=ACCEPTED)
        acc_b = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_b_profile,
            status='ACCEPTED',
            is_standby=False,
        )

        self.client.force_authenticate(user=self.requester_user)
        resp = self.client.get(f'/api/journeys/by-request/{self.blood_req.id}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()

        # Primary returned journey MUST be B (active), NOT A (cancelled)
        self.assertEqual(data['id'], acc_b.id)
        self.assertEqual(data['status'], 'ACCEPTED')
        self.assertEqual(data['donor_name'], self.donor_b_user.username)
        self.assertFalse(data['is_standby'])

        # Both acceptances should be in acceptances list
        self.assertIn('acceptances', data)
        acc_ids = [a['id'] for a in data['acceptances']]
        self.assertIn(acc_b.id, acc_ids)
        self.assertIn(acc_a.id, acc_ids)
