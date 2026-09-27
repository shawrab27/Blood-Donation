# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os, django, sys
sys.path.append(os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
import json

User = get_user_model()
user = User.objects.first()
if not user:
    user = User.objects.create(username="testuser", phone_number="01711111111", is_profile_complete=True)

refresh = RefreshToken.for_user(user)
print(json.dumps({"access": str(refresh.access_token), "refresh": str(refresh)}))
