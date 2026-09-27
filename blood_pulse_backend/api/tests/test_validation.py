# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.core.files.uploadedfile import SimpleUploadedFile
from api.models import DonorProfile
from django.contrib.auth.models import User

class ValidationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_haversine_bounds_get(self):
        response = self.client.get('/api/donors-nearby/', {'lat': '999.99', 'lng': '-999.99'})
        self.assertEqual(response.status_code, 400)
        
    def test_haversine_bounds_post(self):
        response = self.client.post('/api/donors-nearby/', {'lat': '999.99', 'lng': '-999.99'}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_club_upload_size_limit(self):
        # 15MB file
        big_file_data = b'0' * (15 * 1024 * 1024)
        big_file = SimpleUploadedFile('big.jpg', big_file_data, content_type='image/jpeg')
        
        data = {
            'name': 'Test Club',
            'established_year': 2020,
            'contact_number': '1234567890',
            'description': 'test desc',
            'president_name': 'pres',
            'cover_photo': big_file
        }
        response = self.client.post('/api/clubs/register/', data, format='multipart')
        self.assertEqual(response.status_code, 400)
        self.assertIn('cover_photo', response.data.get('errors', {}))

    def test_bmi_negative_weight(self):
        from api.utils import calculate_bmi
        result = calculate_bmi(weight_kg=-70, height_cm=170)
        self.assertEqual(result, "invalid input")
