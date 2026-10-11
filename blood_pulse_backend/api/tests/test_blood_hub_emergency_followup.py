# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Integration tests for thank you letters, follow-up wellness checks,
national emergency 2-admin activation, poster data, and public QR landing.
"""

from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    DonationMatch,
    FollowUp,
    NationalEmergencyEvent,
    DisasterResponsePoint,
    DonationSlot,
)


class BloodHubEmergencyAndFollowUpTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Users
        self.requester = User.objects.create_user(username='req_u', password='password123', email='req@test.com')
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester, blood_group='B+', district='Dhaka', phone_number='+8801799990001', is_profile_complete=True
        )

        self.donor = User.objects.create_user(username='donor_u', password='password123', email='donor@test.com')
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor, blood_group='B+', district='Dhaka', phone_number='+8801799990002', is_available=True, is_profile_complete=True
        )

        self.admin1 = User.objects.create_user(username='admin1', password='password123', is_staff=True)
        self.admin2 = User.objects.create_user(username='admin2', password='password123', is_staff=True)

        self.hospital = Hospital.objects.create(name='Kurmitola General Hospital', district='Dhaka')

        self.req = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='B+',
            hospital=self.hospital,
            units_needed=1,
            status='OPEN',
        )

    def test_donation_history_followup_and_thank_you_flow(self):
        # Create match
        match = DonationMatch.objects.create(
            request=self.req,
            donor=self.donor_profile,
            status='ACCEPTED',
            role='PRIMARY',
        )

        # Move request to ARRIVED so transition to DONATED is valid
        self.req.status = 'ARRIVED'
        self.req.save()

        # Move to DONATED via single-sided status update
        self.client.force_authenticate(user=self.donor)
        res_donated = self.client.post(f'/api/matches/{match.id}/status/', {'status': 'DONATED'}, format='json')
        self.assertEqual(res_donated.status_code, status.HTTP_200_OK)
        match.refresh_from_db()
        self.assertEqual(match.status, 'DONATED')

        # Invariant Part 0(b): One-sided DONATED MUST NOT increment bags or history!
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.total_bags_donated, 0)
        self.assertEqual(FollowUp.objects.filter(match=match).count(), 0)

        # Now execute two-sided confirmation (both donor and requester confirm)
        self.client.force_authenticate(user=self.donor)
        res_conf_d = self.client.post(f'/api/matches/{match.id}/confirm/', {'action': 'CONFIRM'}, format='json')
        self.assertEqual(res_conf_d.status_code, status.HTTP_200_OK)

        self.client.force_authenticate(user=self.requester)
        res_conf_r = self.client.post(f'/api/matches/{match.id}/confirm/', {'action': 'CONFIRM'}, format='json')
        self.assertEqual(res_conf_r.status_code, status.HTTP_200_OK)

        # After two-sided confirmation: donor stats updated and FollowUp created
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.total_bags_donated, 1)

        # FollowUp created
        fu = FollowUp.objects.filter(match=match).first()
        self.assertIsNotNone(fu)
        self.assertEqual(fu.status, 'PENDING')

        # Requester sends thank you letter
        self.client.force_authenticate(user=self.requester)
        res_thanks = self.client.post(f'/api/matches/{match.id}/thanks/', {
            'template_key': 'warm_gratitude',
            'body': 'Deepest gratitude for arriving on time and helping our patient!',
        }, format='json')
        self.assertEqual(res_thanks.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_thanks.data['template_key'], 'warm_gratitude')

        # Donor answers follow-up
        self.client.force_authenticate(user=self.donor)
        res_fu = self.client.post(f'/api/followups/{fu.id}/answer/', {'response': 'OK', 'notes': 'Feeling great.'}, format='json')
        self.assertEqual(res_fu.status_code, status.HTTP_200_OK)
        fu.refresh_from_db()
        self.assertEqual(fu.status, 'ANSWERED')
        self.assertEqual(fu.response, 'OK')

    def test_national_emergency_two_admin_activation(self):
        event = NationalEmergencyEvent.objects.create(
            title="Monsoon Flash Flood Response 2026",
            title_en="Monsoon Flash Flood Response 2026",
            active=False,
            is_active=False,
        )
        point = DisasterResponsePoint.objects.create(
            event=event,
            name="Sylhet MAG Osmani Medical College",
            district="Sylhet",
            lat=24.9,
            lng=91.8,
        )
        slot = DonationSlot.objects.create(point=point, time_range="10:00 - 12:00", capacity=5, pledged=0)

        # Admin 1 approves
        self.client.force_authenticate(user=self.admin1)
        res1 = self.client.post('/api/admin/national-emergency/approve/', {'event_id': event.id}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        event.refresh_from_db()
        self.assertFalse(event.active)

        # Admin 1 approves again -> must be rejected (two different admins required)
        res_dup = self.client.post('/api/admin/national-emergency/approve/', {'event_id': event.id}, format='json')
        self.assertEqual(res_dup.status_code, status.HTTP_400_BAD_REQUEST)

        # Admin 2 approves -> flips active=True
        self.client.force_authenticate(user=self.admin2)
        res2 = self.client.post('/api/admin/national-emergency/approve/', {'event_id': event.id}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        event.refresh_from_db()
        self.assertTrue(event.active)

        # Query active emergency
        self.client.force_authenticate(user=self.donor)
        res_active = self.client.get('/api/national-emergency/active/')
        self.assertEqual(res_active.status_code, status.HTTP_200_OK)
        self.assertEqual(res_active.data['id'], event.id)

        # Pledge to donate decrements capacity
        res_pledge = self.client.post('/api/national-emergency/pledge/', {
            'event_id': event.id,
            'slot_id': slot.id,
        }, format='json')
        self.assertEqual(res_pledge.status_code, status.HTTP_201_CREATED)
        slot.refresh_from_db()
        self.assertEqual(slot.pledged, 1)

    def test_poster_data_and_public_qr_landing(self):
        # Poster data (authenticated)
        self.client.force_authenticate(user=self.requester)
        res_poster = self.client.get(f'/api/requests/{self.req.id}/poster-data/')
        self.assertEqual(res_poster.status_code, status.HTTP_200_OK)
        self.assertIn('qr_target_url', res_poster.data)
        self.assertEqual(res_poster.data['blood_group'], 'B+')

        # QR landing (public, unauthenticated)
        self.client.logout()
        res_qr = self.client.get(f'/api/requests/{self.req.id}/qr-landing/')
        self.assertEqual(res_qr.status_code, status.HTTP_200_OK)
        self.assertEqual(res_qr.data['blood_group'], 'B+')
        self.assertIn('cta_button_url', res_qr.data)

        # Strictly verify zero PII in public QR landing
        self.assertNotIn('patient_name', res_qr.data)
        self.assertNotIn('contact_phone', res_qr.data)
        self.assertNotIn('patient_photo', res_qr.data)
