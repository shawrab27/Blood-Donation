# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth.models import User
from api.models import DonorProfile

username = "testuser"
password = "Password123!"

# Get or create user
user, created = User.objects.get_or_create(username=username)
user.set_password(password)
user.save()

# Try to just get or create empty profile with minimum fields
try:
    profile, _ = DonorProfile.objects.get_or_create(user=user)
except Exception as e:
    print(f"Profile creation error: {e}")
    # Maybe we don't even need to force create one if signals handle it
    pass

print(f"Created/Updated User: {username} / {password}")
