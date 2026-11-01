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


class B1Item6PhoneMaskingTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.requester_user = User.objects.create_user(
            username='mask_req_user', password='password123', email='req_mask@example.com', first_name='Rahim'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801811111199',
            is_profile_complete=True,
            email_verified=True,
        )

        self.unrelated_user = User.objects.create_user(
            username='mask_unrel_user', password='password123', email='unrel_mask@example.com', first_name='Karim'
        )
        self.unrelated_profile = DonorProfile.objects.create(
            user=self.unrelated_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801822222299',
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

        # Request WITH exact coordinates
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Mohammad Rahim Khan',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811111199',
            contact_number='+8801811111199',
            lat=23.810321,
            lng=90.412512,
            status='ACTIVE',
        )

    def test_6_phone_masking_and_geo_fuzzing_on_all_real_urls(self):
        """
        Item 6 Test:
        Public and unrelated viewers see NO phone digits ('Hidden until accepted').
        Exact lat/lng coordinates are fuzzed.
        """
        # 1. Anonymous on /api/emergency/requests/ (BloodRequestListSerializer)
        self.client.logout()
        resp_list = self.client.get('/api/emergency/requests/')
        self.assertEqual(resp_list.status_code, status.HTTP_200_OK)
        items = resp_list.json()
        item = next((i for i in items if i['id'] == self.blood_req.id), None)
        self.assertIsNotNone(item)
        self.assertEqual(item['contact_phone_masked'], "Hidden until accepted")

        # 2. Anonymous on /api/emergency/requests/<pk>/ (emergency_request_detail_view)
        resp_anon_detail = self.client.get(f'/api/emergency/requests/{self.blood_req.id}/')
        self.assertEqual(resp_anon_detail.status_code, status.HTTP_200_OK)
        anon_data = resp_anon_detail.json()
        self.assertNotIn('contact_phone', anon_data)
        self.assertNotIn('contact_phone_display', anon_data)

        # 3. Unrelated user on /api/emergency/requests/<pk>/ (BloodRequestDetailSerializer)
        self.client.force_authenticate(user=self.unrelated_user)
        resp_unrel_detail = self.client.get(f'/api/emergency/requests/{self.blood_req.id}/')
        self.assertEqual(resp_unrel_detail.status_code, status.HTTP_200_OK)
        unrel_data = resp_unrel_detail.json()
        self.assertEqual(unrel_data['contact_phone_display'], "Hidden until accepted")
        self.assertNotEqual(unrel_data['patient_name'], 'Mohammad Rahim Khan')
        # Exact coords (23.810321, 90.412512) must be fuzzed!
        self.assertNotEqual(unrel_data['lat'], 23.810321)
        self.assertNotEqual(unrel_data['lng'], 90.412512)

        # 4. Unrelated user on /api/requests/<pk>/ (BloodRequestDetailV2APIView)
        resp_v2 = self.client.get(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(resp_v2.status_code, status.HTTP_200_OK)
        v2_data = resp_v2.json()
        self.assertEqual(v2_data['contact_phone_display'], "Hidden until accepted")
        self.assertNotEqual(v2_data['lat'], 23.810321)
        self.assertNotEqual(v2_data['lng'], 90.412512)


class B1Item7IssueReportRulesTests(TestCase):
    def setUp(self):
        from django.utils import timezone
        from datetime import timedelta
        from api.models import Hospital, DonorProfile, BloodRequest, RequestAcceptance

        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='b1_7_req', password='password123', email='req7@example.com'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811117701',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor
        self.donor_user = User.objects.create_user(
            username='b1_7_donor', password='password123', email='donor7@example.com'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711117702',
            is_profile_complete=True,
            email_verified=True,
            no_show_count=0,
        )

        # Unrelated User
        self.unrelated_user = User.objects.create_user(
            username='b1_7_unrel', password='password123', email='unrel7@example.com'
        )
        DonorProfile.objects.create(
            user=self.unrelated_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801911117703',
            is_profile_complete=True,
            email_verified=True,
        )

        self.hospital = Hospital.objects.create(
            name='Item 7 General Hospital',
            district='Dhaka',
            address='Dhanmondi, Dhaka',
        )

        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Seven',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811117701',
            status='ACTIVE',
        )

        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            eta_minutes=30,
        )

    def test_7_medical_rejection_only_by_donor_no_freetext_no_trust_penalty(self):
        from api.models import DonationIssue, RequestTimelineEvent

        # 1. Requester cannot report MEDICAL_REJECTION -> 403 Forbidden
        self.client.force_authenticate(user=self.requester_user)
        resp_req = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'MEDICAL_REJECTION',
            'reason_code': 'LOW_HEMOGLOBIN',
        })
        self.assertEqual(resp_req.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Donor reporting invalid reason code -> 400 Bad Request
        self.client.force_authenticate(user=self.donor_user)
        resp_inv = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'MEDICAL_REJECTION',
            'reason_code': 'UNKNOWN_CODE',
        })
        self.assertEqual(resp_inv.status_code, status.HTTP_400_BAD_REQUEST)

        # 3. Donor reporting valid reason code with free-text description
        resp_ok = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'MEDICAL_REJECTION',
            'reason_code': 'LOW_HEMOGLOBIN',
            'description': 'Private medical notes: patient had viral fever and low platelet count',
        })
        self.assertEqual(resp_ok.status_code, status.HTTP_201_CREATED)
        data = resp_ok.json()

        # Never store or return free-text medical values
        self.assertNotIn('Private medical notes', str(data))
        self.assertEqual(data['issue']['description'], 'LOW_HEMOGLOBIN')

        issue_obj = DonationIssue.objects.get(id=data['issue']['id'])
        self.assertEqual(issue_obj.description, 'LOW_HEMOGLOBIN')

        # Acceptance updated to FAILED with reason code only
        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'FAILED')
        self.assertIn('LOW_HEMOGLOBIN', self.acceptance.cancellation_reason)
        self.assertNotIn('Private medical notes', self.acceptance.cancellation_reason)

        # No automatic trust penalty
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.no_show_count, 0)

        # Timeline event logged for admin review
        event = RequestTimelineEvent.objects.filter(request=self.blood_req, state='ISSUE_REPORTED').last()
        self.assertIsNotNone(event)
        self.assertIn('Pending admin review', event.note)

    def test_7_no_show_only_by_requester_after_eta_and_grace(self):
        from datetime import timedelta
        from django.utils import timezone
        from api.models import RequestTimelineEvent

        # 1. Donor cannot report NO_SHOW -> 403 Forbidden
        self.client.force_authenticate(user=self.donor_user)
        resp_donor = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'DONOR_NO_SHOW',
        })
        self.assertEqual(resp_donor.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Requester cannot report NO_SHOW before ETA + grace minutes (30 + 20 = 50 min) -> 400
        self.client.force_authenticate(user=self.requester_user)
        resp_early = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'DONOR_NO_SHOW',
        })
        self.assertEqual(resp_early.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('grace period', resp_early.json().get('error', ''))

        # 3. Simulate overdue journey (started 60 minutes ago)
        RequestAcceptance.objects.filter(id=self.acceptance.id).update(
            started_at=timezone.now() - timedelta(minutes=60)
        )

        resp_ok = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'DONOR_NO_SHOW',
        })
        self.assertEqual(resp_ok.status_code, status.HTTP_201_CREATED)

        # Acceptance failed
        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'FAILED')

        # Neither triggers an automatic trust penalty
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.no_show_count, 0)

        # RequestTimelineEvent logged for admin review
        event = RequestTimelineEvent.objects.filter(request=self.blood_req, state='ISSUE_REPORTED').last()
        self.assertIsNotNone(event)
        self.assertIn('DONOR_NO_SHOW', event.note)
        self.assertIn('Pending admin review', event.note)

    def test_7_can_report_booleans_on_journey_detail(self):
        from datetime import timedelta
        from django.utils import timezone

        # Fresh journey (within ETA)
        # Donor perspective
        self.client.force_authenticate(user=self.donor_user)
        resp_donor = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_donor.status_code, status.HTTP_200_OK)
        donor_data = resp_donor.json()
        self.assertTrue(donor_data['can_report_medical'])
        self.assertFalse(donor_data['can_report_no_show'])

        # Requester perspective before ETA + grace
        self.client.force_authenticate(user=self.requester_user)
        resp_req = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_req.status_code, status.HTTP_200_OK)
        req_data = resp_req.json()
        self.assertFalse(req_data['can_report_medical'])
        self.assertFalse(req_data['can_report_no_show'])

        # After ETA + grace passed
        RequestAcceptance.objects.filter(id=self.acceptance.id).update(
            started_at=timezone.now() - timedelta(minutes=60)
        )
        resp_req_overdue = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        self.assertEqual(resp_req_overdue.status_code, status.HTTP_200_OK)
        overdue_data = resp_req_overdue.json()
        self.assertFalse(overdue_data['can_report_medical'])
        self.assertTrue(overdue_data['can_report_no_show'])

        # Completed/Failed journey
        RequestAcceptance.objects.filter(id=self.acceptance.id).update(status='COMPLETED')
        resp_completed = self.client.get(f'/api/journeys/{self.acceptance.id}/')
        comp_data = resp_completed.json()
        self.assertFalse(comp_data['can_report_medical'])
        self.assertFalse(comp_data['can_report_no_show'])


class B1Item8StandbyCapacityTests(TestCase):
    def setUp(self):
        from datetime import timedelta
        from django.utils import timezone
        from api.models import Hospital, DonorProfile, BloodRequest, StandbyOffer

        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='b1_8_req', password='password123', email='req8@example.com'
        )
        DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801811118800',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor 1
        self.donor1_user = User.objects.create_user(
            username='b1_8_donor1', password='password123', email='donor8_1@example.com', first_name='Donor One'
        )
        self.donor1_profile = DonorProfile.objects.create(
            user=self.donor1_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711118801',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor 2
        self.donor2_user = User.objects.create_user(
            username='b1_8_donor2', password='password123', email='donor8_2@example.com', first_name='Donor Two'
        )
        self.donor2_profile = DonorProfile.objects.create(
            user=self.donor2_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711118802',
            is_profile_complete=True,
            email_verified=True,
        )

        self.hospital = Hospital.objects.create(
            name='Item 8 Capacity Hospital',
            district='Dhaka',
            address='Mirpur, Dhaka',
        )

        # Request with units_needed = 1
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Eight',
            blood_group='O+',
            hospital=self.hospital,
            contact_phone='+8801811118800',
            units_needed=1,
            units_received=0,
            units_pending=0,
            status='ACTIVE',
        )

        now = timezone.now()
        self.offer1 = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.donor1_profile,
            status='PENDING',
            expires_at=now + timedelta(minutes=10),
        )
        self.offer2 = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.donor2_profile,
            status='PENDING',
            expires_at=now + timedelta(minutes=10),
        )

    def test_8_standby_capacity_prevents_two_donors_taking_one_slot(self):
        # 1. Donor 1 responds ACCEPT -> Success 200
        self.client.force_authenticate(user=self.donor1_user)
        resp1 = self.client.post(f'/api/standby/{self.offer1.id}/respond/', {'action': 'ACCEPT'})
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)

        self.offer1.refresh_from_db()
        self.assertEqual(self.offer1.status, 'ACCEPTED')

        self.blood_req.refresh_from_db()
        self.assertEqual(self.blood_req.units_pending, 1)

        # 2. Donor 2 responds ACCEPT on the same slot -> 409 Conflict (Capacity reached)
        self.client.force_authenticate(user=self.donor2_user)
        resp2 = self.client.post(f'/api/standby/{self.offer2.id}/respond/', {'action': 'ACCEPT'})
        self.assertEqual(resp2.status_code, status.HTTP_409_CONFLICT)
        self.assertIn('Slot Full', resp2.json().get('error', ''))

        self.offer2.refresh_from_db()
        self.assertEqual(self.offer2.status, 'DECLINED')

    def test_8_standby_expired_offer_rejected(self):
        from datetime import timedelta
        from django.utils import timezone
        from api.models import StandbyOffer

        # Expired offer
        expired_offer = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.donor2_profile,
            status='PENDING',
            expires_at=timezone.now() - timedelta(minutes=5),
        )
        self.client.force_authenticate(user=self.donor2_user)
        resp = self.client.post(f'/api/standby/{expired_offer.id}/respond/', {'action': 'ACCEPT'})
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('expired', resp.json().get('error', ''))


class Item0PositivePathTests(TestCase):
    def setUp(self):
        from django.utils import timezone
        from datetime import timedelta
        from api.models import Hospital, DonorProfile, BloodRequest, RequestAcceptance, StandbyOffer

        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='item0_req', password='password123', email='item0_req@example.com', first_name='Requester'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801811110001',
            is_profile_complete=True,
            email_verified=True,
        )

        # Donor
        self.donor_user = User.objects.create_user(
            username='item0_donor', password='password123', email='item0_donor@example.com', first_name='Donor'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711110002',
            is_profile_complete=True,
            email_verified=True,
        )

        # Standby Donor
        self.standby_user = User.objects.create_user(
            username='item0_standby', password='password123', email='item0_st@example.com', first_name='Standby'
        )
        self.standby_profile = DonorProfile.objects.create(
            user=self.standby_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711110003',
            is_profile_complete=True,
            email_verified=True,
        )

        self.hospital = Hospital.objects.create(
            name='Item 0 Test Hospital',
            district='Dhaka',
            address='Gulshan, Dhaka',
        )

        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Item Zero',
            blood_group='A+',
            hospital=self.hospital,
            contact_phone='+8801811110001',
            contact_number='+8801811110001',
            units_needed=1,
            units_received=0,
            units_pending=0,
            status='ACTIVE',
        )

    def test_0a_standby_donor_can_confirm_when_slot_free(self):
        from datetime import timedelta
        from django.utils import timezone
        from api.models import StandbyOffer, RequestAcceptance

        offer = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.standby_profile,
            status='PENDING',
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        self.client.force_authenticate(user=self.standby_user)
        resp = self.client.post(f'/api/standby/{offer.id}/respond/', {'action': 'ACCEPT'})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        offer.refresh_from_db()
        self.assertEqual(offer.status, 'ACCEPTED')

        acceptance = RequestAcceptance.objects.filter(request=self.blood_req, donor=self.standby_profile).first()
        self.assertIsNotNone(acceptance)
        self.assertEqual(acceptance.status, 'ACCEPTED')
        self.assertTrue(acceptance.is_standby)

    def test_0a_donor_can_report_medical_rejection_with_valid_code(self):
        from api.models import RequestAcceptance

        acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            eta_minutes=20,
        )

        self.client.force_authenticate(user=self.donor_user)
        resp = self.client.post(f'/api/journeys/{acceptance.id}/issue/', {
            'issue_type': 'MEDICAL_REJECTION',
            'reason_code': 'LOW_HEMOGLOBIN',
        })
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)

        acceptance.refresh_from_db()
        self.assertEqual(acceptance.status, 'FAILED')
        self.assertEqual(acceptance.cancellation_reason, 'Medical Rejection: LOW_HEMOGLOBIN')

    def test_0a_requester_can_report_donor_no_show_after_eta_and_grace(self):
        from datetime import timedelta
        from django.utils import timezone
        from api.models import RequestAcceptance

        # Scenario 1: eta_minutes = 25, overdue after 25 + 20 = 45 min
        acceptance_with_eta = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            eta_minutes=25,
        )
        RequestAcceptance.objects.filter(id=acceptance_with_eta.id).update(
            started_at=timezone.now() - timedelta(minutes=50)
        )

        self.client.force_authenticate(user=self.requester_user)
        resp1 = self.client.post(f'/api/journeys/{acceptance_with_eta.id}/issue/', {
            'issue_type': 'DONOR_NO_SHOW',
        })
        self.assertEqual(resp1.status_code, status.HTTP_201_CREATED)
        acceptance_with_eta.refresh_from_db()
        self.assertEqual(acceptance_with_eta.status, 'FAILED')

        # Scenario 2 (Item 0b): eta_minutes is None (donor offline), overdue after 0 + 20 = 20 min from accept time
        offline_acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.standby_profile,
            status='ACCEPTED',
            eta_minutes=None,
        )
        RequestAcceptance.objects.filter(id=offline_acceptance.id).update(
            started_at=timezone.now() - timedelta(minutes=25)
        )

        resp2 = self.client.post(f'/api/journeys/{offline_acceptance.id}/issue/', {
            'issue_type': 'DONOR_NO_SHOW',
        })
        self.assertEqual(resp2.status_code, status.HTTP_201_CREATED)
        offline_acceptance.refresh_from_db()
        self.assertEqual(offline_acceptance.status, 'FAILED')

    def test_0a_accepted_participants_still_see_real_phones(self):
        from api.models import RequestAcceptance

        acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            is_standby=False,
        )

        # Donor sees requester real phone
        self.client.force_authenticate(user=self.donor_user)
        resp_donor = self.client.get(f'/api/journeys/{acceptance.id}/')
        self.assertEqual(resp_donor.status_code, status.HTTP_200_OK)
        donor_view = resp_donor.json()
        self.assertEqual(donor_view['requester_contact'], '+8801811110001')

        # Requester sees donor real phone
        self.client.force_authenticate(user=self.requester_user)
        resp_req = self.client.get(f'/api/journeys/{acceptance.id}/')
        self.assertEqual(resp_req.status_code, status.HTTP_200_OK)
        req_view = resp_req.json()
        self.assertEqual(req_view['donor_contact'], '+8801711110002')

    def test_0a_preflight_from_firebase_app_allowed(self):
        resp = self.client.options(
            '/api/journeys/',
            HTTP_ORIGIN='https://bloodpulse-283dc.web.app',
            HTTP_ACCESS_CONTROL_REQUEST_METHOD='GET',
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.headers.get('Access-Control-Allow-Origin'), 'https://bloodpulse-283dc.web.app')
