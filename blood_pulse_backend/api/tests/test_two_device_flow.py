# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
End-to-End Two-Device Integration Test Suite (Anomaly #27).
Simulates real-world interaction between:
- Device A (Requester: Dr. Sultana / Fatima at Hospital in Dhaka)
- Device B (Donor: Kamal Hossain, O+, traveling to hospital)
- Device C (Standby Donor: backup candidate upon cancellation)
"""

from unittest.mock import patch
from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    DonationMatch,
    DirectMessage,
    DonorFeedback,
    StandbyOffer,
    Notification,
    UserNotificationState,
    EmergencyNotification,
)
from api.services.notify import dispatch_wave_notifications


class TwoDeviceEndToEndFlowTests(TestCase):
    def setUp(self):
        # Device A (Requester Client)
        self.device_a_client = APIClient()
        self.requester_user = User.objects.create_user(
            username='device_a_requester',
            password='password123',
            first_name='Dr. Sultana',
            email='requester@example.com',
        )
        self.device_a_client.force_authenticate(user=self.requester_user)

        # Device B (Donor Client)
        self.device_b_client = APIClient()
        self.donor_user = User.objects.create_user(
            username='device_b_donor',
            password='password123',
            first_name='Kamal Hossain',
            email='donor_kamal@example.com',
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801822222222',
            fcm_token='token_device_b_donor',
            is_available=True,
            is_profile_complete=True,
            latitude=23.7500,
            longitude=90.3900,
        )
        self.device_b_client.force_authenticate(user=self.donor_user)

        # Hospital Destination in Dhaka
        self.hospital = Hospital.objects.create(
            name='National Institute of Cardiovascular Diseases (NICVD)',
            district='Dhaka',
            lat=23.7700,
            lng=90.3700,
        )

    @patch('api.services.notify.send_fcm_multicast_batches')
    def test_complete_two_device_journey_lifecycle(self, mock_fcm):
        mock_fcm.return_value = {'sent': 1, 'failed': 0, 'invalid_tokens_cleared': 0}

        # ---------------------------------------------------------
        # Step 1: Device A creates urgent requisition
        # ---------------------------------------------------------
        blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Emergency Cardiac Patient',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_phone='+8801811111111',
            status='ACTIVE',
            lat=23.7700,
            lng=90.3700,
        )
        self.assertEqual(blood_req.status, 'ACTIVE')

        # ---------------------------------------------------------
        # Step 2: Wave notification engine alerts Device B
        # ---------------------------------------------------------
        candidates = [{'donor': self.donor_profile, 'distance_km': 3.2}]
        dispatched = dispatch_wave_notifications(blood_req, candidates, wave_number=1)
        self.assertEqual(dispatched, 1)

        # Verify Device B receives in-app emergency notification & badge
        badge = UserNotificationState.objects.get(user=self.donor_user)
        self.assertEqual(badge.unread_count, 1)
        emerg_notif = EmergencyNotification.objects.filter(donor=self.donor_profile, request=blood_req).first()
        self.assertIsNotNone(emerg_notif)
        self.assertEqual(emerg_notif.request_id, blood_req.id)

        # ---------------------------------------------------------
        # Step 3: Device B accepts the requisition
        # ---------------------------------------------------------
        # Initialize RequestAcceptance and DonationMatch
        acceptance = RequestAcceptance.objects.create(
            request=blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
        )
        match = DonationMatch.objects.create(
            request=blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
            units_pledged=1,
        )

        # ---------------------------------------------------------
        # Step 4: Live GPS Tracking & ETA Calculation
        # ---------------------------------------------------------
        # Device B signals transit
        resp_status = self.device_b_client.post(f'/api/journeys/{acceptance.id}/status/', {
            'status': 'ON_THE_WAY',
        })
        self.assertEqual(resp_status.status_code, status.HTTP_200_OK)

        # Device B sends live GPS coordinates
        donor_lat, donor_lng = 23.7550, 90.3800
        resp_loc = self.device_b_client.post(f'/api/journeys/{acceptance.id}/location/', {
            'lat': donor_lat,
            'lng': donor_lng,
        })
        self.assertEqual(resp_loc.status_code, status.HTTP_200_OK)
        loc_data = resp_loc.json()
        self.assertEqual(loc_data['status'], 'updated')
        self.assertGreater(loc_data['distance_km'], 0)
        self.assertGreater(loc_data['eta_minutes'], 0)

        # Device A polls live tracking: verifies coordinates, destination & ETA
        view_loc = self.device_a_client.get(f'/api/journeys/{acceptance.id}/location/')
        self.assertEqual(view_loc.status_code, status.HTTP_200_OK)
        view_data = view_loc.json()
        self.assertTrue(view_data['is_tracking_active'])
        self.assertAlmostEqual(view_data['donor_lat'], donor_lat, places=4)
        self.assertAlmostEqual(view_data['donor_lng'], donor_lng, places=4)
        self.assertIn('destination', view_data)

        # Unauthorized Device (outsider) gets 403 Forbidden
        outsider_client = APIClient()
        outsider_user = User.objects.create_user(username='outsider_device', password='password123')
        outsider_client.force_authenticate(user=outsider_user)
        resp_forbid = outsider_client.get(f'/api/journeys/{acceptance.id}/location/')
        self.assertEqual(resp_forbid.status_code, status.HTTP_403_FORBIDDEN)

        # ---------------------------------------------------------
        # Step 5: Direct Chat & Voice Message Communication
        # ---------------------------------------------------------
        # Device A sends text message to Device B
        msg_resp = self.device_a_client.post(f'/api/chat/{acceptance.id}/messages/', {
            'content': 'Please come to 3rd floor ICU blood bank room.',
        })
        self.assertEqual(msg_resp.status_code, status.HTTP_201_CREATED)
        msg_id = msg_resp.json()['id']

        # Device B retrieves messages and marks as read
        get_msgs = self.device_b_client.get(f'/api/chat/{acceptance.id}/messages/')
        self.assertEqual(get_msgs.status_code, status.HTTP_200_OK)
        results_b = get_msgs.json().get('results', [])
        self.assertTrue(any(m['id'] == msg_id for m in results_b))

        read_resp = self.device_b_client.post(f'/api/chat/{acceptance.id}/messages/{msg_id}/read/')
        self.assertEqual(read_resp.status_code, status.HTTP_200_OK)

        # Device B uploads and sends a voice message
        dummy_audio = SimpleUploadedFile(
            "donor_voice.m4a",
            b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00isomiso2",
            content_type="audio/m4a",
        )
        voice_upload = self.device_b_client.post(
            f'/api/chat/{acceptance.id}/voice/',
            {'voice_file': dummy_audio, 'duration_seconds': 14},
            format='multipart',
        )
        self.assertEqual(voice_upload.status_code, status.HTTP_201_CREATED)
        voice_url = voice_upload.json()['voice_url']

        voice_msg_resp = self.device_b_client.post(f'/api/chat/{acceptance.id}/messages/', {
            'content': '',
            'message_type': 'VOICE',
            'voice_url': voice_url,
            'voice_duration_seconds': 14,
        })
        self.assertEqual(voice_msg_resp.status_code, status.HTTP_201_CREATED)

        # Device A retrieves chat messages and observes the voice note
        a_msgs = self.device_a_client.get(f'/api/chat/{acceptance.id}/messages/')
        self.assertEqual(a_msgs.status_code, status.HTTP_200_OK)
        results_a = a_msgs.json().get('results', [])
        voice_entry = next((m for m in results_a if m['message_type'] == 'VOICE'), None)
        self.assertIsNotNone(voice_entry)
        self.assertEqual(voice_entry['voice_duration_seconds'], 14)

        # ---------------------------------------------------------
        # Step 6: Arrival & Donation Completion
        # ---------------------------------------------------------
        # Device B arrives at hospital
        resp_arrive = self.device_b_client.post(f'/api/journeys/{acceptance.id}/status/', {
            'status': 'ARRIVED',
        })
        self.assertEqual(resp_arrive.status_code, status.HTTP_200_OK)

        # Device B completes blood donation
        resp_donated = self.device_b_client.post(f'/api/journeys/{acceptance.id}/status/', {
            'status': 'DONATED',
        })
        self.assertEqual(resp_donated.status_code, status.HTTP_200_OK)

        # Device A confirms donation
        resp_confirmed = self.device_a_client.post(f'/api/journeys/{acceptance.id}/status/', {
            'status': 'CONFIRMED',
        })
        self.assertEqual(resp_confirmed.status_code, status.HTTP_200_OK)

        # Two-sided confirmation on DonationMatch
        resp_match_b = self.device_b_client.post(f'/api/matches/{match.id}/confirm/', {
            'action': 'CONFIRM',
        })
        self.assertEqual(resp_match_b.status_code, status.HTTP_200_OK)

        resp_match_a = self.device_a_client.post(f'/api/matches/{match.id}/confirm/', {
            'action': 'CONFIRM',
        })
        self.assertEqual(resp_match_a.status_code, status.HTTP_200_OK)

        match.refresh_from_db()
        self.assertIsNotNone(match.confirmed_at)
        self.assertEqual(match.status, 'DONATED')

        # Verify donor profile updated
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.fulfilled_count, 1)

        # ---------------------------------------------------------
        # Step 7: Post-Donation Feedback & Privacy
        # ---------------------------------------------------------
        # Device B (Donor) submits 5-star private feedback
        feedback_resp = self.device_b_client.post(
            f'/api/requests/{blood_req.id}/feedback/',
            {'stars': 5, 'tags': ['POLITE', 'GAVE_FOOD']},
            format='json',
        )
        self.assertEqual(feedback_resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(DonorFeedback.objects.filter(request=blood_req, donor=self.donor_profile).exists())

        # Device A (Requester) is blocked from reading donor feedback (privacy shield)
        view_fb_resp = self.device_a_client.get(f'/api/requests/{blood_req.id}/feedback/')
        self.assertEqual(view_fb_resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_two_device_cancellation_and_standby_activation(self):
        # Requester on Device A creates request
        blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Accident Victim',
            blood_group='O+',
            units_needed=1,
            hospital=self.hospital,
            contact_phone='+8801811111111',
            status='ACTIVE',
        )

        # Device C (Standby Donor)
        standby_user = User.objects.create_user(
            username='device_c_standby',
            password='password123',
            first_name='Salim',
        )
        standby_profile = DonorProfile.objects.create(
            user=standby_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801844444444',
            fcm_token='token_device_c',
            is_available=True,
            is_profile_complete=True,
            latitude=23.7650,
            longitude=90.3850,
        )
        device_c_client = APIClient()
        device_c_client.force_authenticate(user=standby_user)

        # Primary acceptance on Device B
        primary_acceptance = RequestAcceptance.objects.create(
            request=blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
        )

        # Device B cancels journey due to unexpected transit issue
        cancel_resp = self.device_b_client.post(f'/api/journeys/{primary_acceptance.id}/status/', {
            'status': 'CANCELLED',
            'reason': 'Motorbike breakdown on road',
        })
        self.assertEqual(cancel_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(cancel_resp.json()['standby_triggered'])

        # Standby offer created for Device C
        offer = StandbyOffer.objects.filter(request=blood_req, donor=standby_profile).first()
        self.assertIsNotNone(offer)
        self.assertEqual(offer.status, 'PENDING')

        # Device C accepts standby offer and becomes active donor
        accept_resp = device_c_client.post(f'/api/standby/{offer.id}/respond/', {
            'action': 'ACCEPT',
        })
        self.assertEqual(accept_resp.status_code, status.HTTP_200_OK)

        offer.refresh_from_db()
        self.assertEqual(offer.status, 'ACCEPTED')

        # New standby acceptance exists for Device C
        new_acc = RequestAcceptance.objects.filter(request=blood_req, donor=standby_profile).first()
        self.assertIsNotNone(new_acc)
        self.assertTrue(new_acc.is_standby)
        self.assertEqual(new_acc.status, 'ACCEPTED')

        # Device A (Requester) receives notification that Device C joined
        notif = Notification.objects.filter(user=self.requester_user, type='STANDBY_ACCEPTED').first()
        self.assertIsNotNone(notif)
