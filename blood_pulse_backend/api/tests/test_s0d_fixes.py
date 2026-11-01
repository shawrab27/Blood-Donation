# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Unit tests for s0d fixes:
1. Contact reveal: every status tested for both donor and requester views (non-standby reveals on ACCEPTED..CONFIRMED, standby shields).
2. Live location field: writes to donor_lat/donor_lng, readable on ACCEPTED/ON_THE_WAY/ARRIVED, null on DONATED.
3. Collision: user A owns request 29 (no acceptance), user B has acceptance 29. User A gets 200 request-only, unrelated user C gets 404 (never 403).
4. Multiple donors: by-request returns newest non-standby acceptance + acceptances list.
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


class S0dFixesTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='s0d_req_user',
            password='password123',
            email='s0d_req@example.com',
            first_name='Requester',
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801811111101',
            is_profile_complete=True,
        )

        # Donor
        self.donor_user = User.objects.create_user(
            username='s0d_donor_user',
            password='password123',
            email='s0d_donor@example.com',
            first_name='Donor',
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801722222202',
            is_profile_complete=True,
        )

        # Unrelated User C
        self.user_c = User.objects.create_user(
            username='s0d_user_c',
            password='password123',
            email='s0d_c@example.com',
            first_name='UserC',
        )
        self.profile_c = DonorProfile.objects.create(
            user=self.user_c,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801933333303',
            is_profile_complete=True,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

    def test_1_contact_reveal_all_statuses_donor_and_requester(self):
        """
        Defect 1: Contact reveal.
        For non-standby acceptance with status in
        (ACCEPTED, ON_THE_WAY, ARRIVED, DONATED, COMPLETED, CONFIRMED),
        BOTH sides see real phones.
        Before that (e.g. CANCELLED, FAILED) it is masked.
        Standby acceptance (is_standby=True) reveals nothing to either side.
        """
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Contact Reveal',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc = RequestAcceptance.objects.create(
            request=req,
            donor=self.donor_profile,
            status='ACCEPTED',
            is_standby=False,
        )

        revealed_statuses = ['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED', 'COMPLETED', 'CONFIRMED']
        masked_statuses = ['FAILED', 'CANCELLED']

        # Test non-standby revealed statuses
        for st in revealed_statuses:
            acc.status = st
            acc.is_standby = False
            acc.save(update_fields=['status', 'is_standby'])

            # Requester view
            self.client.force_authenticate(user=self.requester_user)
            resp = self.client.get(f'/api/journeys/{acc.id}/')
            self.assertEqual(resp.status_code, status.HTTP_200_OK, f"Failed on requester view for {st}")
            data = resp.json()
            self.assertEqual(data['requester_contact'], '+8801811111101', f"Requester contact not revealed in {st}")
            self.assertEqual(data['donor_contact'], '+8801722222202', f"Donor contact not revealed to requester in {st}")

            # Donor view
            self.client.force_authenticate(user=self.donor_user)
            resp = self.client.get(f'/api/journeys/{acc.id}/')
            self.assertEqual(resp.status_code, status.HTTP_200_OK, f"Failed on donor view for {st}")
            data = resp.json()
            self.assertEqual(data['requester_contact'], '+8801811111101', f"Requester contact not revealed to donor in {st}")
            self.assertEqual(data['donor_contact'], '+8801722222202', f"Donor contact not revealed in {st}")

        # Test non-standby masked statuses
        for st in masked_statuses:
            acc.status = st
            acc.is_standby = False
            acc.save(update_fields=['status', 'is_standby'])

            for u in [self.requester_user, self.donor_user]:
                self.client.force_authenticate(user=u)
                resp = self.client.get(f'/api/journeys/{acc.id}/')
                self.assertEqual(resp.status_code, status.HTTP_200_OK)
                data = resp.json()
                self.assertIn('\u2022', data['requester_contact'], f"Requester contact unmasked in {st} for {u.username}")
                self.assertIn('\u2022', data['donor_contact'], f"Donor contact unmasked in {st} for {u.username}")

        # Test standby acceptance shields contacts for ALL statuses
        acc.is_standby = True
        for st in revealed_statuses + masked_statuses:
            acc.status = st
            acc.save(update_fields=['status', 'is_standby'])

            for u in [self.requester_user, self.donor_user]:
                self.client.force_authenticate(user=u)
                resp = self.client.get(f'/api/journeys/{acc.id}/')
                self.assertEqual(resp.status_code, status.HTTP_200_OK)
                data = resp.json()
                self.assertIn('\u2022', data['requester_contact'], f"Standby exposed requester contact in {st} for {u.username}")
                self.assertIn('\u2022', data['donor_contact'], f"Standby exposed donor contact in {st} for {u.username}")

    def test_2_live_location_donor_lat_written_and_read(self):
        """
        Defect 2: Live location field.
        Donor updates location (writes donor_lat/donor_lng).
        Requester reads donor_lat/donor_lng while ACCEPTED, ON_THE_WAY, ARRIVED.
        Gets null after DONATED.
        """
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Live GPS',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='ACTIVE',
        )
        acc = RequestAcceptance.objects.create(
            request=req,
            donor=self.donor_profile,
            status='ACCEPTED',
            is_standby=False,
        )

        # Donor posts location
        self.client.force_authenticate(user=self.donor_user)
        post_resp = self.client.post(
            f'/api/journeys/{acc.id}/location/',
            {'lat': 23.8103, 'lng': 90.4125},
            format='json',
            HTTP_X_BYPASS_THROTTLE='1',
        )
        self.assertEqual(post_resp.status_code, status.HTTP_200_OK)
        acc.refresh_from_db()
        self.assertEqual(acc.donor_lat, 23.8103)
        self.assertEqual(acc.donor_lng, 90.4125)

        # Requester reads on ACCEPTED, ON_THE_WAY, ARRIVED -> gets coordinates
        self.client.force_authenticate(user=self.requester_user)
        for st in ['ACCEPTED', 'ON_THE_WAY', 'ARRIVED']:
            acc.status = st
            acc.save(update_fields=['status'])
            get_resp = self.client.get(f'/api/journeys/{acc.id}/')
            self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
            d = get_resp.json()
            self.assertEqual(d['donor_lat'], 23.8103)
            self.assertEqual(d['donor_lng'], 90.4125)

        # Transition to DONATED -> donor_lat and donor_lng must be null
        acc.status = 'DONATED'
        acc.save(update_fields=['status'])
        get_resp = self.client.get(f'/api/journeys/{acc.id}/')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        d = get_resp.json()
        self.assertIsNone(d['donor_lat'])
        self.assertIsNone(d['donor_lng'])

    def test_3_collision_request_only_view_and_404_for_unrelated(self):
        """
        Defect 3: Collision test.
        User A owns request 29 with no acceptance.
        User B's acceptance id is 29 (on a completely different request).
        User A gets 200 request-only view (viewer_role REQUESTER, request_only true).
        Unrelated User C gets 404 (never 403, no ID confirmation).
        """
        # User B (different requester and donor)
        other_requester = User.objects.create_user(username='other_req_b', password='p', email='b@ex.com')
        other_donor = User.objects.create_user(username='other_donor_b', password='p', email='db@ex.com')
        other_dp = DonorProfile.objects.create(user=other_donor, blood_group='A+', phone_number='+8801999999999')
        other_req = BloodRequest.objects.create(
            requester=other_requester,
            patient_name='Patient Other B',
            blood_group='A+',
            hospital=self.hospital,
            status='ACTIVE',
        )

        # Create acceptance with explicit pk=29
        acc_29 = RequestAcceptance.objects.create(
            id=29,
            request=other_req,
            donor=other_dp,
            status='ACCEPTED',
            is_standby=False,
        )
        self.assertEqual(acc_29.id, 29)

        # User A owns BloodRequest with pk=29 (no acceptance)
        req_29 = BloodRequest.objects.create(
            id=29,
            requester=self.requester_user,
            patient_name='User A Request 29',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            status='OPEN',
        )
        self.assertEqual(req_29.id, 29)

        # User A requests /api/journeys/29/ -> 200 request-only view
        self.client.force_authenticate(user=self.requester_user)
        resp_a = self.client.get('/api/journeys/29/')
        self.assertEqual(resp_a.status_code, status.HTTP_200_OK)
        data_a = resp_a.json()
        self.assertEqual(data_a['id'], 29)
        self.assertEqual(data_a['request_id'], 29)
        self.assertEqual(data_a['viewer_role'], 'REQUESTER')
        self.assertTrue(data_a['request_only'])

        # User C (unrelated to both) requests /api/journeys/29/ -> 404 NOT FOUND (never 403)
        self.client.force_authenticate(user=self.user_c)
        resp_c = self.client.get('/api/journeys/29/')
        self.assertEqual(resp_c.status_code, status.HTTP_404_NOT_FOUND)

    def test_4_by_request_returns_newest_non_standby_and_acceptances_list(self):
        """
        Defect 4: Multiple donors on a request.
        GET /api/journeys/by-request/<request_id>/ returns newest non-standby acceptance
        and includes acceptances list. Unrelated user gets 404.
        """
        multi_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Multi Donors',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111101',
            units_needed=2,
            status='ACTIVE',
        )

        # Donor 1 (standby)
        u_d1 = User.objects.create_user(username='d1', password='p', email='d1@ex.com')
        dp1 = DonorProfile.objects.create(user=u_d1, blood_group='O+', phone_number='+8801700000001')
        acc_standby = RequestAcceptance.objects.create(
            request=multi_req,
            donor=dp1,
            status='ACCEPTED',
            is_standby=True,
        )

        # Donor 2 (active, older)
        u_d2 = User.objects.create_user(username='d2', password='p', email='d2@ex.com')
        dp2 = DonorProfile.objects.create(user=u_d2, blood_group='O+', phone_number='+8801700000002')
        acc_active_old = RequestAcceptance.objects.create(
            request=multi_req,
            donor=dp2,
            status='ACCEPTED',
            is_standby=False,
        )

        # Donor 3 (active, newer)
        u_d3 = User.objects.create_user(username='d3', password='p', email='d3@ex.com')
        dp3 = DonorProfile.objects.create(user=u_d3, blood_group='O+', phone_number='+8801700000003')
        acc_active_new = RequestAcceptance.objects.create(
            request=multi_req,
            donor=dp3,
            status='ON_THE_WAY',
            is_standby=False,
        )

        # Requester calls by-request
        self.client.force_authenticate(user=self.requester_user)
        resp = self.client.get(f'/api/journeys/by-request/{multi_req.id}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()

        # Primary acceptance returned must be the newest non-standby (Donor 3)
        self.assertEqual(data['id'], acc_active_new.id)
        self.assertEqual(data['status'], 'ON_THE_WAY')
        self.assertFalse(data['is_standby'])

        # Must include all acceptances in acceptances list
        self.assertIn('acceptances', data)
        acc_ids = [a['id'] for a in data['acceptances']]
        self.assertIn(acc_standby.id, acc_ids)
        self.assertIn(acc_active_old.id, acc_ids)
        self.assertIn(acc_active_new.id, acc_ids)

        # Unrelated User C gets 404
        self.client.force_authenticate(user=self.user_c)
        resp_c = self.client.get(f'/api/journeys/by-request/{multi_req.id}/')
        self.assertEqual(resp_c.status_code, status.HTTP_404_NOT_FOUND)
