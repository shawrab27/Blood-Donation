# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from assistant.pipeline.router import route_query

questions = [
    "days remain to donate",
    "aspirin before donating",
    "tattoo waiting period",
    "who developed this app",
    "blood pressure limits for donating"
]

for q in questions:
    res = route_query(q)
    print(f"\n--- Query: '{q}' ---")
    print(f"Track: {res['track']}")
    if res['track'] == 'C':
        for i, m in enumerate(res['matches']):
            print(f" {i+1}. {m.title_en} (Distance: {m.distance:.4f})")
    elif res['track'] == 'A_B':
        print(f" Track A_B response: {res['response']['reply']}")

