# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import django
from io import BytesIO
from PIL import Image

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from rest_framework.test import APIClient

def test_malicious_upload():
    client = APIClient()
    
    img = Image.new('RGB', (100, 100), color = 'red')
    fake_file = BytesIO()
    img.save(fake_file, format='JPEG')
    
    # Pad to 16MB
    fake_file.write(b'0' * (16 * 1024 * 1024))
    fake_file.seek(0)
    fake_file.name = 'huge_image.jpg'
    
    print(f"File size: {len(fake_file.getvalue()) / (1024*1024):.2f} MB")
    
    data = {
        'name': 'Test Club Huge',
        'description': 'A test club',
        'president_name': 'Test',
        'contact_number': '1234',
        'cover_photo': fake_file
    }
    
    response = client.post('/api/clubs/register/', data, format='multipart')
    print(f"Upload Status Code: {response.status_code}")
    print(f"Response: {response.data}")

if __name__ == '__main__':
    test_malicious_upload()
