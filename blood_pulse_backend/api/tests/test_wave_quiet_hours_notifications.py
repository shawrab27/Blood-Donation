# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from unittest.mock import patch, MagicMock
from datetime import datetime, timezone
from django.contrib.auth.models import User
from django.test import TestCase
from api.models import BloodRequest, DonorProfile, Notification, WaveNotificationLog, EmergencyNotification
from api.services.waves import get_candidate_donors_for_wave
from api.services.notify import dispatch_wave_notifications


class WaveQuietHoursNotificationTests(TestCase):
    def setUp(self):
        self.requester = User.objects.create_user(username='req_user', password='password123')
        self.donor_user = User.objects.create_user(username='donor_user', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            is_available=True,
            is_profile_complete=True,
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125,
            fcm_token='test_token_quiet_hours',
        )

    @patch('api.services.notify.send_fcm_multicast_batches')
    @patch('api.services.eligibility.is_in_quiet_hours', return_value=True)
    def test_urgent_request_during_quiet_hours_creates_in_app_and_attempts_push(self, mock_quiet, mock_fcm):
        """Urgent request during quiet hours creates in-app notification row + attempts push."""
        mock_fcm.return_value = {'sent': 1, 'failed': 0, 'invalid_tokens_cleared': 0}

        req_urgent = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='A+',  # O+ is compatible with A+
            effective_scope='LOCAL',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='URGENT',
            hospital_name_other='Dhaka Medical College',
            ward_bed='Ward 3, Bed 12',
            mode='EMERGENCY',
            status='ACTIVE',
        )

        candidates = get_candidate_donors_for_wave(req_urgent, wave_number=1)
        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0]['donor'], self.donor)

        dispatched = dispatch_wave_notifications(req_urgent, candidates, wave_number=1)
        self.assertEqual(dispatched, 1)

        # 1. In-app notification row MUST be created
        notif = Notification.objects.filter(user=self.donor_user, type='emergency_request_new').first()
        self.assertIsNotNone(notif)
        self.assertIn("Dhaka Medical College", notif.body)
        self.assertIn("A+ blood", notif.body)
        self.assertIn(f"[Req #{req_urgent.id}]", notif.body)

        # 2. Push MUST be attempted because request is URGENT
        mock_fcm.assert_called_once()
        args, kwargs = mock_fcm.call_args
        tokens_with_donors = args[0]
        self.assertEqual(len(tokens_with_donors), 1)
        self.assertEqual(tokens_with_donors[0][0], 'test_token_quiet_hours')

    @patch('api.services.notify.send_fcm_multicast_batches')
    @patch('api.services.eligibility.is_in_quiet_hours', return_value=True)
    def test_normal_request_during_quiet_hours_creates_in_app_row_without_push(self, mock_quiet, mock_fcm):
        """Normal request during quiet hours creates in-app notification row silently WITHOUT push."""
        req_normal = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='A+',
            effective_scope='LOCAL',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='NORMAL',
            hospital_name_other='Kurmitola General Hospital',
            ward_bed='Ward 5, Bed 2',
            mode='EMERGENCY',
            status='ACTIVE',
        )

        candidates = get_candidate_donors_for_wave(req_normal, wave_number=1)
        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0]['donor'], self.donor)

        dispatched = dispatch_wave_notifications(req_normal, candidates, wave_number=1)
        self.assertEqual(dispatched, 1)

        # 1. In-app notification row MUST be created
        notif = Notification.objects.filter(user=self.donor_user, type='emergency_request_new').first()
        self.assertIsNotNone(notif)
        self.assertIn("Kurmitola General Hospital", notif.body)
        self.assertIn(f"[Req #{req_normal.id}]", notif.body)

        # 2. Push MUST NOT be called because urgency is NORMAL during quiet hours
        mock_fcm.assert_not_called()
