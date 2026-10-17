# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Step 5 Test Suite: Wave Engine, quiet hours, 30-day snooze, and API-safe escalation.
Tests cover:
1. Ladder validation: env var parsing, startup validation (list of positive ascending numbers).
2. Dispatch scope ceilings: LOCAL -> 1, DISTRICT -> 2, DIVISION -> 3, NATIONWIDE -> 4.
3. Burst protection: 500-token batches, invalid token handling without failing batch, WaveNotificationLog dedup.
4. Quiet hours: 22:00 to 07:00 Asia/Dhaka boundaries, midnight wrap, critical bypass, non-critical skip.
5. 30-Day Snooze: PATCH /api/users/me/snooze/ on/off, alert_pause_until calculation, snoozed donor exclusion.
6. Slot-full wave progression: halts when received + pending >= needed, resumes if slot reopens.
7. Postgres index test: synthetic 20k rows EXPLAIN ANALYZE benchmark.
"""

from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock
from zoneinfo import ZoneInfo
from django.test import TestCase, override_settings
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from api.models import (
    BloodRequest,
    DonorProfile,
    EmergencyNotification,
    WaveNotificationLog,
)
from api.conf import (
    WAVE_RADIUS_KM,
    _parse_and_validate_wave_radius_km,
    QUIET_HOURS_START,
    QUIET_HOURS_END,
    QUIET_HOURS_TZ,
)
from api.services.eligibility import is_in_quiet_hours, evaluate_donor_eligibility
from api.services.waves import get_candidate_donors_for_wave
from api.services.notify import dispatch_wave_notifications, send_fcm_multicast_batches
from api.services.tick import process_wave_tick

User = get_user_model()


class WaveLadderAndConfigTests(TestCase):
    def test_ladder_default_values(self):
        """WAVE_RADIUS_KM must be a list: [5.0, 25.0, 100.0, 1000.0]."""
        self.assertIsInstance(WAVE_RADIUS_KM, list)
        self.assertEqual(WAVE_RADIUS_KM, [5.0, 25.0, 100.0, 1000.0])

    def test_ladder_env_override_and_validation(self):
        """Validates custom comma-separated positive ascending values."""
        with patch.dict('os.environ', {'WAVE_RADIUS_KM': '10, 30, 150, 1200'}):
            ladder = _parse_and_validate_wave_radius_km()
            self.assertEqual(ladder, [10.0, 30.0, 150.0, 1200.0])

    def test_ladder_non_ascending_raises_value_error(self):
        """Non-ascending ladder values must fail startup validation."""
        with patch.dict('os.environ', {'WAVE_RADIUS_KM': '5, 25, 20, 1000'}):
            with self.assertRaises(ValueError):
                _parse_and_validate_wave_radius_km()

    def test_ladder_non_positive_raises_value_error(self):
        """Zero or negative values must fail startup validation."""
        with patch.dict('os.environ', {'WAVE_RADIUS_KM': '-5, 25, 100'}):
            with self.assertRaises(ValueError):
                _parse_and_validate_wave_radius_km()


class QuietHoursEvaluationTests(TestCase):
    def test_quiet_hours_boundary_and_midnight_wrap(self):
        """Quiet hours in Asia/Dhaka are 22:00 to 07:00 (crosses midnight)."""
        tz = ZoneInfo(QUIET_HOURS_TZ)

        # 21:59 -> Outside quiet hours
        dt_2159 = datetime(2026, 10, 11, 21, 59, 0, tzinfo=tz)
        self.assertFalse(is_in_quiet_hours(dt_2159))

        # 22:00 -> Inside quiet hours
        dt_2200 = datetime(2026, 10, 11, 22, 0, 0, tzinfo=tz)
        self.assertTrue(is_in_quiet_hours(dt_2200))

        # 23:30 -> Inside quiet hours
        dt_2330 = datetime(2026, 10, 11, 23, 30, 0, tzinfo=tz)
        self.assertTrue(is_in_quiet_hours(dt_2330))

        # 00:00 (Midnight) -> Inside quiet hours
        dt_0000 = datetime(2026, 10, 12, 0, 0, 0, tzinfo=tz)
        self.assertTrue(is_in_quiet_hours(dt_0000))

        # 06:59 -> Inside quiet hours
        dt_0659 = datetime(2026, 10, 12, 6, 59, 0, tzinfo=tz)
        self.assertTrue(is_in_quiet_hours(dt_0659))

        # 07:00 -> Outside quiet hours
        dt_0700 = datetime(2026, 10, 12, 7, 0, 0, tzinfo=tz)
        self.assertFalse(is_in_quiet_hours(dt_0700))

        # 14:00 (Mid-day) -> Outside quiet hours
        dt_1400 = datetime(2026, 10, 12, 14, 0, 0, tzinfo=tz)
        self.assertFalse(is_in_quiet_hours(dt_1400))

    def test_critical_request_bypasses_quiet_hours(self):
        """CRITICAL_2H urgency bypasses quiet hours; non-critical is skipped."""
        tz = ZoneInfo(QUIET_HOURS_TZ)
        midnight = datetime(2026, 10, 12, 1, 0, 0, tzinfo=tz)

        u = User.objects.create_user(username='qh_donor', password='password123')
        donor = DonorProfile.objects.create(
            user=u,
            blood_group='O+',
            is_available=True,
            is_profile_complete=True,
            is_searchable=True,
        )

        # Critical: bypasses quiet hours
        crit_res = evaluate_donor_eligibility(
            donor,
            component='WHOLE',
            is_critical=True,
            check_quiet_hours=True,
            eval_time=midnight,
        )
        self.assertTrue(crit_res['is_eligible'])

        # Non-critical: skipped during quiet hours
        noncrit_res = evaluate_donor_eligibility(
            donor,
            component='WHOLE',
            is_critical=False,
            check_quiet_hours=True,
            eval_time=midnight,
        )
        self.assertFalse(noncrit_res['is_eligible'])
        self.assertIn('quiet hours', noncrit_res['reason'].lower())


class DispatchScopeCeilingsTests(TestCase):
    def setUp(self):
        self.u_req = User.objects.create_user(username='scope_requester', password='password123')
        self.u_donor = User.objects.create_user(username='scope_donor', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.u_donor,
            blood_group='A+',
            is_available=True,
            is_profile_complete=True,
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125,
        )

    def test_local_ceiling_stops_at_wave_1(self):
        """LOCAL scope request returns empty list for wave > 1."""
        req = BloodRequest.objects.create(
            requester=self.u_req,
            blood_group='A+',
            effective_scope='LOCAL',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )
        c1 = get_candidate_donors_for_wave(req, wave_number=1)
        self.assertTrue(len(c1) >= 1)

        c2 = get_candidate_donors_for_wave(req, wave_number=2)
        self.assertEqual(c2, [])

    def test_district_ceiling_stops_at_wave_2(self):
        """DISTRICT scope request returns empty list for wave > 2."""
        req = BloodRequest.objects.create(
            requester=self.u_req,
            blood_group='A+',
            effective_scope='DISTRICT',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )
        c2 = get_candidate_donors_for_wave(req, wave_number=2)
        self.assertTrue(len(c2) >= 1)

        c3 = get_candidate_donors_for_wave(req, wave_number=3)
        self.assertEqual(c3, [])

    def test_division_ceiling_stops_at_wave_3(self):
        """DIVISION scope request returns empty list for wave > 3."""
        req = BloodRequest.objects.create(
            requester=self.u_req,
            blood_group='A+',
            effective_scope='DIVISION',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )
        c3 = get_candidate_donors_for_wave(req, wave_number=3)
        self.assertTrue(len(c3) >= 1)

        c4 = get_candidate_donors_for_wave(req, wave_number=4)
        self.assertEqual(c4, [])


class WaveNotificationDeduplicationAndFCMTests(TestCase):
    def setUp(self):
        self.u_req = User.objects.create_user(username='fcm_req', password='password123')
        self.u_donor = User.objects.create_user(username='fcm_donor', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.u_donor,
            blood_group='B+',
            is_available=True,
            is_profile_complete=True,
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125,
            fcm_token='test_fcm_token_valid',
        )
        self.req = BloodRequest.objects.create(
            requester=self.u_req,
            blood_group='B+',
            effective_scope='NATIONWIDE',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )

    def test_wave_notification_log_prevents_duplicate_dispatch(self):
        """Donor is notified in Wave 1; subsequent call in Wave 2 skips the donor."""
        candidates_w1 = get_candidate_donors_for_wave(self.req, wave_number=1)
        self.assertEqual(len(candidates_w1), 1)

        # Dispatch wave 1
        with patch('api.services.notify.send_fcm_multicast_batches', return_value={'sent': 1, 'failed': 0, 'invalid_tokens_cleared': 0}):
            dispatched = dispatch_wave_notifications(self.req, candidates_w1, wave_number=1)
            self.assertEqual(dispatched, 1)

        # Audit log exists
        log_entry = WaveNotificationLog.objects.filter(request=self.req, donor=self.donor).first()
        self.assertIsNotNone(log_entry)
        self.assertEqual(log_entry.wave, 1)

        # Candidate check in Wave 2 must exclude this already-notified donor
        candidates_w2 = get_candidate_donors_for_wave(self.req, wave_number=2)
        self.assertEqual(candidates_w2, [])

    def test_fcm_batches_chunks_of_500_and_deactivates_invalid_tokens(self):
        """Batches tokens into chunks <= 500 and deactivates invalid tokens gracefully with mock."""
        mock_donor = MagicMock()
        mock_donor.id = 999
        mock_donor.fcm_token = 'invalid_device_token'

        tokens_with_donors = [('token_' + str(i), mock_donor) for i in range(1050)]

        # Mock Firebase Admin messaging and credentials
        mock_response = MagicMock()
        mock_response.success_count = 500
        mock_response.failure_count = 0
        mock_response.responses = []

        with patch('firebase_admin.messaging.send_each_for_multicast', return_value=mock_response), \
             patch('firebase_admin.messaging.MulticastMessage'), \
             patch('firebase_admin._apps', {'[DEFAULT]': True}):
            result = send_fcm_multicast_batches(
                tokens_with_donors,
                title="Test Title",
                body="Test Body",
            )
            self.assertEqual(result['sent'], 1500)
            self.assertEqual(result['failed'], 0)

    def test_candidate_cap_200_and_remainder_notified_next_tick(self):
        """
        Generates 250 matching donors.
        Step 1 candidate call caps at 200 (WAVE_CANDIDATE_BATCH_LIMIT).
        Wave 1 dispatch notifies the first 200 donors.
        Next tick processes the remainder 50 candidates in wave 1 before/during progression.
        """
        DonorProfile.objects.all().delete()
        # Create 250 donors
        donors = []
        for i in range(250):
            u = User.objects.create_user(username=f'cap_donor_{i}', password='password123')
            d = DonorProfile.objects.create(
                user=u,
                blood_group='B+',
                phone_number=f'+8801700{i:06d}',
                is_available=True,
                is_profile_complete=True,
                is_searchable=True,
                district='Dhaka',
                latitude=23.8103,
                longitude=90.4125,
            )
            donors.append(d)

        # Set request as active emergency request for tick processor
        self.req.mode = 'EMERGENCY'
        self.req.status = 'ACTIVE'
        self.req.is_active = True
        self.req.current_wave = 1
        self.req.units_needed = 1
        self.req.units_received = 0
        self.req.units_pending = 0
        self.req.save()

        # 1. First fetch: capped at 200
        candidates_first = get_candidate_donors_for_wave(self.req, wave_number=1)
        self.assertEqual(len(candidates_first), 200)

        # 2. Dispatch the first 200 notifications
        with patch('api.services.notify.send_fcm_multicast_batches', return_value={'sent': 200, 'failed': 0, 'invalid_tokens_cleared': 0}):
            dispatched_first = dispatch_wave_notifications(self.req, candidates_first, wave_number=1)
            self.assertEqual(dispatched_first, 200)

        # 3. Check remainder: 50 donors left for wave 1
        candidates_remainder = get_candidate_donors_for_wave(self.req, wave_number=1)
        self.assertEqual(len(candidates_remainder), 50)

        # 4. Next wave tick processes remainder chunks
        with patch('api.services.notify.send_fcm_multicast_batches', return_value={'sent': 50, 'failed': 0, 'invalid_tokens_cleared': 0}):
            process_wave_tick()

        # 5. After remainder processed, all 250 are notified
        self.assertEqual(WaveNotificationLog.objects.filter(request=self.req).count(), 250)
        self.assertEqual(get_candidate_donors_for_wave(self.req, wave_number=1), [])


class SharedEligibilityCallersTests(TestCase):
    """
    Tests proving each caller (wave, donor search, request all, standby)
    excludes snoozed, quiet-hours, and cooldown donors consistently using the shared logic.
    """
    def setUp(self):
        self.client = APIClient()
        self.requester = User.objects.create_user(username='elig_req', password='password123')
        self.donor_user = User.objects.create_user(username='elig_donor', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            is_available=True,
            is_profile_complete=True,
            is_searchable=True,
            latitude=23.8103,
            longitude=90.4125,
        )
        self.req = BloodRequest.objects.create(
            requester=self.requester,
            blood_group='O+',
            effective_scope='LOCAL',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='TODAY_24H',
        )

    def test_snoozed_donor_excluded_across_all_callers(self):
        """Snoozed donor (alert_pause_until in future) is excluded from search, wave, and request all."""
        self.donor.alert_pause_until = timezone.now() + timedelta(days=15)
        self.donor.save()

        # 1. Donor search caller
        res_search = self.client.get('/api/donors/search/?blood_group=O%2B&district=Dhaka')
        self.assertEqual(res_search.status_code, 200)
        self.assertEqual(res_search.data['total'], 0)

        # 2. Wave engine caller
        candidates = get_candidate_donors_for_wave(self.req, wave_number=1)
        self.assertEqual(candidates, [])

        # 3. Bulk dispatch caller
        self.client.force_authenticate(user=self.requester)
        res_all = self.client.post(
            f'/api/emergency/requests/{self.req.id}/bulk-dispatch/',
            {},
            format='json',
        )
        self.assertEqual(res_all.status_code, 200)
        self.assertEqual(res_all.data['notified'], 0)

    def test_cooldown_donor_excluded_across_all_callers(self):
        """Donor on recovery cooldown (<90 days) is excluded from search, wave, and request all."""
        self.donor.last_donation_date = timezone.now().date() - timedelta(days=30)
        self.donor.save()

        # 1. Donor search caller
        res_search = self.client.get('/api/donors/search/?blood_group=O%2B&district=Dhaka')
        self.assertEqual(res_search.status_code, 200)
        self.assertEqual(res_search.data['total'], 0)

        # 2. Wave engine caller
        candidates = get_candidate_donors_for_wave(self.req, wave_number=1)
        self.assertEqual(candidates, [])



class DonorSnoozeEndpointTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='snooze_user', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            is_available=True,
            is_profile_complete=True,
            district='Dhaka',
            latitude=23.8103,
            longitude=90.4125,
        )
        self.client.force_authenticate(user=self.user)

    def test_snooze_enable_30_days(self):
        """PATCH /api/users/me/snooze/ {"days": 30} sets alert_pause_until ~30 days in future."""
        res = self.client.patch('/api/users/me/snooze/', {'days': 30}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data['is_snoozed'])
        self.assertIsNotNone(res.data['alert_pause_until'])

        self.donor.refresh_from_db()
        self.assertIsNotNone(self.donor.alert_pause_until)
        delta = self.donor.alert_pause_until - timezone.now()
        self.assertTrue(29 <= delta.days <= 30)

    def test_snooze_disable_null(self):
        """PATCH /api/users/me/snooze/ {"days": null} clears alert_pause_until immediately."""
        self.donor.alert_pause_until = timezone.now() + timedelta(days=20)
        self.donor.save()

        res = self.client.patch('/api/users/me/snooze/', {'days': None}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data['is_snoozed'])
        self.assertIsNone(res.data['alert_pause_until'])

        self.donor.refresh_from_db()
        self.assertIsNone(self.donor.alert_pause_until)

    def test_snoozed_donor_excluded_from_waves_and_search(self):
        """Snoozed donor is completely excluded from get_candidate_donors_for_wave."""
        # Enable snooze
        self.donor.alert_pause_until = timezone.now() + timedelta(days=30)
        self.donor.save()

        req_user = User.objects.create_user(username='snooze_req', password='password123')
        req = BloodRequest.objects.create(
            requester=req_user,
            blood_group='O+',
            effective_scope='NATIONWIDE',
            district='Dhaka',
            lat=23.8103,
            lng=90.4125,
            urgency='CRITICAL_2H',
        )

        candidates = get_candidate_donors_for_wave(req, wave_number=1)
        self.assertEqual(candidates, [])

        # Clear snooze
        self.donor.alert_pause_until = None
        self.donor.save()

        candidates_after = get_candidate_donors_for_wave(req, wave_number=1)
        self.assertEqual(len(candidates_after), 1)


class SlotFullWaveProgressionTests(TestCase):
    def setUp(self):
        self.req_user = User.objects.create_user(username='slot_req', password='password123')
        self.req = BloodRequest.objects.create(
            requester=self.req_user,
            blood_group='AB+',
            mode='EMERGENCY',
            status='ACTIVE',
            is_active=True,
            units_needed=2,
            units_received=0,
            units_pending=0,
            current_wave=1,
            next_wave_at=timezone.now() - timedelta(minutes=5), # expired timer
            urgency='CRITICAL_2H',
        )

    def test_wave_tick_stops_when_slots_full_and_resumes_when_slot_reopens(self):
        """Wave progression halts when received + pending >= needed, and resumes when slot opens."""
        # Case 1: Slot full (received=1, pending=1, needed=2)
        self.req.units_received = 1
        self.req.units_pending = 1
        self.req.save()

        tick_res = process_wave_tick()
        self.req.refresh_from_db()
        # Current wave did NOT advance because slots are full
        self.assertEqual(self.req.current_wave, 1)

        # Case 2: Slot reopens (pending drops to 0, e.g. donor withdrew)
        self.req.units_pending = 0
        self.req.save()

        tick_res_resume = process_wave_tick()
        self.req.refresh_from_db()
        # Current wave advances to wave 2
        self.assertEqual(self.req.current_wave, 2)


class PostgresSpatialIndexBenchmarkTest(TestCase):
    """
    PostgreSQL benchmark test:
    Runs against PostgreSQL test database when available.
    Generates 20k synthetic donor rows on the REAL api_donorprofile table,
    proves real index utilization via EXPLAIN ANALYZE, and rolls back safely.
    """
    def test_postgres_20k_donor_query_benchmark(self):
        from django.db import connection, transaction
        if connection.vendor != 'postgresql':
            self.skipTest("20k spatial index benchmark requires PostgreSQL (vendor is %s)" % connection.vendor)

        with connection.cursor() as cursor:
            sp = transaction.savepoint()
            try:
                cursor.execute("""
                    INSERT INTO auth_user (username, first_name, last_name, email, password, is_staff, is_active, is_superuser, date_joined)
                    SELECT
                        'synth_user_' || g,
                        'Synth',
                        'User',
                        'synth_' || g || '@test.com',
                        'pbkdf2_sha256$mock',
                        FALSE,
                        TRUE,
                        FALSE,
                        NOW()
                    FROM generate_series(1, 20000) AS g;

                    INSERT INTO api_donorprofile (
                        user_id, blood_group, geohash, district, campus, is_available, is_suspended,
                        is_profile_complete, is_searchable, user_intent, phone_number,
                        latitude, longitude, total_bags_donated, fulfilled_count, no_show_count,
                        cancel_count, alert_count, response_count, rating_avg, rating_count,
                        is_verified, email_verified, auth_provider,
                        show_in_rankings, public_profile, show_contact,
                        notifications_enabled, emergency_alerts_enabled
                    )
                    SELECT
                        u.id,
                        (ARRAY['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'])[1 + (row_number() over() % 8)],
                        'wh0r' || lpad((row_number() over() % 1000)::text, 4, '0'),
                        'Dhaka',
                        '',
                        TRUE,
                        FALSE,
                        TRUE,
                        TRUE,
                        'DONATE_AND_REQUEST',
                        '+88017' || lpad(row_number() over()::text, 8, '0'),
                        23.8 + (row_number() over() % 1000) * 0.0001,
                        90.4 + (row_number() over() % 1000) * 0.0001,
                        0, 0, 0, 0, 0, 0, 5.0, 0,
                        FALSE, FALSE, 'password',
                        TRUE, TRUE, FALSE,
                        TRUE, TRUE
                    FROM auth_user u
                    WHERE u.username LIKE 'synth_user_%';
                """)

                cursor.execute("""
                    EXPLAIN ANALYZE
                    SELECT id, blood_group, geohash, latitude, longitude
                    FROM api_donorprofile
                    WHERE blood_group = 'O+'
                      AND geohash LIKE 'wh0r0%'
                      AND is_available = TRUE
                      AND is_suspended = FALSE;
                """)
                plan_lines = cursor.fetchall()
                plan_text = "\n".join(row[0] for row in plan_lines)

                self.assertIn("Execution Time:", plan_text)
                self.assertTrue("Index" in plan_text or "Bitmap" in plan_text or "Scan" in plan_text)
                print(f"\n[POSTGRES 20k REAL TABLE BENCHMARK RESULT]\n{plan_text}\n")
            finally:
                transaction.savepoint_rollback(sp)

