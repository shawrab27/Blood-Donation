# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from api.models import DonorProfile
from django.test import RequestFactory
from api.views_bloodhub import donor_search_view

User = get_user_model()

u1, _ = User.objects.get_or_create(username='real_d1', defaults={'first_name': 'Real Donor 1'})
u2, _ = User.objects.get_or_create(username='real_d2', defaults={'first_name': 'Real Donor 2'})
u3, _ = User.objects.get_or_create(username='hidden_d3', defaults={'first_name': 'Hidden Donor'})

DonorProfile.objects.update_or_create(
    user=u1, 
    defaults={'blood_group': 'A+', 'district': 'Dhaka', 'is_searchable': True, 'is_available': True, 'total_bags_donated': 5, 'phone_number': '+8801900000001'}
)
DonorProfile.objects.update_or_create(
    user=u2, 
    defaults={'blood_group': 'O-', 'district': 'Dhaka', 'is_searchable': True, 'is_available': True, 'total_bags_donated': 2, 'phone_number': '+8801900000002'}
)
DonorProfile.objects.update_or_create(
    user=u3, 
    defaults={'blood_group': 'A+', 'district': 'Dhaka', 'is_searchable': False, 'is_available': True, 'total_bags_donated': 10, 'phone_number': '+8801900000003'}
)

print('Users and profiles created.')

factory = RequestFactory()
request = factory.get('/api/donors/search/', {'blood_group': 'A+', 'district': 'Dhaka'})
response = donor_search_view(request)
import json
print(json.dumps(response.data, indent=2))
