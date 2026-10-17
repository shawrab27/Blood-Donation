# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import time
from unittest.mock import patch, MagicMock
from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APITestCase
from rest_framework import status


class CacheScalabilityTests(TestCase):
    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_cache_basic_roundtrip(self):
        cache.set('test_key_scalability', 'bloodpulse_active', 60)
        self.assertEqual(cache.get('test_key_scalability'), 'bloodpulse_active')
        cache.delete('test_key_scalability')
        self.assertIsNone(cache.get('test_key_scalability'))

    def test_cache_ttl_expiry(self):
        cache.set('short_ttl_key', 'temporary_val', 1)
        self.assertEqual(cache.get('short_ttl_key'), 'temporary_val')
        time.sleep(1.1)
        self.assertIsNone(cache.get('short_ttl_key'))

    def test_cache_batch_concurrency_simulation(self):
        # Simulate high-throughput concurrent donor tracking / radar cache lookups
        keys = {f"donor_loc_sim_{i}": f"23.{8100+i},90.{4100+i}" for i in range(100)}
        cache.set_many(keys, timeout=120)

        results = cache.get_many(list(keys.keys()))
        self.assertEqual(len(results), 100)
        for k, v in keys.items():
            self.assertEqual(results.get(k), v)

    def test_cache_increment_decrement_atomic_counter(self):
        cache.set('rate_limit_probe', 0, 60)
        c1 = cache.incr('rate_limit_probe')
        c2 = cache.incr('rate_limit_probe')
        self.assertEqual(c1, 1)
        self.assertEqual(c2, 2)


class CacheHealthEndpointTests(APITestCase):
    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    def test_api_health_cache_endpoint_returns_200(self):
        response = self.client.get('/api/health/cache/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'healthy')
        self.assertTrue(response.data['read_write_verified'])
        self.assertIn('latency_ms', response.data)
        self.assertIn('backend', response.data)

    def test_root_health_cache_endpoint_returns_200(self):
        response = self.client.get('/health/cache/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], 'healthy')
        self.assertTrue(response.data['read_write_verified'])

    @patch('django.core.cache.cache.get')
    def test_cache_health_degraded_when_read_fails(self, mock_get):
        mock_get.return_value = 'unexpected_probe_val'
        response = self.client.get('/api/health/cache/')
        self.assertEqual(response.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
        self.assertEqual(response.data['status'], 'degraded')
        self.assertFalse(response.data['read_write_verified'])

    @patch('django.core.cache.cache.set')
    def test_cache_health_unhealthy_when_exception_thrown(self, mock_set):
        mock_set.side_effect = ConnectionError("Redis server unreachable")
        response = self.client.get('/api/health/cache/')
        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
        self.assertEqual(response.data['status'], 'unhealthy')
        self.assertIn('error', response.data)


class CacheSettingsTierTests(TestCase):
    def test_locmem_fallback_by_default_in_tests(self):
        from django.conf import settings
        self.assertIn('default', settings.CACHES)
        # In test suite, backend is locmem to avoid external dependencies
        self.assertIn('LocMemCache', settings.CACHES['default']['BACKEND'])
