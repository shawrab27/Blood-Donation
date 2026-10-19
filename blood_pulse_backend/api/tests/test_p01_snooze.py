"""
Tests for Task P-01: Pause Emergency Alerts (Snooze) toggle and lifecycle.
Verifies:
1. on -> off -> on cycle with explicit 'off' payloads (enable=False, off=True, days=None, days=0).
2. Wave candidate query includes donor right after turning snooze off.
3. Quiet hours logic remains unaffected.
4. ProfileMeView (/api/profile/me/) returns alert_pause_until and emergency_alerts_paused_until.
5. Error rejection on invalid payload.
"""
from datetime import timedelta
import zoneinfo
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import DonorProfile, BloodRequest
from api.services.waves import get_candidate_donors_for_wave


class TaskP01SnoozeTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='snooze_tester',
            password='password123',
            first_name='Snooze',
            last_name='Tester',
            email='snooze@example.com'
        )
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            phone_number='01811223344',
            is_available=True,
            is_profile_complete=True,
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125,
            user_intent='DONATE_AND_REQUEST',
        )
        self.client.force_authenticate(user=self.user)

        self.requester = User.objects.create_user(username='req_tester', password='password123')
        self.req_critical = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='A+',
            effective_scope='NATIONWIDE',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )
        self.req_normal = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='A+',
            effective_scope='NATIONWIDE',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='WITHIN_24H',
        )

    def test_snooze_on_off_on_cycle_with_explicit_off_formats(self):
        # 1. Turn ON for 30 days
        res = self.client.patch('/api/users/me/snooze/', {'days': 30}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['is_snoozed'])
        self.assertIsNotNone(res.data['alert_pause_until'])
        self.donor.refresh_from_db()
        self.assertIsNotNone(self.donor.alert_pause_until)

        # 2. Turn OFF via enable=False
        res = self.client.patch('/api/users/me/snooze/', {'enable': False}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['is_snoozed'])
        self.assertIsNone(res.data['alert_pause_until'])
        self.assertIsNone(res.data['emergency_alerts_paused_until'])
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.alert_pause_until)
        self.assertIsNone(self.donor.emergency_alerts_paused_until)

        # 3. Turn ON for 7 days
        res = self.client.patch('/api/users/me/snooze/', {'days': 7}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['is_snoozed'])
        self.assertEqual(res.data['days'], 7)

        # 4. Turn OFF via off=True
        res = self.client.patch('/api/users/me/snooze/', {'off': True}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['is_snoozed'])
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.alert_pause_until)

        # 5. Turn ON for 90 days
        res = self.client.patch('/api/users/me/snooze/', {'days': 90}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['is_snoozed'])

        # 6. Turn OFF via days=0
        res = self.client.patch('/api/users/me/snooze/', {'days': 0}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['is_snoozed'])
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.alert_pause_until)

        # 7. Turn OFF via days=None
        self.donor.alert_pause_until = timezone.now() + timedelta(days=10)
        self.donor.save()
        res = self.client.patch('/api/users/me/snooze/', {'days': None}, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['is_snoozed'])
        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.alert_pause_until)

    def test_wave_candidate_query_includes_user_right_after_off(self):
        # When ON -> excluded from wave candidates
        self.client.patch('/api/users/me/snooze/', {'days': 30}, format='json')
        candidates_snoozed = get_candidate_donors_for_wave(self.req_critical, wave_number=1)
        self.assertEqual(candidates_snoozed, [])

        # Turn OFF -> immediately included in wave candidates
        res_off = self.client.patch('/api/users/me/snooze/', {'enable': False}, format='json')
        self.assertEqual(res_off.status_code, status.HTTP_200_OK)
        self.assertFalse(res_off.data['is_snoozed'])

        candidates_active = get_candidate_donors_for_wave(self.req_critical, wave_number=1)
        self.assertEqual(len(candidates_active), 1)
        self.assertEqual(candidates_active[0]['donor'].id, self.donor.id)

    def test_quiet_hours_unaffected_after_snooze_off(self):
        # Clear snooze
        self.client.patch('/api/users/me/snooze/', {'enable': False}, format='json')

        # Evaluate at 23:00 Dhaka time (Quiet hours: 22:00 - 07:00)
        tz_dhaka = zoneinfo.ZoneInfo("Asia/Dhaka")
        quiet_time = timezone.now().astimezone(tz_dhaka).replace(hour=23, minute=0, second=0, microsecond=0)

        # Non-critical request must still respect quiet hours (candidate excluded)
        c_normal = get_candidate_donors_for_wave(self.req_normal, wave_number=1, eval_time=quiet_time)
        self.assertEqual(c_normal, [])

        # Critical request bypasses quiet hours (candidate included)
        c_critical = get_candidate_donors_for_wave(self.req_critical, wave_number=1, eval_time=quiet_time)
        self.assertEqual(len(c_critical), 1)
        self.assertEqual(c_critical[0]['donor'].id, self.donor.id)

    def test_profile_me_get_includes_snooze_and_persists(self):
        # 1. Turn ON snooze
        self.client.patch('/api/users/me/snooze/', {'days': 14}, format='json')

        # 2. GET /api/profile/me/ must return alert_pause_until and emergency_alerts_paused_until
        res_profile = self.client.get('/api/profile/me/')
        self.assertEqual(res_profile.status_code, status.HTTP_200_OK)
        self.assertIn('alert_pause_until', res_profile.data)
        self.assertIn('emergency_alerts_paused_until', res_profile.data)
        self.assertIsNotNone(res_profile.data['alert_pause_until'])

        # 3. Turn OFF snooze
        self.client.patch('/api/users/me/snooze/', {'enable': False}, format='json')

        # 4. GET /api/profile/me/ must return None for snooze fields
        res_profile_off = self.client.get('/api/profile/me/')
        self.assertEqual(res_profile_off.status_code, status.HTTP_200_OK)
        self.assertIsNone(res_profile_off.data['alert_pause_until'])
        self.assertIsNone(res_profile_off.data['emergency_alerts_paused_until'])

    def test_snooze_invalid_payload_rejected(self):
        res = self.client.patch('/api/users/me/snooze/', {'days': 'invalid_string'}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', res.data)
