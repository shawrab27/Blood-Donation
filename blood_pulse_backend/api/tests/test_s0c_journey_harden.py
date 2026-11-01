# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit and integration tests for s0c journey hardening (api/views_bloodhub.py):
1. ID Ambiguity & Collision case (acceptance ID equals another request's ID for same user).
2. journey_list_view with ?request_id= never appends other requests, and carries request_only: true.
3. donor_lat/donor_lng returned only while status is ACCEPTED, ON_THE_WAY, ARRIVED; null after.
4. is_standby acceptances shield requester contact until promoted to active.
5. Requester with multiple accepted donors sees all of them in acceptances list.
6. Invalid, non-integer, or negative limit/offset returns safe defaults, never 500.
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


class S0cJourneyHardeningTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # User A
        self.user_a = User.objects.create_user(
            username='user_a', password='password123', email='user_a@example.com', first_name='UserA'
        )
        self.profile_a = DonorProfile.objects.create(
            user=self.user_a,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111101',
            is_profile_complete=True,
            is_available=True,
        )

        # User B
        self.user_b = User.objects.create_user(
            username='user_b', password='password123', email='user_b@example.com', first_name='UserB'
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.user_b,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111102',
            is_profile_complete=True,
            is_available=True,
        )

        # User C
        self.user_c = User.objects.create_user(
            username='user_c', password='password123', email='user_c@example.com', first_name='UserC'
        )
        self.profile_c = DonorProfile.objects.create(
            user=self.user_c,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111103',
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

    def test_1_id_ambiguity_and_collision_case(self):
        """
        1. Collision case:
        One user is participant in:
        - RequestAcceptance with ID X (as donor)
        - BloodRequest with ID X (as requester), which is accepted by another donor in Acceptance Y.
        Calling /api/journeys/X/ opens Acceptance X (donor view).
        Calling /api/journeys/by-request/X/ opens Acceptance Y (requester view for request X).
        """
        # Create BloodRequest 1 (requested by User B, accepted by User A as donor)
        req_for_b = BloodRequest.objects.create(
            requester=self.user_b,
            patient_name='Patient B',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111102',
            status='ACTIVE',
        )
        acc_a_is_donor = RequestAcceptance.objects.create(
            request=req_for_b,
            donor=self.profile_a,
            status='ACCEPTED',
            support_status='CAN_SUPPORT',
            units_pledged=1,
        )

        # Create BloodRequest 2 (requested by User A, accepted by User C as donor)
        req_for_a = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient A',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc_c_is_donor = RequestAcceptance.objects.create(
            request=req_for_a,
            donor=self.profile_c,
            status='ACCEPTED',
            support_status='CAN_SUPPORT',
            units_pledged=1,
        )

        # Force numeric collision in test database:
        # We simulate the exact scenario where acc_a_is_donor.id == req_for_a.id
        collision_id = 4500
        RequestAcceptance.objects.filter(pk=acc_a_is_donor.pk).update(id=collision_id)
        BloodRequest.objects.filter(pk=req_for_a.pk).update(id=collision_id)
        # Update references
        acc_c_is_donor.request_id = collision_id
        acc_c_is_donor.save(update_fields=['request_id'])

        # User A calls /api/journeys/<collision_id>/
        # Must resolve to RequestAcceptance 4500 (User A as DONOR)
        self.client.force_authenticate(user=self.user_a)
        resp_detail = self.client.get(f'/api/journeys/{collision_id}/')
        self.assertEqual(resp_detail.status_code, status.HTTP_200_OK)
        data_detail = resp_detail.json()
        self.assertEqual(data_detail['id'], collision_id)
        self.assertEqual(data_detail['viewer_role'], 'DONOR')
        self.assertEqual(data_detail['patient_name'], 'Patient B')

        # User A calls /api/journeys/by-request/<collision_id>/
        # Must resolve to BloodRequest 4500 (User A as REQUESTER, acceptance = acc_c_is_donor)
        resp_by_req = self.client.get(f'/api/journeys/by-request/{collision_id}/')
        self.assertEqual(resp_by_req.status_code, status.HTTP_200_OK)
        data_by_req = resp_by_req.json()
        self.assertEqual(data_by_req['id'], acc_c_is_donor.id)
        self.assertEqual(data_by_req['request_id'], collision_id)
        self.assertEqual(data_by_req['viewer_role'], 'REQUESTER')
        self.assertEqual(data_by_req['patient_name'], 'Patient A')

    def test_2_journey_list_with_request_id_never_appends_other_requests(self):
        """
        2. journey_list_view: with ?request_id= never append user's other open requests.
        Items carry request_only: true if they have no acceptance.
        """
        self.client.force_authenticate(user=self.user_a)

        # Request 1: has an acceptance
        req1 = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient 1',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc1 = RequestAcceptance.objects.create(
            request=req1,
            donor=self.profile_b,
            status='ACCEPTED',
        )

        # Request 2: open, no acceptance
        req2 = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient 2',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )

        # Filter by req1.id -> must contain ONLY acc1, never req2
        resp1 = self.client.get(f'/api/journeys/?request_id={req1.id}')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        results1 = resp1.json()['results']
        self.assertEqual(len(results1), 1)
        self.assertEqual(results1[0]['id'], acc1.id)
        self.assertEqual(results1[0]['request_id'], req1.id)
        self.assertFalse(results1[0]['request_only'])

        # Filter by req2.id -> must contain ONLY req2 with request_only: true
        resp2 = self.client.get(f'/api/journeys/?request_id={req2.id}')
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)
        results2 = resp2.json()['results']
        self.assertEqual(len(results2), 1)
        self.assertEqual(results2[0]['id'], req2.id)
        self.assertEqual(results2[0]['request_id'], req2.id)
        self.assertTrue(results2[0]['request_only'])

    def test_3_return_donor_lat_lng_only_while_active_null_after(self):
        """
        3. Return donor_lat/donor_lng only while status is ACCEPTED, ON_THE_WAY, ARRIVED;
        null after DONATED, COMPLETED, CONFIRMED, or CANCELLED.
        """
        self.client.force_authenticate(user=self.user_a)
        req = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient LatLng',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc = RequestAcceptance.objects.create(
            request=req,
            donor=self.profile_b,
            status='ACCEPTED',
            donor_lat=23.8103,
            donor_lng=90.4125,
        )

        # Status: ACCEPTED -> coordinates visible
        resp = self.client.get(f'/api/journeys/{acc.id}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.json()['donor_lat'], 23.8103)
        self.assertEqual(resp.json()['donor_lng'], 90.4125)

        # Status: DONATED -> coordinates null
        acc.status = 'DONATED'
        acc.save(update_fields=['status'])
        resp_donated = self.client.get(f'/api/journeys/{acc.id}/')
        self.assertEqual(resp_donated.status_code, status.HTTP_200_OK)
        self.assertIsNone(resp_donated.json()['donor_lat'])
        self.assertIsNone(resp_donated.json()['donor_lng'])

        # Status: CANCELLED -> coordinates null
        acc.status = 'CANCELLED'
        acc.save(update_fields=['status'])
        resp_cancelled = self.client.get(f'/api/journeys/{acc.id}/')
        self.assertEqual(resp_cancelled.status_code, status.HTTP_200_OK)
        self.assertIsNone(resp_cancelled.json()['donor_lat'])
        self.assertIsNone(resp_cancelled.json()['donor_lng'])

    def test_4_standby_acceptance_shields_requester_contact_until_promoted(self):
        """
        4. is_standby acceptances must not reveal requester contact until promoted to active.
        """
        self.client.force_authenticate(user=self.user_b)
        req = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient Standby Shield',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc_standby = RequestAcceptance.objects.create(
            request=req,
            donor=self.profile_b,
            status='ACCEPTED',
            is_standby=True,
        )

        # While standby -> contact masked
        resp_standby = self.client.get(f'/api/journeys/{acc_standby.id}/')
        self.assertEqual(resp_standby.status_code, status.HTTP_200_OK)
        contact_standby = resp_standby.json()['requester_contact']
        self.assertIn('\u2022', contact_standby)
        self.assertNotEqual(contact_standby, '+8801811111101')

        # When promoted (is_standby=False) -> contact revealed
        acc_standby.is_standby = False
        acc_standby.save(update_fields=['is_standby'])
        resp_promoted = self.client.get(f'/api/journeys/{acc_standby.id}/')
        self.assertEqual(resp_promoted.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_promoted.json()['requester_contact'], '+8801811111101')

    def test_5_requester_sees_all_accepted_donors_in_acceptances_list(self):
        """
        5. A requester with several accepted donors must see all of them in acceptances list.
        """
        self.client.force_authenticate(user=self.user_a)
        req = BloodRequest.objects.create(
            requester=self.user_a,
            patient_name='Patient Multi Donor',
            blood_group='A+',
            units_needed=2,
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc1 = RequestAcceptance.objects.create(
            request=req,
            donor=self.profile_b,
            status='ACCEPTED',
            units_pledged=1,
        )
        acc2 = RequestAcceptance.objects.create(
            request=req,
            donor=self.profile_c,
            status='ON_THE_WAY',
            units_pledged=1,
        )

        resp = self.client.get(f'/api/journeys/{acc1.id}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertIn('acceptances', data)
        acc_list = data['acceptances']
        self.assertEqual(len(acc_list), 2)
        acc_ids = {a['id'] for a in acc_list}
        self.assertEqual(acc_ids, {acc1.id, acc2.id})

    def test_6_invalid_limit_and_offset_returns_safe_defaults_never_500(self):
        """
        6. Invalid, non-integer or negative limit/offset returns safe defaults, never 500.
        """
        self.client.force_authenticate(user=self.user_a)

        # Non-integer parameters
        resp_invalid = self.client.get('/api/journeys/?limit=invalid&offset=notanumber')
        self.assertEqual(resp_invalid.status_code, status.HTTP_200_OK)
        self.assertIn('results', resp_invalid.json())

        # Negative parameters
        resp_negative = self.client.get('/api/journeys/?limit=-10&offset=-5')
        self.assertEqual(resp_negative.status_code, status.HTTP_200_OK)
        self.assertIn('results', resp_negative.json())
