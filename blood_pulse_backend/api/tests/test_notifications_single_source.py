# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from unittest.mock import patch

from api.models import Notification
from api.services.notifications import notify


class NotificationsSingleSourceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='test_user_notif', password='password123')

    @patch('api.services.notifications.send_push_to_user')
    def test_notify_creates_db_row_first(self, mock_push):
        mock_push.return_value = {'status': 'success'}

        payload = {
            'title': 'Emergency Alert',
            'body': 'B+ needed at Dhaka Medical',
            'request_id': '1234',
        }
        notif = notify(self.user, 'emergency_request', payload)

        self.assertIsNotNone(notif.id)
        self.assertEqual(notif.title, 'Emergency Alert')
        self.assertEqual(notif.body, 'B+ needed at Dhaka Medical')
        self.assertEqual(notif.type, 'emergency_request')
        self.assertFalse(notif.is_read)

        # Confirm persisted in DB
        db_notif = Notification.objects.get(id=notif.id)
        self.assertEqual(db_notif.user, self.user)

        # Confirm push called with notification_id
        mock_push.assert_called_once()
        _, kwargs = mock_push.call_args
        self.assertEqual(kwargs['data_payload']['notification_id'], str(notif.id))
        self.assertEqual(kwargs['data_payload']['request_id'], '1234')
