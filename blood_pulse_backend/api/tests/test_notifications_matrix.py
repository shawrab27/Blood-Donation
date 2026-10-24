from unittest.mock import patch
from django.contrib.auth.models import User
from django.test import TestCase
from api.models import Notification, UserNotificationState, UserDevice, DonorProfile
from api.services.notifications import notify, NOTIFICATION_MATRIX
from api.services.notify import send_fcm_multicast_batches


class NotificationsMatrixTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testuser_notif',
            email='testuser@example.com',
            password='Password123'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='01799887766',
            district='Dhaka',
            fcm_token='valid_test_token_12345'
        )
        self.device = UserDevice.objects.create(
            user=self.user,
            device_id='device_notif_1',
            fcm_token='valid_test_token_12345',
            is_revoked=False
        )

    @patch('api.services.notifications.send_push_to_user')
    def test_row_before_push_ordering(self, mock_push):
        """Verifies DB Notification row is written FIRST before FCM push dispatch."""
        row_exists_during_push = []

        def side_effect(user, title, body, data_payload=None):
            # Inspect database at the exact moment push is called
            exists = Notification.objects.filter(user=user, type='emergency_request_new').exists()
            row_exists_during_push.append(exists)
            return {'status': 'sent', 'sent': 1, 'failed': 0}

        mock_push.side_effect = side_effect

        notif = notify(
            user=self.user,
            type='emergency_request_new',
            payload={'title': 'Urgent Blood Needed', 'body': 'O+ needed at Dhaka Medical'}
        )

        self.assertIsNotNone(notif)
        self.assertTrue(row_exists_during_push and row_exists_during_push[0])
        self.assertEqual(notif.title, 'Urgent Blood Needed')
        self.assertFalse(notif.is_read)

    @patch('api.services.notifications.send_push_to_user')
    def test_matrix_push_and_bell_permissions(self, mock_push):
        """Validates all matrix rules for push vs bell permissions."""
        mock_push.return_value = {'status': 'sent', 'sent': 1, 'failed': 0}

        # 1. emergency_request_new -> push YES, bell YES
        n1 = notify(self.user, 'emergency_request_new', {'title': 'E1', 'body': 'B1'})
        self.assertIsNotNone(n1)
        mock_push.assert_called()
        mock_push.reset_mock()

        # 2. post_like -> push NO, bell YES
        n2 = notify(self.user, 'post_like', {'title': 'Like', 'body': 'Liked post'})
        self.assertIsNotNone(n2)
        mock_push.assert_not_called()
        mock_push.reset_mock()

        # 3. comment -> push NO, bell YES
        n3 = notify(self.user, 'comment', {'title': 'Comment', 'body': 'New comment'})
        self.assertIsNotNone(n3)
        mock_push.assert_not_called()
        mock_push.reset_mock()

        # 4. tracking_update -> push NO, bell NO (live in-app only)
        n4 = notify(self.user, 'tracking_update', {'title': 'Moving', 'body': 'On the way'})
        self.assertIsNone(n4)
        mock_push.assert_not_called()
        mock_push.reset_mock()

        # 5. chat_message -> push YES, bell YES
        n5 = notify(self.user, 'chat_message', {'title': 'Chat', 'body': 'Hello'})
        self.assertIsNotNone(n5)
        mock_push.assert_called()
        mock_push.reset_mock()

        # 6. donation_confirmed -> push YES, bell YES
        n6 = notify(self.user, 'donation_confirmed', {'title': 'Done', 'body': 'Verified'})
        self.assertIsNotNone(n6)
        mock_push.assert_called()
        mock_push.reset_mock()

    def test_user_notification_state_derived_from_rows(self):
        """Ensures UserNotificationState unread count matches actual unread Notification rows."""
        self.assertEqual(UserNotificationState.get_unread_for_user(self.user), 0)

        # Create 3 unread notifications
        Notification.objects.create(user=self.user, title='N1', body='B1', type='t', is_read=False, created_at='2026-01-01T00:00:00Z')
        Notification.objects.create(user=self.user, title='N2', body='B2', type='t', is_read=False, created_at='2026-01-01T00:00:00Z')
        Notification.objects.create(user=self.user, title='N3', body='B3', type='t', is_read=True, created_at='2026-01-01T00:00:00Z')

        count = UserNotificationState.get_unread_for_user(self.user)
        self.assertEqual(count, 2)
        state = UserNotificationState.objects.get(user=self.user)
        self.assertEqual(state.unread_count, 2)

    @patch('firebase_admin.messaging.send_each_for_multicast')
    def test_token_cleanup_on_unregistered_fcm(self, mock_multicast):
        """Verifies invalid or unregistered tokens are wiped from UserDevice and DonorProfile."""
        class MockException(Exception):
            pass

        class MockResponse:
            def __init__(self, success, exc=None):
                self.success = success
                self.exception = exc
                self.message_id = 'msg_1' if success else None

        class MockBatchResponse:
            def __init__(self):
                self.success_count = 0
                self.failure_count = 1
                self.responses = [MockResponse(False, MockException('Requested entity was not found (unregistered).'))]

        mock_multicast.return_value = MockBatchResponse()

        tokens_with_donors = [(self.profile.fcm_token, self.profile)]
        res = send_fcm_multicast_batches(tokens_with_donors, 'Test', 'Body')

        self.assertEqual(res['invalid_tokens_cleared'], 1)
        self.profile.refresh_from_db()
        self.assertIsNone(self.profile.fcm_token)
        self.device.refresh_from_db()
        self.assertIsNone(self.device.fcm_token)
