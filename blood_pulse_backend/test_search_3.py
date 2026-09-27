# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client

c = Client()
res = c.get('/api/donors/search/?blood_group=A%2B&district=Dhaka')
data = res.json()
if data.get('results'):
    print(data['results'][0].keys())
