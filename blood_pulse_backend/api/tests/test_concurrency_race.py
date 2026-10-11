# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import unittest
import threading
import uuid
from django.test import TransactionTestCase
from django.contrib.auth.models import User
from django.db import connection
from api.models import BloodRequest, DonorProfile, RequestAcceptance
from rest_framework.test import APIClient

class AcceptanceConcurrencyTest(TransactionTestCase):
    def setUp(self):
        uid = uuid.uuid4().hex[:6]
        self.requester = User.objects.create_user(username=f'req_{uid}', email=f'req_{uid}@test.com', password='pw', first_name="Test")
        self.donor1 = User.objects.create_user(username=f'd1_{uid}', email=f'd1_{uid}@test.com', password='pw', first_name="Test")
        self.donor2 = User.objects.create_user(username=f'd2_{uid}', email=f'd2_{uid}@test.com', password='pw', first_name="Test")
        
        DonorProfile.objects.create(user=self.donor1, blood_group='O+', phone_number=f'+88017{uid}11', district="Dhaka", is_available=True, is_profile_complete=True)
        DonorProfile.objects.create(user=self.donor2, blood_group='O+', phone_number=f'+88017{uid}22', district="Dhaka", is_available=True, is_profile_complete=True)
        
        self.req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Bob',
            blood_group='O+',
            units_needed=1,
            status='ACTIVE'
        )

    def _fixture_teardown(self):
        if connection.vendor == 'postgresql':
            with connection.cursor() as cursor:
                cursor.execute(
                    'TRUNCATE api_bloodrequest, auth_user, api_donorprofile, api_requestacceptance, api_donationmatch, api_emailotp CASCADE;'
                )
        else:
            super()._fixture_teardown()

    @unittest.skipIf(connection.vendor == 'sqlite', "Concurrency test requires PostgreSQL (row-level locking)")
    def test_concurrent_accepts(self):
        client1 = APIClient()
        client1.force_authenticate(user=self.donor1)
        
        client2 = APIClient()
        client2.force_authenticate(user=self.donor2)
        
        from api.models import EmailOTP
        from api.services.email import hash_otp
        from django.utils import timezone
        from datetime import timedelta
        EmailOTP.objects.create(
            email=self.donor1.email,
            otp_hash=hash_otp('123456', self.donor1.email),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False
        )
        EmailOTP.objects.create(
            email=self.donor2.email,
            otp_hash=hash_otp('123456', self.donor2.email),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False
        )

        results = [None, None]
        
        def accept_req(client, index):
            connection.close()
            response = client.post(f'/api/emergency/requests/{self.req.id}/accept/', {'otp': '123456'})
            results[index] = response.status_code
            connection.close()
            
        t1 = threading.Thread(target=accept_req, args=(client1, 0))
        t2 = threading.Thread(target=accept_req, args=(client2, 1))
        
        t1.start()
        t2.start()
        
        t1.join()
        t2.join()
        
        self.assertIn(201, results)
        self.assertIn(400, results)
        
        acceptances = RequestAcceptance.objects.filter(request=self.req, status='ACCEPTED')
        self.assertEqual(acceptances.count(), 1)

    @unittest.skipIf(connection.vendor == 'sqlite', "Concurrency test requires PostgreSQL (row-level locking)")
    def test_concurrent_v2_accept_slot_race(self):
        """Two donors racing for the last slot via V2 accept endpoint cannot overfill units_needed."""
        client1 = APIClient()
        client1.force_authenticate(user=self.donor1)
        client2 = APIClient()
        client2.force_authenticate(user=self.donor2)

        results = [None, None]

        def accept_v2(client, index):
            connection.close()
            response = client.post(
                f'/api/requests/{self.req.id}/accept/',
                {'support_status': 'CAN_SUPPORT', 'units_pledged': 1},
                format='json',
            )
            results[index] = response.status_code
            connection.close()

        t1 = threading.Thread(target=accept_v2, args=(client1, 0))
        t2 = threading.Thread(target=accept_v2, args=(client2, 1))
        t1.start()
        t2.start()
        t1.join()
        t2.join()

        self.assertIn(201, results)
        self.assertTrue(409 in results or 400 in results)
        self.req.refresh_from_db()
        self.assertEqual(self.req.units_pending, 1)
        self.assertLessEqual(self.req.units_received + self.req.units_pending, self.req.units_needed)

    @unittest.skipIf(connection.vendor == 'sqlite', "Concurrency test requires PostgreSQL (row-level locking)")
    def test_concurrent_5_donors_last_slot_race(self):
        """At least 5 donors concurrently try to claim the last unit: exactly 1 wins, 4 rejected."""
        from datetime import timedelta
        from django.utils import timezone

        uid = uuid.uuid4().hex[:6]
        req_target = BloodRequest.objects.create(
            requester=self.requester,
            patient_name=f'Race Patient {uid}',
            blood_group='O+',
            units_needed=1,
            status='OPEN',
            expires_at=timezone.now() + timedelta(hours=6),
        )

        donors = []
        for i in range(5):
            d_user = User.objects.create_user(
                username=f'donor_{uid}_{i}',
                email=f'donor_{uid}_{i}@test.com',
                password='pw',
                first_name=f'Donor{i}',
            )
            DonorProfile.objects.create(
                user=d_user,
                blood_group='O+',
                phone_number=f'+88017{uid}{i:02d}',
                district="Dhaka",
                is_available=True,
                is_profile_complete=True,
                user_intent='DONATE_AND_REQUEST',
            )
            donors.append(d_user)

        results = [None] * 5

        def donor_accept_thread(donor_user, index):
            connection.close()
            client = APIClient()
            client.force_authenticate(user=donor_user)
            res = client.post(
                f'/api/requests/{req_target.id}/accept/',
                {'support_status': 'CAN_SUPPORT', 'units_pledged': 1},
                format='json',
            )
            results[index] = res.status_code
            connection.close()

        threads = [
            threading.Thread(target=donor_accept_thread, args=(donors[i], i))
            for i in range(5)
        ]

        for t in threads:
            t.start()
        for t in threads:
            t.join()

        winners = [code for code in results if code == 201]
        rejected = [code for code in results if code in (400, 409)]

        self.assertEqual(len(winners), 1, f"Expected exactly 1 winner, got {len(winners)} (all: {results})")
        self.assertEqual(len(rejected), 4, f"Expected 4 rejected donors, got {len(rejected)} (all: {results})")

        req_target.refresh_from_db()
        self.assertEqual(req_target.units_received, 0)
        self.assertEqual(req_target.units_pending, 1)
        self.assertLessEqual(req_target.units_received + req_target.units_pending, req_target.units_needed)

