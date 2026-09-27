# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()
from api.models import BloodRequest
r = BloodRequest.objects.get(id=7)
print(f"ID: {r.id} | Blood Group: {r.blood_group} | Timestamp: {r.created_at} | Status: {r.status} | Patient: {r.patient_name}")
