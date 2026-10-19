# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from unittest.mock import patch, MagicMock
import requests
from django.core.cache import cache
from rest_framework.test import APITestCase
from rest_framework import status
from api.services.routing import get_route_or_fallback, estimate_eta_and_distance, FALLBACK_SPEED_KMH, DETOUR_FACTOR
from api.services.geo import haversine_distance


class OsmRoutingServiceTests(APITestCase):
    def setUp(self):
        cache.clear()

    def tearDown(self):
        cache.clear()

    @patch('api.services.routing.requests.get')
    def test_osrm_routing_success(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'code': 'Ok',
            'routes': [
                {
                    'distance': 5000.0,  # 5 km
                    'duration': 600.0,   # 10 min
                    'geometry': {'coordinates': [[90.41, 23.81], [90.42, 23.82]]}
                }
            ]
        }
        mock_get.return_value = mock_response

        res = get_route_or_fallback(23.81, 90.41, 23.82, 90.42, overview=True)
        self.assertEqual(res['distance_km'], 5.0)
        self.assertEqual(res['duration_min'], 10)
        self.assertEqual(res['provider'], 'osrm')
        self.assertFalse(res['is_fallback'])
        self.assertEqual(len(res['coordinates']), 2)

    @patch('api.services.routing.requests.get')
    def test_osrm_routing_timeout_fallback(self, mock_get):
        mock_get.side_effect = requests.exceptions.Timeout("OSRM timeout")

        from_lat, from_lng = 23.8103, 90.4125
        to_lat, to_lng = 23.7259, 90.3976
        res = get_route_or_fallback(from_lat, from_lng, to_lat, to_lng, overview=False)

        straight_line = haversine_distance(from_lat, from_lng, to_lat, to_lng)
        expected_distance = round(straight_line * DETOUR_FACTOR, 2)
        expected_duration = max(1, round((expected_distance / FALLBACK_SPEED_KMH) * 60.0))

        self.assertEqual(res['distance_km'], expected_distance)
        self.assertEqual(res['duration_min'], expected_duration)
        self.assertEqual(res['provider'], 'straight_line_fallback')
        self.assertTrue(res['is_fallback'])

    @patch('api.services.routing.requests.get')
    def test_osrm_routing_caching(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'routes': [{'distance': 3000.0, 'duration': 300.0, 'geometry': {'coordinates': []}}]
        }
        mock_get.return_value = mock_response

        # First call
        res1 = get_route_or_fallback(23.81, 90.41, 23.82, 90.42)
        # Second call should hit cache without calling requests.get again
        res2 = get_route_or_fallback(23.81, 90.41, 23.82, 90.42)

        self.assertEqual(mock_get.call_count, 1)
        self.assertEqual(res1, res2)

    @patch('api.services.routing.requests.get')
    def test_estimate_eta_and_distance_helper(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'routes': [{'distance': 10000.0, 'duration': 1200.0, 'geometry': {'coordinates': []}}]
        }
        mock_get.return_value = mock_response

        dist, eta = estimate_eta_and_distance(23.81, 90.41, 23.85, 90.45)
        self.assertEqual(dist, 10.0)
        self.assertEqual(eta, 20)


from django.contrib.auth import get_user_model

User = get_user_model()


class RouteViewApiTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(username='osm_tester', password='pw')
        self.client.force_authenticate(user=self.user)

    def tearDown(self):
        cache.clear()

    def test_anonymous_request_returns_401(self):
        self.client.force_authenticate(user=None)
        resp1 = self.client.get('/api/osm/geocode/?q=Dhaka')
        resp2 = self.client.get('/api/osm/reverse/?lat=23.81&lng=90.41')
        resp3 = self.client.get('/api/osm/route/?from_lat=23.81&from_lng=90.41&to_lat=23.82&to_lng=90.42')
        self.assertEqual(resp1.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(resp2.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(resp3.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_geocode_query_length_validation(self):
        # Missing q
        resp = self.client.get('/api/osm/geocode/')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

        # Too short (< 2 chars)
        resp = self.client.get('/api/osm/geocode/?q=a')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Query length', resp.json()['error'])

        # Too long (> 100 chars)
        long_q = 'a' * 105
        resp = self.client.get(f'/api/osm/geocode/?q={long_q}')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Query length', resp.json()['error'])

    def test_reverse_geocode_bounds_validation(self):
        # Invalid format
        resp = self.client.get('/api/osm/reverse/?lat=abc&lng=def')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

        # Out of bounds lat (> 90)
        resp = self.client.get('/api/osm/reverse/?lat=99.0&lng=90.0')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('out of bounds', resp.json()['error'])

    def test_route_missing_parameters_returns_400(self):
        response = self.client.get('/api/osm/route/', {'from_lat': 23.81})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.data)

    def test_route_invalid_coordinate_format_returns_400(self):
        response = self.client.get('/api/osm/route/', {
            'from_lat': 'invalid',
            'from_lng': 90.41,
            'to_lat': 23.82,
            'to_lng': 90.42
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_route_out_of_bounds_returns_400(self):
        response = self.client.get('/api/osm/route/', {
            'from_lat': 95.0,
            'from_lng': 90.41,
            'to_lat': 23.82,
            'to_lng': 90.42
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('out of bounds', response.data['error'])

    @patch('api.services.routing.requests.get')
    def test_route_success_returns_200_with_route_info(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'routes': [{'distance': 4200.0, 'duration': 480.0, 'geometry': {'coordinates': [[90.4, 23.8], [90.5, 23.9]]}}]
        }
        mock_get.return_value = mock_response

        response = self.client.get('/api/osm/route/', {
            'from_lat': 23.81,
            'from_lng': 90.41,
            'to_lat': 23.82,
            'to_lng': 90.42,
            'overview': 'true'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['distance_km'], 4.2)
        self.assertEqual(response.data['duration_min'], 8)
        self.assertIn('coordinates', response.data)

    @patch('api.services.routing.requests.get')
    def test_osm_proxy_throttle_enforcement(self, mock_get):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'routes': [{'distance': 1000.0, 'duration': 120.0, 'geometry': {'coordinates': []}}]
        }
        mock_get.return_value = mock_response

        # OSMProxyThrottle rate is 10/min. 11th request should trigger 429.
        status_codes = []
        for i in range(12):
            resp = self.client.get('/api/osm/route/', {
                'from_lat': 23.81 + (i * 0.001),
                'from_lng': 90.41,
                'to_lat': 23.82,
                'to_lng': 90.42,
            })
            status_codes.append(resp.status_code)

        self.assertIn(status.HTTP_429_TOO_MANY_REQUESTS, status_codes)

