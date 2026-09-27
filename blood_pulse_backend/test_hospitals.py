# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client
from api.models import Hospital

Hospital.objects.get_or_create(
    name="Test Hospital", 
    address="Test Address", 
    district="Dhaka"
)

c = Client()
res = c.get('/api/hospitals/')
data = res.json()
if 'results' in data and len(data['results']) > 0:
    print(data['results'][0].keys())
    print(data['results'][0])
