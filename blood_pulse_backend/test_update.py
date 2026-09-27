# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import urllib.request
import json
import os
import django

url = "http://127.0.0.1:8000/api/health-accessories/"

def fetch_first():
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        items = data['results'] if 'results' in data else data
        if items:
            return items[0]
    return None

print("Fetching BEFORE edit...")
before = fetch_first()
if before:
    print(f"Name: {before['name_en']}, URL: {before['affiliate_url']}")

print("\nSimulating Admin Edit (updating DB directly)...")
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()
from api.models import HealthAccessory

item = HealthAccessory.objects.first()
item.affiliate_url = "https://www.daraz.com.bd/catalog/?q=digital+blood+pressure+monitor&affiliate_id=BPULSE123"
item.save()

print("\nFetching AFTER edit...")
after = fetch_first()
if after:
    print(f"Name: {after['name_en']}, URL: {after['affiliate_url']}")

