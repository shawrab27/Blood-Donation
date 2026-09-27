# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from api.models import Hospital, Division, District

dhaka_div, _ = Division.objects.get_or_create(name="Dhaka")
dhaka_dist, _ = District.objects.get_or_create(name="Dhaka", division=dhaka_div)

sylhet_div, _ = Division.objects.get_or_create(name="Sylhet")
sylhet_dist, _ = District.objects.get_or_create(name="Sylhet", division=sylhet_div)

rajshahi_div, _ = Division.objects.get_or_create(name="Rajshahi")
rajshahi_dist, _ = District.objects.get_or_create(name="Rajshahi", division=rajshahi_div)

Hospital.objects.get_or_create(
    name="Dhaka Medical College Hospital",
    defaults={
        "district": dhaka_dist,
        "division": dhaka_div,
        "address": "Secretariat Road, Dhaka 1000",
        "phone": "02-55165088",
        "is_verified": True,
        "is_referral_center": True
    }
)

Hospital.objects.get_or_create(
    name="Sylhet MAG Osmani Medical College",
    defaults={
        "district": sylhet_dist,
        "division": sylhet_div,
        "address": "Kajalshah, Sylhet 3100",
        "phone": "0821-713667",
        "is_verified": True,
        "is_referral_center": True
    }
)

Hospital.objects.get_or_create(
    name="Rajshahi Medical College Hospital",
    defaults={
        "district": rajshahi_dist,
        "division": rajshahi_div,
        "address": "Rajshahi City",
        "phone": "0721-772150",
        "is_verified": True,
        "is_referral_center": True
    }
)
print("Hospitals seeded.")
