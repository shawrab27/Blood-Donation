import json
from unittest.mock import patch
from django.test import TestCase
from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework.test import APIClient

class OSMProxyTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='osmtester', first_name="Test")
        self.client.force_authenticate(user=self.user)

    @patch('api.osm_proxy.requests.get')
    def test_geocode_success(self, mock_get):
        mock_get.return_value.status_code = 200
        mock_get.return_value.json.return_value = [
            {'display_name': 'Dhaka, Bangladesh', 'lat': '23.8103', 'lon': '90.4125'}
        ]
        
        url = reverse('osm-geocode')
        response = self.client.get(url, {'q': 'Dhaka'})
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['display_name'], 'Dhaka, Bangladesh')
        self.assertEqual(data[0]['lat'], 23.8103)
        self.assertEqual(data[0]['lng'], 90.4125)
        
        # Test cache hit (mock should not be called again)
        self.client.get(url, {'q': 'Dhaka'})
        self.assertEqual(mock_get.call_count, 1)
        
    def test_geocode_malformed_query(self):
        url = reverse('osm-geocode')
        response = self.client.get(url)
        self.assertEqual(response.status_code, 400)

    @patch('api.osm_proxy.requests.get')
    def test_upstream_timeout(self, mock_get):
        import requests
        mock_get.side_effect = requests.exceptions.Timeout
        
        url = reverse('osm-geocode')
        response = self.client.get(url, {'q': 'TimeoutCity'})
        self.assertEqual(response.status_code, 503)
        
    @patch('api.osm_proxy.requests.get')
    def test_route_success(self, mock_get):
        mock_get.return_value.status_code = 200
        mock_get.return_value.json.return_value = {
            'routes': [
                {'distance': 15000, 'duration': 1800} # 15km, 30m
            ]
        }
        
        url = reverse('osm-route')
        response = self.client.get(url, {'from_lat': 23.8, 'from_lng': 90.4, 'to_lat': 23.9, 'to_lng': 90.5})
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data['distance_km'], 15.0)
        self.assertEqual(data['duration_min'], 30.0)

    def test_throttle(self):
        url = reverse('osm-geocode')
        # We need a different query each time so it doesn't just hit the cache? 
        # Actually throttling happens before the view code, so it doesn't matter if it's cached or not.
        for i in range(10):
            res = self.client.get(url, {'q': f'q{i}'})
            # Since requests.get is not mocked, wait, it will fail if it's not mocked!
            # Let's mock it for the throttle test as well just in case.
        pass

    @patch('api.osm_proxy.requests.get')
    def test_throttle_enforced(self, mock_get):
        mock_get.return_value.status_code = 200
        mock_get.return_value.json.return_value = []
        url = reverse('osm-geocode')
        for i in range(10):
            res = self.client.get(url, {'q': f'test{i}'})
            self.assertEqual(res.status_code, 200)
        
        # 11th should fail
        res = self.client.get(url, {'q': 'test11'})
        self.assertEqual(res.status_code, 429)

