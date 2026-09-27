# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from api.models import DonorProfile, DonationHistory
from rest_framework.test import APIClient

User = get_user_model()
u1, _ = User.objects.get_or_create(username='history_test2', defaults={'first_name': 'History Donor'})

# Create profile
profile, _ = DonorProfile.objects.update_or_create(
    user=u1, 
    defaults={'blood_group': 'B+', 'district': 'Dhaka', 'phone_number': '+8801700000123'}
)

# Create some history
DonationHistory.objects.update_or_create(
    donor=profile,
    date='2026-08-01',
    defaults={'location': 'Dhaka Medical College', 'bags_donated': 1, 'notes': 'Emergency'}
)
DonationHistory.objects.update_or_create(
    donor=profile,
    date='2026-04-10',
    defaults={'location': 'Labaid Hospital', 'bags_donated': 2, 'notes': 'Routine'}
)

client = APIClient()
client.force_authenticate(user=u1)
response = client.get('/api/donors/me/')

import json
print("Response STATUS:", response.status_code)
print(json.dumps(response.data, indent=2))
