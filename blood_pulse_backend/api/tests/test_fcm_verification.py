# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import io
from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.management import call_command
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile, UserDevice
from api.services.notify import send_push_to_user, send_fcm_multicast_batches


class FCMVerificationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='fcm_user', password='password123', email='fcm@example.com')
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801911111111',
            is_available=True,
        )

    def test_fcm_token_registration_tied_to_user_device(self):
        self.client.force_authenticate(user=self.user)
        resp = self.client.post('/api/users/update-fcm/', {
            'token': 'fcm_test_token_abc123',
            'device_id': 'device_pixel_8',
            'platform': 'android',
            'device_name': 'Google Pixel 8',
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.json()['status'], 'success')
        self.assertEqual(resp.json()['device_id'], 'device_pixel_8')

        # Verify UserDevice was updated
        device = UserDevice.objects.get(user=self.user, device_id='device_pixel_8')
        self.assertEqual(device.fcm_token, 'fcm_test_token_abc123')
        self.assertIsNotNone(device.fcm_updated_at)
        self.assertEqual(device.platform, 'android')

        # Verify DonorProfile was synced
        self.donor.refresh_from_db()
        self.assertEqual(self.donor.fcm_token, 'fcm_test_token_abc123')

    def test_fcm_token_refresh_updates_existing_device(self):
        self.client.force_authenticate(user=self.user)
        # First registration
        self.client.post('/api/users/update-fcm/', {
            'token': 'initial_token_111',
            'device_id': 'device_samsung_s24',
        })
        # Token refresh
        refresh_resp = self.client.post('/api/users/update-fcm/', {
            'token': 'refreshed_token_222',
            'device_id': 'device_samsung_s24',
        })
        self.assertEqual(refresh_resp.status_code, status.HTTP_200_OK)

        device = UserDevice.objects.get(user=self.user, device_id='device_samsung_s24')
        self.assertEqual(device.fcm_token, 'refreshed_token_222')

    def test_send_test_push_command_dry_run(self):
        UserDevice.objects.create(
            user=self.user,
            device_id='device_test',
            fcm_token='eXample_FCM_Token_For_DryRun_998877',
        )

        out = io.StringIO()
        call_command('send_test_push', user='fcm_user', stdout=out)
        output = out.getvalue()

        self.assertIn('[DRY RUN]', output)
        self.assertIn('fcm_user', output)
        self.assertIn('Tokens found  : 1', output)
        self.assertIn('--confirm', output)
        # Ensure secret token is masked
        self.assertNotIn('eXample_FCM_Token_For_DryRun_998877', output)
        self.assertIn('eXampl...8877', output)

    @patch('api.services.notify.send_fcm_multicast_batches')
    def test_send_test_push_command_confirm(self, mock_send):
        mock_send.return_value = {
            'sent': 1,
            'failed': 0,
            'invalid_tokens_cleared': 0,
        }
        UserDevice.objects.create(
            user=self.user,
            device_id='device_confirmed',
            fcm_token='valid_token_xyz',
        )

        out = io.StringIO()
        call_command('send_test_push', user='fcm_user', confirm=True, stdout=out)
        output = out.getvalue()

        self.assertIn('[EXECUTED]', output)
        self.assertIn('Sent successfully: 1', output)
        mock_send.assert_called_once()

    @patch('firebase_admin.messaging.send_each_for_multicast')
    def test_invalid_token_cleanup_on_device_and_profile(self, mock_multicast):
        token = 'invalid_unregistered_token_123'
        device = UserDevice.objects.create(
            user=self.user,
            device_id='device_bad',
            fcm_token=token,
        )
        self.donor.fcm_token = token
        self.donor.save(update_fields=['fcm_token'])

        # Mock an Unregistered response from FCM
        mock_resp_item = MagicMock()
        mock_resp_item.success = False
        mock_resp_item.exception = Exception('Requested entity was not found: unregistered token')

        mock_multicast_result = MagicMock()
        mock_multicast_result.success_count = 0
        mock_multicast_result.failure_count = 1
        mock_multicast_result.responses = [mock_resp_item]
        mock_multicast.return_value = mock_multicast_result

        tokens_with_donors = [(token, self.donor)]
        res = send_fcm_multicast_batches(tokens_with_donors, 'Title', 'Body')

        self.assertEqual(res['invalid_tokens_cleared'], 1)
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.fcm_token)

        device.refresh_from_db()
        self.assertIsNone(device.fcm_token)
