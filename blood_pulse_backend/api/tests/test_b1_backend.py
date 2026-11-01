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


class B1Item2PaginationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.requester_user = User.objects.create_user(
            username='b1_pag_req', password='password123', email='pag_req@example.com'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811111102',
            is_profile_complete=True,
            email_verified=True,
        )

        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

    def test_2_pagination_25_items_limit_20_no_duplicate_requests(self):
        """
        Item 2 Test:
        22 RequestAcceptances for requester, and 3 open BloodRequests without acceptance (Total = 25 items).
        Page 1 (offset=0, limit=20): count=25, contains request_only items.
        Page 2 (offset=20, limit=20): count=25, contains remaining 2 acceptances, NEVER duplicates request_only items.
        """
        # Create 22 acceptances across 22 requests
        for i in range(22):
            req = BloodRequest.objects.create(
                requester=self.requester_user,
                patient_name=f'Patient Acc {i}',
                blood_group='A+',
                hospital=self.hospital,
                status='ACTIVE',
            )
            donor_u = User.objects.create_user(username=f'donor_pag_{i}', password='p', email=f'd{i}@ex.com')
            dp = DonorProfile.objects.create(user=donor_u, blood_group='A+', phone_number=f'+880170000{i:04d}')
            RequestAcceptance.objects.create(
                request=req,
                donor=dp,
                status='ACCEPTED',
                is_standby=False,
            )

        # Create 3 open requests without acceptance
        open_ids = []
        for j in range(3):
            open_req = BloodRequest.objects.create(
                requester=self.requester_user,
                patient_name=f'Patient Open {j}',
                blood_group='A+',
                hospital=self.hospital,
                status='OPEN',
            )
            open_ids.append(open_req.id)

        self.client.force_authenticate(user=self.requester_user)

        # Page 1: limit 20, offset 0
        resp1 = self.client.get('/api/journeys/?limit=20&offset=0')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        data1 = resp1.json()
        self.assertEqual(data1['count'], 25)
        self.assertEqual(data1['next_offset'], 20)

        # Confirm request_only items are present on first page
        p1_ids = [item['id'] for item in data1['results'] if item['request_only']]
        for oid in open_ids:
            self.assertIn(oid, p1_ids)

        # Page 2: limit 20, offset 20
        resp2 = self.client.get('/api/journeys/?limit=20&offset=20')
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)
        data2 = resp2.json()
        self.assertEqual(data2['count'], 25)
        self.assertIsNone(data2['next_offset'])  # 20 + 20 >= 25

        # Confirm request_only items are NEVER appended again on page 2
        p2_request_only = [item for item in data2['results'] if item['request_only']]
        self.assertEqual(len(p2_request_only), 0)


class B1Item3CorsTests(TestCase):
    def test_3_cors_origins_and_regexes_no_wildcards(self):
        """
        Item 3 Test:
        CORS_ALLOWED_ORIGIN_REGEXES must not contain wildcards for vercel.app, web.app, pages.dev, netlify.app.
        CORS_ALLOWED_ORIGINS and CSRF_TRUSTED_ORIGINS must contain explicit Firebase Hosting domains.
        """
        from django.conf import settings

        regexes = getattr(settings, 'CORS_ALLOWED_ORIGIN_REGEXES', [])
        for r in regexes:
            self.assertNotIn('vercel.app', r)
            self.assertNotIn('web.app', r)
            self.assertNotIn('pages.dev', r)
            self.assertNotIn('netlify.app', r)

        cors_origins = getattr(settings, 'CORS_ALLOWED_ORIGINS', [])
        self.assertIn('https://bloodpulse-283dc.web.app', cors_origins)
        self.assertIn('https://bloodpulse-283dc.firebaseapp.com', cors_origins)

        csrf_origins = getattr(settings, 'CSRF_TRUSTED_ORIGINS', [])
        self.assertIn('https://bloodpulse-283dc.web.app', csrf_origins)
        self.assertIn('https://bloodpulse-283dc.firebaseapp.com', csrf_origins)


class B1Item4MediaServeTests(TestCase):
    def test_4_media_file_serve_path_traversal_blocked(self):
        """
        Item 4 Test:
        MediaFileServeView blocks path traversal attempts with 404.
        """
        resp1 = self.client.get('/api/media/files/..%2F..%2Fsettings.py/')
        self.assertEqual(resp1.status_code, status.HTTP_404_NOT_FOUND)

        resp2 = self.client.get('/api/media/files/....//etc//passwd/')
        self.assertEqual(resp2.status_code, status.HTTP_404_NOT_FOUND)


class B1Item5DeleteRemovalTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_5_blood_request_detail_v2_has_no_delete(self):
        """
        Item 5 Test:
        DELETE /api/requests/<pk>/ returns 405 Method Not Allowed since delete is removed.
        """
        user = User.objects.create_user(
            username='req_del_user',
            password='p',
            email='del@ex.com',
            first_name='Del User',
        )
        DonorProfile.objects.create(
            user=user,
            blood_group='A+',
            phone_number='+8801899999901',
            district='Dhaka',
            is_profile_complete=True,
            email_verified=True,
        )
        h = Hospital.objects.create(name='Del Hospital', district='Dhaka')
        req = BloodRequest.objects.create(requester=user, patient_name='P', blood_group='A+', hospital=h)

        self.client.force_authenticate(user=user)
        resp = self.client.delete(f'/api/requests/{req.id}/')
        self.assertEqual(resp.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)
