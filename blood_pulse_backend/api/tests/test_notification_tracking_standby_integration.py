# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from unittest.mock import patch
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    StandbyOffer,
    Notification,
    UserNotificationState,
    WaveNotificationLog,
    EmergencyNotification,
)
from api.services.notify import dispatch_wave_notifications


class NotificationTrackingStandbyAutomatedTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.requester_user = User.objects.create_user(username='req_user', password='password123', first_name='Sultana')
        self.primary_donor_user = User.objects.create_user(username='primary_donor', password='password123', first_name='Kamal')
        self.standby_donor_user = User.objects.create_user(username='standby_donor', password='password123', first_name='Nasir')

        self.hospital = Hospital.objects.create(
            name='National Institute of Cardiovascular Diseases',
            district='Dhaka',
            lat=23.7700,
            lng=90.3700,
        )

        self.primary_donor = DonorProfile.objects.create(
            user=self.primary_donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801822222222',
            fcm_token='token_primary_donor',
            is_available=True,
            latitude=23.7500,
            longitude=90.3900,
        )

        self.standby_donor = DonorProfile.objects.create(
            user=self.standby_donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801833333333',
            fcm_token='token_standby_donor',
            is_available=True,
            latitude=23.7600,
            longitude=90.4000,
        )

        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Cardiac Patient',
            blood_group='O+',
            units_needed=2,
            hospital=self.hospital,
            contact_phone='+8801811111111',
            status='ACTIVE',
        )

    @patch('api.services.notify.send_fcm_multicast_batches')
    def test_wave_engine_notifications_and_deduplication(self, mock_fcm):
        mock_fcm.return_value = {'sent': 2, 'failed': 0, 'invalid_tokens_cleared': 0}

        candidates = [
            {'donor': self.primary_donor, 'distance_km': 2.5},
            {'donor': self.standby_donor, 'distance_km': 3.8},
        ]

        # Wave 1 dispatch
        dispatched_1 = dispatch_wave_notifications(self.blood_req, candidates, wave_number=1)
        self.assertEqual(dispatched_1, 2)
        mock_fcm.assert_called_once()

        # Audit records created
        self.assertEqual(WaveNotificationLog.objects.filter(request=self.blood_req).count(), 2)
        self.assertEqual(EmergencyNotification.objects.filter(request=self.blood_req).count(), 2)

        # Unread badges incremented
        badge = UserNotificationState.objects.get(user=self.primary_donor_user)
        self.assertEqual(badge.unread_count, 1)

        # Wave 2 dispatch with same candidates -> deduplication must prevent re-dispatching
        mock_fcm.reset_mock()
        dispatched_2 = dispatch_wave_notifications(self.blood_req, candidates, wave_number=2)
        self.assertEqual(dispatched_2, 0)
        mock_fcm.assert_not_called()

    def test_tracking_location_updates_and_privacy(self):
        # Create accepted journey
        acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.primary_donor,
            status='ACCEPTED',
        )

        # Donor updates location
        self.client.force_authenticate(user=self.primary_donor_user)
        resp_update = self.client.post(f'/api/journeys/{acceptance.id}/location/', {
            'lat': 23.7550,
            'lng': 90.3850,
        })
        self.assertEqual(resp_update.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_update.json()['status'], 'updated')

        # Requester queries tracking -> gets location and destination
        self.client.force_authenticate(user=self.requester_user)
        resp_view = self.client.get(f'/api/journeys/{acceptance.id}/location/')
        self.assertEqual(resp_view.status_code, status.HTTP_200_OK)
        data = resp_view.json()
        self.assertAlmostEqual(data['donor_lat'], 23.7550, places=4)
        self.assertAlmostEqual(data['donor_lng'], 90.3850, places=4)
        self.assertIn('destination', data)

        # Unauthorized outsider gets 403 Forbidden
        outsider = User.objects.create_user(username='outsider_tracking', password='password123')
        self.client.force_authenticate(user=outsider)
        resp_forbidden = self.client.get(f'/api/journeys/{acceptance.id}/location/')
        self.assertEqual(resp_forbidden.status_code, status.HTTP_403_FORBIDDEN)

    def test_standby_promotion_and_notification(self):
        # Primary donor acceptance
        primary_acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.primary_donor,
            status='ACCEPTED',
        )

        # Primary donor cancels journey -> Standby auto-triggered by journey cancellation
        self.client.force_authenticate(user=self.primary_donor_user)
        cancel_resp = self.client.post(f'/api/journeys/{primary_acceptance.id}/status/', {
            'status': 'CANCELLED',
            'reason': 'Flat tire on highway',
        })
        self.assertEqual(cancel_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(cancel_resp.json().get('standby_triggered'))

        standby_offer = StandbyOffer.objects.filter(request=self.blood_req, donor=self.standby_donor).first()
        self.assertIsNotNone(standby_offer)
        self.assertEqual(standby_offer.status, 'PENDING')

        # In-app notification created for standby donor
        notif = Notification.objects.filter(user=self.standby_donor_user, type='STANDBY_OFFER').first()
        self.assertIsNotNone(notif)
        self.assertIn("Standby", notif.title)

        # Standby donor responds and accepts -> transitions to ACCEPTED
        self.client.force_authenticate(user=self.standby_donor_user)
        accept_resp = self.client.post(f'/api/standby/{standby_offer.id}/respond/', {
            'action': 'ACCEPT',
        })
        self.assertEqual(accept_resp.status_code, status.HTTP_200_OK)

        standby_offer.refresh_from_db()
        self.assertEqual(standby_offer.status, 'ACCEPTED')

        # Requester receives notification that standby donor stepped up
        req_notif = Notification.objects.filter(user=self.requester_user, type='STANDBY_ACCEPTED').first()
        self.assertIsNotNone(req_notif)
