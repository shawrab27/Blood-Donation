# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from api.models import (
    DonorProfile, BloodRequest, RequestAcceptance, DirectMessage, District, Division
)

User = get_user_model()

class ChatQueryCountTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.division = Division.objects.create(name='Dhaka')
        self.district = District.objects.create(name='Dhaka', division=self.division)

        self.requester_user = User.objects.create_user(
            username='requester_user',
            first_name='Requester',
            last_name='Person',
            password='password123',
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            phone_number='01711111111',
            blood_group='A+',
            district='Dhaka',
            is_profile_complete=True,
        )

        self.donor_user = User.objects.create_user(
            username='donor_user',
            first_name='Donor',
            last_name='Hero',
            password='password123',
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            phone_number='01722222222',
            blood_group='A+',
            district='Dhaka',
            is_profile_complete=True,
        )

        self.req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Alpha',
            blood_group='A+',
            hospital_location='Dhaka Medical',
            district=self.district,
            status='IN_PROGRESS',
        )

        self.acceptance = RequestAcceptance.objects.create(
            request=self.req,
            donor=self.donor_profile,
            status='ACCEPTED',
        )

        # Create 30 direct messages between donor and requester
        messages = []
        for i in range(30):
            sender = self.requester_user if i % 2 == 0 else self.donor_user
            recipient = self.donor_user if i % 2 == 0 else self.requester_user
            messages.append(DirectMessage(
                acceptance=self.acceptance,
                sender=sender,
                recipient=recipient,
                content=f'Message number {i}',
                status='DELIVERED',
            ))
        DirectMessage.objects.bulk_create(messages)

    def test_get_messages_no_n_plus_one_queries(self):
        """
        Verify that fetching 30 chat messages does NOT cause N+1 queries.
        Query count must be constant regardless of number of messages due to select_related.
        """
        self.client.force_authenticate(user=self.requester_user)

        url = f'/api/chat/{self.acceptance.id}/messages/?limit=30'
        
        # We assert that total database queries are exactly 4
        # (acceptance check + unconfirmed check + count + messages with select_related)
        with self.assertNumQueries(4):
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertEqual(len(data.get('results', [])), 30)

        # Verify last-30 pagination limit
        self.assertEqual(data.get('count'), 30)
        self.assertEqual(data.get('limit'), 30)
