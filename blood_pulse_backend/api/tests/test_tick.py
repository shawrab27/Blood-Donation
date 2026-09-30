# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
import os

class TickEndpointTests(TestCase):
    def test_tick_requires_valid_token(self):
        client = APIClient()
        os.environ['EMERGENCY_TICK_TOKEN'] = 'super_secret_tick_token'
        
        # Missing token
        resp = client.get('/api/emergency/tick/')
        self.assertIn(resp.status_code, [401, 403])
        
        # Wrong token
        resp = client.get('/api/emergency/tick/', HTTP_AUTHORIZATION='Bearer wrong')
        self.assertIn(resp.status_code, [401, 403])
        
        # Right token
        resp = client.get('/api/emergency/tick/', HTTP_AUTHORIZATION='Bearer super_secret_tick_token')
        self.assertEqual(resp.status_code, 200)
        
        # Works on HEAD
        resp_head = client.head('/api/emergency/tick/', HTTP_AUTHORIZATION='Bearer super_secret_tick_token')
        self.assertEqual(resp_head.status_code, 200)
    def test_tick_rejects_missing_or_invalid_tokens(self):
        client = APIClient()
        os.environ['EMERGENCY_TICK_TOKEN'] = 'super_secret_tick_token'

        # Send NO Authorization header at all
        resp_no_header = client.get('/api/emergency/tick/')
        self.assertEqual(resp_no_header.status_code, 403)

        # Send an obviously wrong token
        resp_wrong_token = client.get('/api/emergency/tick/', HTTP_AUTHORIZATION='Bearer hacker_token_123')
        self.assertEqual(resp_wrong_token.status_code, 403)

    def test_auto_deferral_on_maintenance_tick(self):
        from django.contrib.auth.models import User
        from api.models import DonorProfile
        from django.utils import timezone
        from datetime import timedelta
        
        user1 = User.objects.create_user(username='d1', password='pw', first_name="Test")
        user2 = User.objects.create_user(username='d2', password='pw', first_name="Test")
        user3 = User.objects.create_user(username='d3', password='pw', first_name="Test")
        
        now = timezone.now().date()
        
        # d1: donated 10 days ago (should be deferred)
        DonorProfile.objects.create(user=user1, phone_number='1', is_available=True, last_donation_date=now - timedelta(days=10), district="Dhaka", blood_group="O+")
        
        # d2: donated 91 days ago, currently deferred (should be re-enabled)
        DonorProfile.objects.create(user=user2, phone_number='2', is_available=False, last_donation_date=now - timedelta(days=91), district="Dhaka", blood_group="O+")
        
        # d3: donated 100 days ago, currently deferred but suspended (should remain deferred)
        DonorProfile.objects.create(user=user3, phone_number='3', is_available=False, is_suspended=True, last_donation_date=now - timedelta(days=100), district="Dhaka", blood_group="O+")
        
        client = APIClient()
        os.environ['EMERGENCY_TICK_TOKEN'] = 'super_secret_tick_token'
        
        resp = client.get('/api/emergency/maintenance-tick/', HTTP_AUTHORIZATION='Bearer super_secret_tick_token')
        self.assertEqual(resp.status_code, 200)
        
        data = resp.json()
        self.assertEqual(data.get('auto_deferred_count'), 1)
        self.assertEqual(data.get('auto_reenabled_count'), 1)
        
        d1 = DonorProfile.objects.get(user=user1)
        self.assertFalse(d1.is_available)
        
        d2 = DonorProfile.objects.get(user=user2)
        self.assertTrue(d2.is_available)
        
        d3 = DonorProfile.objects.get(user=user3)
        self.assertFalse(d3.is_available)
