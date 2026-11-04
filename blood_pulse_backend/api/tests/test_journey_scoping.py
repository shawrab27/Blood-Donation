# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit and integration tests for journey scoping in api/views_bloodhub.py:
- journey_detail_view
- journey_list_view

Covers:
1. Requester can open journey.
2. Accepted donor can open same journey.
3. Unrelated authenticated user gets 403 or 404.
4. Non-matching request_id gets 404.
5. Unauthenticated call gets 401.
6. Phone numbers are masked before accept and visible to both sides after accept.
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


class JourneyScopingTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='requester_user',
            password='password123',
            email='requester@example.com',
            first_name='Requester',
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111111',
            is_profile_complete=True,
            is_available=False,
        )

        # Accepted Donor
        self.donor_user = User.objects.create_user(
            username='accepted_donor',
            password='password123',
            email='donor@example.com',
            first_name='AcceptedDonor',
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_profile_complete=True,
            is_available=True,
            latitude=23.8103,
            longitude=90.4125,
        )

        # Unrelated Authenticated User
        self.unrelated_user = User.objects.create_user(
            username='unrelated_user',
            password='password123',
            email='unrelated@example.com',
            first_name='Unrelated',
        )
        self.unrelated_profile = DonorProfile.objects.create(
            user=self.unrelated_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801933333333',
            is_profile_complete=True,
            is_available=True,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

        # Active Blood Request
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Rahim',
            blood_group='A+',
            component='WHOLE',
            units_needed=1,
            hospital=self.hospital,
            ward_bed='Ward 2, Bed 10',
            contact_phone='+8801811111111',
            lat=23.7259,
            lng=90.3976,
            status='ACTIVE',
        )

        # Request Acceptance (Journey)
        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            support_status='CAN_SUPPORT',
            units_pledged=1,
        )

    def test_1_requester_can_open_journey(self):
        """1. The requester of a BloodRequest can open the journey for that request."""
        self.client.force_authenticate(user=self.requester_user)

        # Open by acceptance ID (journey ID)
        resp_by_acc_id = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_by_acc_id.status_code, status.HTTP_418_IM_A_TEAPOT)
        data_acc = resp_by_acc_id.json()
        self.assertEqual(data_acc['id'], self.acceptance.id)
        self.assertEqual(data_acc['request_id'], self.blood_req.id)
        self.assertEqual(data_acc['viewer_role'], 'REQUESTER')
        self.assertEqual(data_acc['blood_group'], 'A+')
        self.assertEqual(data_acc['hospital_name'], 'Dhaka Medical College Hospital')

        # Open by request ID
        resp_by_req_id = self.client.get(f'/api/journeys/{self.blood_req.id}/')
        self.assertEqual(resp_by_req_id.status_code, status.HTTP_200_OK)
        data_req = resp_by_req_id.json()
        self.assertEqual(data_req['id'], self.acceptance.id)
        self.assertEqual(data_req['request_id'], self.blood_req.id)
        self.assertEqual(data_req['viewer_role'], 'REQUESTER')

        # List filter by request_id includes this journey
        list_resp = self.client.get(f'/api/journeys/?request_id={self.blood_req.id}')
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        results = list_resp.json()['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['id'], self.acceptance.id)
        self.assertEqual(results[0]['request_id'], self.blood_req.id)

    def test_2_accepted_donor_can_open_same_journey(self):
        """2. The accepted donor can open the same journey."""
        self.client.force_authenticate(user=self.donor_user)

        # Open by acceptance ID (journey ID)
        resp_by_acc_id = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_by_acc_id.status_code, status.HTTP_200_OK)
        data_acc = resp_by_acc_id.json()
        self.assertEqual(data_acc['id'], self.acceptance.id)
        self.assertEqual(data_acc['request_id'], self.blood_req.id)
        self.assertEqual(data_acc['viewer_role'], 'DONOR')
        self.assertEqual(data_acc['blood_group'], 'A+')
        self.assertEqual(data_acc['hospital_name'], 'Dhaka Medical College Hospital')

        # Open by request ID
        resp_by_req_id = self.client.get(f'/api/journeys/{self.blood_req.id}/')
        self.assertEqual(resp_by_req_id.status_code, status.HTTP_200_OK)
        data_req = resp_by_req_id.json()
        self.assertEqual(data_req['id'], self.acceptance.id)
        self.assertEqual(data_req['request_id'], self.blood_req.id)
        self.assertEqual(data_req['viewer_role'], 'DONOR')

        # List filter by request_id includes this journey
        list_resp = self.client.get(f'/api/journeys/?request_id={self.blood_req.id}')
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        results = list_resp.json()['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['id'], self.acceptance.id)
        self.assertEqual(results[0]['viewer_role'], 'DONOR')

    def test_3_unrelated_authenticated_user_gets_403_or_404(self):
        """3. An unrelated authenticated user gets 403 or 404."""
        self.client.force_authenticate(user=self.unrelated_user)

        # Accessing by acceptance ID
        resp_acc = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertIn(resp_acc.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

        # Accessing by request ID
        resp_req = self.client.get(f'/api/journeys/{self.blood_req.id}/')
        self.assertIn(resp_req.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

        # List query with request_id returns no results for unrelated user
        list_resp = self.client.get(f'/api/journeys/?request_id={self.blood_req.id}')
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_resp.json()['results']), 0)

    def test_4_non_matching_request_id_gets_404(self):
        """4. A request_id that does not match the journey gets 404."""
        self.client.force_authenticate(user=self.requester_user)

        # Completely nonexistent ID
        non_existent_id = 999999
        resp_non_existent = self.client.get(f'/api/journeys/{non_existent_id}/')
        self.assertEqual(resp_non_existent.status_code, status.HTTP_404_NOT_FOUND)

        # Another user's unaccepted request
        other_user = User.objects.create_user(username='other_user', password='p', first_name='Other')
        other_req = BloodRequest.objects.create(
            requester=other_user,
            patient_name='Other Patient',
            blood_group='B+',
            hospital=self.hospital,
            contact_phone='+8801700000099',
            status='ACTIVE',
        )
        resp_other = self.client.get(f'/api/journeys/{other_req.id}/')
        self.assertEqual(resp_other.status_code, status.HTTP_404_NOT_FOUND)

    def test_5_unauthenticated_call_gets_401(self):
        """5. An unauthenticated call gets 401."""
        # Ensure client is logged out
        self.client.logout()

        # Detail endpoint
        resp_detail = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_detail.status_code, status.HTTP_401_UNAUTHORIZED)

        # List endpoint
        resp_list = self.client.get('/api/journeys/')
        self.assertEqual(resp_list.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_6_phone_numbers_masked_before_accept_and_visible_to_both_after_accept(self):
        """6. Phone numbers are masked before accept and visible to both sides after accept."""
        # Part A: Before accept, prospective donor views request details
        unaccepted_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Karim',
            blood_group='A+',
            hospital=self.hospital,
            ward_bed='Bed 5',
            contact_phone='+8801811111111',
            status='ACTIVE',
        )

        self.client.force_authenticate(user=self.donor_user)
        resp_before = self.client.get(f'/api/emergency/requests/{unaccepted_req.id}/')
        self.assertEqual(resp_before.status_code, status.HTTP_200_OK)
        masked_contact = resp_before.json().get('contact_phone_display', '')
        self.assertFalse(any(c.isdigit() for c in masked_contact))
        self.assertEqual(masked_contact, 'Hidden until accepted')
        self.assertNotEqual(masked_contact, '+8801811111111')

        # Part B: After accept, both sides see unmasked contacts in journey_detail_view
        # Requester view
        self.client.force_authenticate(user=self.requester_user)
        resp_requester = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_requester.status_code, status.HTTP_200_OK)
        data_req = resp_requester.json()
        self.assertEqual(data_req['requester_contact'], '+8801811111111')
        self.assertEqual(data_req['donor_contact'], '+8801722222222')

        # Accepted donor view
        self.client.force_authenticate(user=self.donor_user)
        resp_donor = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_donor.status_code, status.HTTP_200_OK)
        data_donor = resp_donor.json()
        self.assertEqual(data_donor['requester_contact'], '+8801811111111')
        self.assertEqual(data_donor['donor_contact'], '+8801722222222')

        # Part C: If journey is CANCELLED/FAILED, contacts are masked
        self.acceptance.status = 'CANCELLED'
        self.acceptance.save(update_fields=['status'])

        resp_cancelled = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_cancelled.status_code, status.HTTP_200_OK)
        data_cancelled = resp_cancelled.json()
        self.assertIn('\u2022', data_cancelled['requester_contact'])
        self.assertIn('\u2022', data_cancelled['donor_contact'])
