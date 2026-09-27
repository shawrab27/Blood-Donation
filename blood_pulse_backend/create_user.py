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
email = "testuser@example.com"

# Create or get user
user, created = User.objects.get_or_create(username=username, defaults={"email": email})
user.set_password(password)
user.save()

# Ensure DonorProfile exists (if required by the app)
profile, p_created = DonorProfile.objects.get_or_create(
    user=user,
    defaults={
        "blood_group": "A+",
        "phone": "01700000000",
        "district": "Dhaka",
        "date_of_birth": "1990-01-01",
        "weight_kg": 65,
        "is_available": True
    }
)

print(f"Created/Updated User: {username} / {password}")
