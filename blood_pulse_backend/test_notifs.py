# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from api.models import Notification
from rest_framework.test import APIClient

User = get_user_model()
u1, _ = User.objects.get_or_create(username='notif_user1')
u2, _ = User.objects.get_or_create(username='notif_user2')

# Create notifications
Notification.objects.create(user=u1, title='User 1 Notif', body='Hello 1', type='GENERAL')
Notification.objects.create(user=u2, title='User 2 Notif', body='Hello 2', type='REQUEST')

client = APIClient()
client.force_authenticate(user=u1)
response = client.get('/api/notifications/')

import json
print("User 1 fetching notifications...")
print("Response STATUS:", response.status_code)
print(json.dumps(response.data, indent=2))

client.force_authenticate(user=u2)
response2 = client.get('/api/notifications/')
print("\nUser 2 fetching notifications...")
print("Response STATUS:", response2.status_code)
print(json.dumps(response2.data, indent=2))
