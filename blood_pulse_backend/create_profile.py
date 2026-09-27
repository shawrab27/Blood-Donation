# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth.models import User
from api.models import DonorProfile

user = User.objects.get(username="testuser")
try:
    DonorProfile.objects.filter(user=user).delete()
    DonorProfile.objects.create(user=user, phone_number="01799999999", blood_group="A+")
    print("Profile created!")
except Exception as e:
    print(e)
