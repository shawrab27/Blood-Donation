# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client
from api.models import DonorProfile
from django.contrib.auth.models import User

# Clean previous test users
User.objects.filter(username__in=['real_searchable', 'real_hidden']).delete()

u1 = User.objects.create(username='real_searchable')
DonorProfile.objects.create(
    user=u1, blood_group='B+', district='Sylhet', phone_number='01811111111', is_available=True, is_searchable=True
)

u2 = User.objects.create(username='real_hidden')
DonorProfile.objects.create(
    user=u2, blood_group='B+', district='Sylhet', phone_number='01822222222', is_available=False, is_searchable=True
)

c = Client()
res = c.get('/api/donors/search/?blood_group=B%2B&district=Sylhet')
data = res.json()
print("Search B+ in Sylhet:")
for r in data.get('results', data):
    print(f"- {r['username']}: {r['blood_group']} in {r['district']} (mask: {r['phone_masked']})")

