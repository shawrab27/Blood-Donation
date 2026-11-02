# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from api.models import FeatureFlag, flag_enabled


class W0bFoundationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user_a = User.objects.create_user(username='flag_user_a', password='Password123!')
        self.user_b = User.objects.create_user(username='flag_user_b', password='Password123!')

    def test_item1_feature_flags_lifecycle_and_endpoint(self):
        """
        Tests FeatureFlag logic and /api/public/config/ behavior:
        1. Off by default: enabled=False returns False.
        2. Allowlist on: enabled=True with allowed_user_ids returns True for user in list, False for others.
        3. Kill switch off: enabled=False overrides the allowlist (returns False even if user is in allowed_user_ids).
        4. Global enable: enabled=True with empty allowed_user_ids returns True for everyone.
        5. Helper flag_enabled(name, user) safe on missing flag.
        6. /api/public/config/ returns only flag booleans for the requesting user, never user lists.
        """
        # 1. Off by default
        flag_default = FeatureFlag.objects.create(name='beta_feature')
        self.assertFalse(flag_default.enabled)
        self.assertFalse(flag_default.is_active_for_user(self.user_a))
        self.assertFalse(flag_enabled('beta_feature', self.user_a))

        # 2. Allowlist on
        flag_allowlist = FeatureFlag.objects.create(
            name='pilot_program',
            enabled=True,
            allowed_user_ids=[self.user_a.id]
        )
        self.assertTrue(flag_allowlist.is_active_for_user(self.user_a))
        self.assertTrue(flag_enabled('pilot_program', self.user_a))
        self.assertFalse(flag_allowlist.is_active_for_user(self.user_b))
        self.assertFalse(flag_enabled('pilot_program', self.user_b))
        self.assertFalse(flag_allowlist.is_active_for_user(None)) # anonymous

        # 3. Kill switch off: enabled=False overrides the allowlist
        flag_allowlist.enabled = False
        flag_allowlist.save(update_fields=['enabled'])
        self.assertFalse(flag_allowlist.is_active_for_user(self.user_a))
        self.assertFalse(flag_enabled('pilot_program', self.user_a))

        # 4. Global enable: enabled=True with empty allowed_user_ids
        flag_global = FeatureFlag.objects.create(name='global_v2', enabled=True, allowed_user_ids=[])
        self.assertTrue(flag_global.is_active_for_user(self.user_a))
        self.assertTrue(flag_global.is_active_for_user(self.user_b))
        self.assertTrue(flag_global.is_active_for_user(None))

        # 5. Helper safe on non-existent flag
        self.assertFalse(flag_enabled('non_existent_flag', self.user_a))

        # 6. /api/public/config/ endpoint check
        # A. Anonymous user
        resp_anon = self.client.get('/api/public/config/')
        self.assertEqual(resp_anon.status_code, status.HTTP_200_OK)
        data_anon = resp_anon.json()
        self.assertIn('flags', data_anon)
        self.assertIsInstance(data_anon['flags'], dict)
        self.assertIn('beta_feature', data_anon['flags'])
        self.assertFalse(data_anon['flags']['beta_feature'])
        self.assertTrue(data_anon['flags']['global_v2'])
        # Must NEVER leak allowed_user_ids
        self.assertNotIn('allowed_user_ids', data_anon)
        self.assertNotIn('allowed_user_ids', str(data_anon))

        # B. Authenticated user in allowlist (re-enable pilot_program)
        flag_allowlist.enabled = True
        flag_allowlist.save(update_fields=['enabled'])
        self.client.force_authenticate(user=self.user_a)
        resp_user_a = self.client.get('/api/public/config/')
        data_user_a = resp_user_a.json()
        self.assertTrue(data_user_a['flags']['pilot_program'])

        # C. Authenticated user NOT in allowlist
        self.client.force_authenticate(user=self.user_b)
        resp_user_b = self.client.get('/api/public/config/')
        data_user_b = resp_user_b.json()
        self.assertFalse(data_user_b['flags']['pilot_program'])

    def test_item2_tick_heartbeats_and_health_endpoint(self):
        """
        Tests tick heartbeat recording and GET /api/health/ticks/:
        - Initially returns {"wave": "stale", "maintenance": "stale"}
        - Updating wave or maintenance records heartbeat and transitions status to "ok"
        - Heartbeats older than TICK_STALE_SECONDS transition back to "stale"
        """
        import os
        from datetime import timedelta
        from django.utils import timezone
        from api.models import TickHeartbeat, record_tick_heartbeat

        # 1. Initially no records -> both stale
        TickHeartbeat.objects.all().delete()
        resp_initial = self.client.get('/api/health/ticks/')
        self.assertEqual(resp_initial.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_initial.json(), {'wave': 'stale', 'maintenance': 'stale'})

        # 2. Record wave heartbeat -> wave ok, maintenance stale
        record_tick_heartbeat('wave')
        resp_wave = self.client.get('/api/health/ticks/')
        self.assertEqual(resp_wave.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_wave.json(), {'wave': 'ok', 'maintenance': 'stale'})

        # 3. Record maintenance heartbeat -> both ok
        record_tick_heartbeat('maintenance')
        resp_both = self.client.get('/api/health/ticks/')
        self.assertEqual(resp_both.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_both.json(), {'wave': 'ok', 'maintenance': 'ok'})

        # 4. Check stale expiration when older than TICK_STALE_SECONDS (default 300)
        stale_time = timezone.now() - timedelta(seconds=350)
        TickHeartbeat.objects.filter(tick_name='wave').update(last_success_at=stale_time)
        resp_stale = self.client.get('/api/health/ticks/')
        self.assertEqual(resp_stale.status_code, status.HTTP_200_OK)
        self.assertEqual(resp_stale.json(), {'wave': 'stale', 'maintenance': 'ok'})

