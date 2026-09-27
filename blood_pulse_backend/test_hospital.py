# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
import json

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from api.models import Hospital
from api.serializers import HospitalSerializer

# Create a mock hospital in memory (don't save it) to see the serializer output format
h = Hospital(id=1, name="Mock Hospital", district="Dhaka", address="123 Road", lat=23.0, lng=90.0, phone="12345", is_verified=True, is_referral_center=False)
serializer = HospitalSerializer(h)
print(json.dumps(serializer.data, indent=2))
