# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client
from api.models import DonorProfile
from django.contrib.auth.models import User

# Setup some donors
User.objects.filter(username__in=['test_searchable', 'test_hidden']).delete()

u1 = User.objects.create(username='test_searchable')
d1 = DonorProfile.objects.create(
    user=u1, blood_group='A+', district='Dhaka', phone_number='01711111111', is_available=True
)

u2 = User.objects.create(username='test_hidden')
d2 = DonorProfile.objects.create(
    user=u2, blood_group='A+', district='Dhaka', phone_number='01722222222', is_available=False
)

c = Client()
res = c.get('/api/donors/search/?blood_group=A%2B&district=Dhaka')
print("Status:", res.status_code)
data = res.json()
print("Total found:", data['count'])
for r in data['results']:
    print(f"- {r['blood_group']} in {r['district']}, mask: {r['phone_number_masked']}")

