# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import io
from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.management import call_command
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

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

    def test_logout_revokes_device_and_fcm_token_stops_push(self):
        """P0-1: Logout must revoke UserDevice, clear FCM token, and send_push_to_user must target nothing."""
        token = 'active_push_token_for_logout_test_123'
        device = UserDevice.objects.create(
            user=self.user,
            device_id='device_to_logout',
            fcm_token=token,
            is_revoked=False,
        )
        self.donor.fcm_token = token
        self.donor.save(update_fields=['fcm_token'])

        # Before logout: user has 1 active token
        pre_push = send_push_to_user(self.user, 'Test', 'Body', dry_run=True)
        self.assertEqual(pre_push['status'], 'dry_run')
        self.assertEqual(pre_push['tokens_count'], 1)

        # Call logout with device_id
        self.client.force_authenticate(user=self.user)
        logout_resp = self.client.post('/api/auth/logout/', {
            'device_id': 'device_to_logout',
            'fcm_token': token,
        })
        self.assertEqual(logout_resp.status_code, status.HTTP_200_OK)

        # Verify device revoked and fcm_token cleared
        device.refresh_from_db()
        self.assertTrue(device.is_revoked)
        self.assertIsNone(device.fcm_token)

        # Verify donor profile cleared
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.fcm_token)

        # After logout: send_push_to_user must target nothing
        post_push = send_push_to_user(self.user, 'Test', 'Body', dry_run=True)
        self.assertEqual(post_push['status'], 'no_tokens')
        self.assertEqual(post_push['tokens_count'], 0)

    def test_update_fcm_requires_is_authenticated_not_admin(self):
        """Endpoint /api/users/update-fcm/ must require IsAuthenticated, but not IsAdminUser."""
        # 1. Unauthenticated -> 401
        resp = self.client.post('/api/users/update-fcm/', {'token': 'unauth_tok_123'})
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

        # 2. Authenticated regular user (not staff, not superuser) -> 200
        self.assertFalse(self.user.is_staff)
        self.assertFalse(self.user.is_superuser)
        self.client.force_authenticate(user=self.user)
        resp2 = self.client.post('/api/users/update-fcm/', {
            'token': 'auth_regular_user_token_123',
            'device_id': 'dev_regular_user',
        })
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)

    def test_logout_via_refresh_token_resolves_user_and_revokes_device(self):
        """When client calls /api/auth/logout/ unauthenticated with refresh token, server resolves user and clears device FCM token."""
        token = 'tok_for_anon_refresh_logout'
        device = UserDevice.objects.create(
            user=self.user,
            device_id='dev_anon_logout',
            fcm_token=token,
            is_revoked=False,
        )
        self.donor.fcm_token = token
        self.donor.save(update_fields=['fcm_token'])

        refresh = RefreshToken.for_user(self.user)
        # Client makes request WITHOUT Authorization header
        resp = self.client.post('/api/auth/logout/', {
            'refresh': str(refresh),
            'fcm_token': token,
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        device.refresh_from_db()
        self.assertTrue(device.is_revoked)
        self.assertIsNone(device.fcm_token)

        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.fcm_token)

    @patch('api.services.notify.send_push_to_user')
    def test_all_seven_send_paths(self, mock_send_push):
        """Audit and test all 7 send paths (wave, accepted, chat, tracking, standby, closing, thanks)."""
        from api.models import BloodRequest, RequestAcceptance, DirectMessage, StandbyOffer, DonorReview
        from api.services.notify import (
            notify_donor_accepted,
            notify_chat_message,
            notify_journey_update,
            notify_standby_offer,
            notify_request_closed,
            notify_donor_thanks,
            dispatch_wave_notifications,
        )

        mock_send_push.return_value = {'status': 'sent', 'sent': 1, 'failed': 0}

        requester = User.objects.create_user(username='req_user', password='password123')
        req = BloodRequest.objects.create(
            requester=requester,
            patient_name='Patient A',
            blood_group='O+',
            units_needed=2,
            district='Dhaka',
            contact_number='+8801700000000',
        )

        # 1. New request / Wave alert
        candidate = {'donor': self.donor, 'distance': 2.5}
        with patch('api.services.notify.send_fcm_multicast_batches') as mock_multicast:
            mock_multicast.return_value = {'sent': 1, 'failed': 0, 'invalid_tokens_cleared': 0}
            self.donor.fcm_token = 'token_for_wave'
            self.donor.save(update_fields=['fcm_token'])
            count = dispatch_wave_notifications(req, [candidate], wave_number=1)
            self.assertEqual(count, 1)
            mock_multicast.assert_called_once()
            # Verify payload and channel
            call_args = mock_multicast.call_args[0]
            self.assertIn("Urgent: O+ Blood Needed!", call_args[1])
            self.assertEqual(mock_multicast.call_args[0][3]['type'], 'BLOOD_EMERGENCY')

        # 2. Donor accepted
        acc = RequestAcceptance.objects.create(
            request=req,
            donor=self.donor,
            status='ACCEPTED',
            units_pledged=1,
        )
        notify_donor_accepted(req, acc)
        self.assertTrue(mock_send_push.called)
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], requester)
        self.assertEqual(last_call[1]['data_payload']['type'], 'DONOR_ACCEPTED')

        # 3. Chat message
        msg = DirectMessage.objects.create(
            acceptance=acc,
            sender=requester,
            recipient=self.user,
            content='Hello donor',
            message_type='TEXT',
        )
        notify_chat_message(msg, self.user)
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], self.user)
        self.assertEqual(last_call[1]['data_payload']['type'], 'CHAT_MESSAGE')

        # 4. Tracking event (e.g. ON_THE_WAY)
        notify_journey_update(acc, 'ON_THE_WAY', self.user)
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], requester)
        self.assertEqual(last_call[1]['data_payload']['type'], 'JOURNEY_UPDATE')
        self.assertEqual(last_call[1]['data_payload']['status'], 'ON_THE_WAY')

        # 5. Standby offer
        from django.utils import timezone
        from datetime import timedelta
        offer = StandbyOffer.objects.create(
            request=req,
            donor=self.donor,
            status='PENDING',
            expires_at=timezone.now() + timedelta(minutes=15),
        )
        notify_standby_offer(offer)
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], self.user)
        self.assertEqual(last_call[1]['data_payload']['type'], 'STANDBY_OFFER')

        # 6. Request closing
        notify_request_closed(req, 'FULFILLED')
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], requester)
        self.assertEqual(last_call[1]['data_payload']['type'], 'REQUEST_CLOSED')

        # 7. Thanks / Review
        from api.models import DonationHistory
        DonationHistory.objects.create(
            donor=self.donor,
            linked_request=req,
            date=timezone.now().date(),
            bags=1,
        )
        review = DonorReview.objects.create(
            donor=self.donor,
            reviewer=requester,
            blood_request=req,
            stars=5,
            comment='Lifesaver! Thank you!',
        )
        notify_donor_thanks(req, self.donor, review)
        last_call = mock_send_push.call_args
        self.assertEqual(last_call[0][0], self.user)
        self.assertEqual(last_call[1]['data_payload']['type'], 'DONOR_THANKS')

    def test_firebase_service_account_assembly_from_split_env_vars(self):
        """Assembling credentials from FIREBASE_SERVICE_ACCOUNT_* split env vars produces valid dict without exposing secrets."""
        from api.services.firebase_service import assemble_firebase_credentials_from_env
        import os

        env_vars = {
            'FIREBASE_SERVICE_ACCOUNT_PROJECT_ID': 'test-bloodpulse-proj',
            'FIREBASE_SERVICE_ACCOUNT_CLIENT_EMAIL': 'firebase-adminsdk@test-bloodpulse.iam.gserviceaccount.com',
            'FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY': '-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASC\\n-----END PRIVATE KEY-----\\n',
            'FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY_ID': 'key123',
            'FIREBASE_SERVICE_ACCOUNT_CLIENT_ID': 'client456',
        }
        with patch.dict(os.environ, env_vars, clear=False):
            cred_dict = assemble_firebase_credentials_from_env()
            self.assertIsNotNone(cred_dict)
            self.assertEqual(cred_dict['project_id'], 'test-bloodpulse-proj')
            self.assertEqual(cred_dict['client_email'], 'firebase-adminsdk@test-bloodpulse.iam.gserviceaccount.com')
            self.assertIn('\n', cred_dict['private_key'])
            self.assertNotIn('\\n', cred_dict['private_key'])

    def test_send_test_push_positional_user_id(self):
        """send_test_push accepts positional user_id and defaults to dry-run."""
        UserDevice.objects.create(
            user=self.user,
            device_id='dev_positional',
            fcm_token='tok_positional_12345678',
        )
        out = io.StringIO()
        call_command('send_test_push', str(self.user.id), stdout=out)
        output = out.getvalue()
        self.assertIn('[DRY RUN]', output)
        self.assertIn(self.user.username, output)
        self.assertIn('Tokens found  : 1', output)

