# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client
from api.models import DonorProfile

c = Client()
res = c.get('/api/donors/search/?blood_group=A%2B&district=Dhaka')
print("Status:", res.status_code)
data = res.json()
print("Total found:", data.get('count', len(data)))
for r in data.get('results', data):
    print(f"- {r['blood_group']} in {r['district']}, mask: {r['phone_number_masked']}")
