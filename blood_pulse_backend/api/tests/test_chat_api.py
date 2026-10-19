# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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
    DirectMessage,
)


class RealtimeChatAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.requester_user = User.objects.create_user(username='chat_req', password='password123', first_name='Rahim')
        self.donor_user = User.objects.create_user(username='chat_donor', password='password123', first_name='Karim')
        self.other_user = User.objects.create_user(username='chat_other', password='password123', first_name='Stranger')

        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801711111111',
            is_available=True,
        )

        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
        )

        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Jamal',
            blood_group='A+',
            units_needed=1,
            hospital=self.hospital,
            contact_phone='+8801811111111',
            status='ACTIVE',
        )

        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
        )

    def test_participant_can_send_and_read_messages(self):
        # Requester sends message to Donor
        self.client.force_authenticate(user=self.requester_user)
        send_resp = self.client.post(f'/api/chat/{self.acceptance.id}/messages/', {
            'content': 'Hello, are you on your way?',
            'message_type': 'TEXT',
        })
        self.assertEqual(send_resp.status_code, status.HTTP_201_CREATED)
        msg_data = send_resp.json()
        self.assertEqual(msg_data['content'], 'Hello, are you on your way?')
        self.assertEqual(msg_data['status'], 'SENT')
        self.assertTrue(msg_data['is_mine'])

        # Donor fetches messages -> message status transitions from SENT to DELIVERED
        self.client.force_authenticate(user=self.donor_user)
        get_resp = self.client.get(f'/api/chat/{self.acceptance.id}/messages/')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        results = get_resp.json()['results']
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['status'], 'DELIVERED')
        self.assertFalse(results[0]['is_mine'])

    def test_unauthorized_user_forbidden(self):
        self.client.force_authenticate(user=self.other_user)

        # GET forbidden
        get_resp = self.client.get(f'/api/chat/{self.acceptance.id}/messages/')
        self.assertEqual(get_resp.status_code, status.HTTP_403_FORBIDDEN)

        # POST forbidden
        post_resp = self.client.post(f'/api/chat/{self.acceptance.id}/messages/', {
            'content': 'I am eavesdropping',
        })
        self.assertEqual(post_resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_message_read_receipt(self):
        msg = DirectMessage.objects.create(
            acceptance=self.acceptance,
            sender=self.requester_user,
            recipient=self.donor_user,
            content='Please hurry, emergency surgery starting soon.',
            status='SENT',
        )

        # Recipient marks read
        self.client.force_authenticate(user=self.donor_user)
        read_resp = self.client.post(f'/api/chat/{self.acceptance.id}/messages/{msg.id}/read/')
        self.assertEqual(read_resp.status_code, status.HTTP_200_OK)

        msg.refresh_from_db()
        self.assertEqual(msg.status, 'READ')
        self.assertIsNotNone(msg.read_at)
        self.assertIsNotNone(msg.delivered_at)

    def test_message_report(self):
        msg = DirectMessage.objects.create(
            acceptance=self.acceptance,
            sender=self.donor_user,
            recipient=self.requester_user,
            content='Give me extra cash or I will not show up.',
            status='SENT',
        )

        self.client.force_authenticate(user=self.requester_user)
        report_resp = self.client.post(f'/api/chat/{self.acceptance.id}/messages/{msg.id}/report/', {
            'reason': 'Extortion attempt',
        })
        self.assertEqual(report_resp.status_code, status.HTTP_200_OK)

        msg.refresh_from_db()
        self.assertTrue(msg.is_reported)
        self.assertEqual(msg.report_reason, 'Extortion attempt')

    def test_message_delete_own_message(self):
        msg = DirectMessage.objects.create(
            acceptance=self.acceptance,
            sender=self.requester_user,
            recipient=self.donor_user,
            content='Oops typo message',
            status='SENT',
        )

        # Donor cannot delete requester message
        self.client.force_authenticate(user=self.donor_user)
        del_fail = self.client.delete(f'/api/chat/{self.acceptance.id}/messages/{msg.id}/')
        self.assertEqual(del_fail.status_code, status.HTTP_403_FORBIDDEN)

        # Requester can delete own message
        self.client.force_authenticate(user=self.requester_user)
        del_ok = self.client.delete(f'/api/chat/{self.acceptance.id}/messages/{msg.id}/')
        self.assertEqual(del_ok.status_code, status.HTTP_204_NO_CONTENT)

        self.assertFalse(DirectMessage.objects.filter(id=msg.id).exists())

    def test_voice_message_upload(self):
        self.client.force_authenticate(user=self.donor_user)

        dummy_audio = SimpleUploadedFile(
            "voice_note.m4a",
            b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00isomiso2",
            content_type="audio/m4a",
        )

        upload_resp = self.client.post(
            f'/api/chat/{self.acceptance.id}/voice/',
            {'voice_file': dummy_audio, 'duration_seconds': 12},
            format='multipart',
        )
        self.assertEqual(upload_resp.status_code, status.HTTP_201_CREATED)
        data = upload_resp.json()
        self.assertIn('chat_voice', data['voice_url'])
        self.assertEqual(data['duration_seconds'], 12)

        # Send voice message with the returned URL
        send_resp = self.client.post(f'/api/chat/{self.acceptance.id}/messages/', {
            'content': '',
            'message_type': 'VOICE',
            'voice_url': data['voice_url'],
            'voice_duration_seconds': 12,
        })
        self.assertEqual(send_resp.status_code, status.HTTP_201_CREATED)
        self.assertEqual(send_resp.json()['message_type'], 'VOICE')

    def test_voice_message_upload_503_when_persistent_storage_missing_in_production(self):
        """P0-2: When DEBUG=False and no persistent remote storage configured, returns 503 VOICE_UNAVAILABLE."""
        from django.conf import settings
        from unittest.mock import patch

        self.client.force_authenticate(user=self.donor_user)
        dummy_audio = SimpleUploadedFile(
            "voice_note.m4a",
            b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00isomiso2",
            content_type="audio/m4a",
        )

        with patch.object(settings, 'DEBUG', False), patch.object(settings, 'IS_TESTING', False):
            with patch('api.services.storage.is_persistent_remote_configured', return_value=False):
                resp = self.client.post(
                    f'/api/chat/{self.acceptance.id}/voice/',
                    {'voice_file': dummy_audio, 'duration_seconds': 15},
                    format='multipart',
                )
                self.assertEqual(resp.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
                self.assertEqual(resp.json()['code'], 'VOICE_UNAVAILABLE')
                self.assertIn('persistent storage is not configured', resp.json()['detail'])

    def test_cleanup_chat_voice_command(self):
        from datetime import timedelta
        from django.utils import timezone
        from django.core.management import call_command
        import io

        msg = DirectMessage.objects.create(
            acceptance=self.acceptance,
            sender=self.donor_user,
            recipient=self.requester_user,
            content='',
            message_type='VOICE',
            voice_url='https://storage.bloodpulse.local/chat_voice/test/dummy.m4a',
            voice_duration_seconds=10,
        )
        # Update created_at to 10 days ago (older than 7-day default)
        past_date = timezone.now() - timedelta(days=10)
        DirectMessage.objects.filter(id=msg.id).update(created_at=past_date)

        out = io.StringIO()
        call_command('cleanup_chat_voice', stdout=out)
        self.assertIn("Cleaned up", out.getvalue())

        msg.refresh_from_db()
        self.assertIsNone(msg.voice_url)

    def test_direct_messages_query_count_constant_for_50_messages(self):
        """P1-1: Verifies select_related('sender', 'recipient') avoids N+1 queries for 50 messages."""
        from django.test.utils import CaptureQueriesContext
        from django.db import connection

        # Bulk create 50 messages alternating between sender and recipient
        messages = [
            DirectMessage(
                acceptance=self.acceptance,
                sender=self.requester_user if i % 2 == 0 else self.donor_user,
                recipient=self.donor_user if i % 2 == 0 else self.requester_user,
                content=f"Message {i}",
                status='DELIVERED',
            )
            for i in range(50)
        ]
        DirectMessage.objects.bulk_create(messages)

        self.client.force_authenticate(user=self.requester_user)

        with CaptureQueriesContext(connection) as queries:
            response = self.client.get(f'/api/chat/{self.acceptance.id}/messages/?limit=50')
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            self.assertEqual(len(response.json()['results']), 50)

        # Without select_related, it would be > 100 queries (2 queries per message for sender and recipient).
        # With select_related, queries remain constant and <= 6 regardless of message count.
        self.assertLessEqual(len(queries), 6)

