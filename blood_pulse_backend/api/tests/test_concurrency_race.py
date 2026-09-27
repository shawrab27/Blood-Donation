# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import threading
from django.test import TransactionTestCase
from django.contrib.auth.models import User
from django.db import connection
from api.models import BloodRequest, DonorProfile, RequestAcceptance
from rest_framework.test import APIClient

class AcceptanceConcurrencyTest(TransactionTestCase):
    def setUp(self):
        self.requester = User.objects.create_user(username='req1', email='req@test.com', password='pw')
        self.donor1 = User.objects.create_user(username='d1', email='d1@test.com', password='pw')
        self.donor2 = User.objects.create_user(username='d2', email='d2@test.com', password='pw')
        
        DonorProfile.objects.create(user=self.donor1, blood_group='O+', phone_number='1111')
        DonorProfile.objects.create(user=self.donor2, blood_group='O+', phone_number='2222')
        
        self.req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Bob',
            blood_group='O+',
            units_needed=1,
            status='ACTIVE'
        )
        
    def test_concurrent_accepts(self):
        # We need to simulate two transactions. Since Django test clients don't do real concurrency by default easily without threads in TransactionTestCase
        
        client1 = APIClient()
        client1.force_authenticate(user=self.donor1)
        
        client2 = APIClient()
        client2.force_authenticate(user=self.donor2)
        
        from api.models import EmailOTP
        from api.services.email import hash_otp
        from django.utils import timezone
        from datetime import timedelta
        EmailOTP.objects.create(
            email='d1@test.com',
            otp_hash=hash_otp('123456', 'd1@test.com'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False
        )
        EmailOTP.objects.create(
            email='d2@test.com',
            otp_hash=hash_otp('123456', 'd2@test.com'),
            expires_at=timezone.now() + timedelta(minutes=10),
            is_used=False
        )

        results = [None, None]
        
        def accept_req(client, index):
            # Each thread needs its own DB connection
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
