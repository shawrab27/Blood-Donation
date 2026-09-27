# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from api.models import HealthAccessory

items = HealthAccessory.objects.filter(description_en__icontains='Certified')
for item in items:
    item.description_en = item.description_en.replace('Certified ', '')
    item.save()

print("DB description updated.")
