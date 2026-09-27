# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from assistant.pipeline.router import route_query
from assistant.pipeline.guards import apply_guards
from assistant.models import KBEntry

questions = [
    "days remain to donate",
    "aspirin before donating",
    "tattoo waiting period",
    "who developed this app",
    "Can I donate if I weigh 49 kg?"  # This is the numeric guard test
]

for q in questions:
    res = route_query(q)
    print(f"\n--- Query: '{q}' ---")
    print(f"Track: {res['track']}")
    
    if res['track'] == 'C':
        matched_kbs = res['matches']
        for i, m in enumerate(matched_kbs):
            print(f" {i+1}. {m.title_en} (Distance: {m.distance:.4f})")
            
        # Test numeric claim guard for the 5th question
        if "weigh 49 kg" in q:
            print("\n>> Testing Numeric Guard <<")
            # Fake Gemini reply with hallucinatory number
            mock_json = {
                "reply": "Yes, you can donate if you weigh 49 kg.",
                "language": "en",
                "action_ids": [],
                "kb_ids_used": [m.id for m in matched_kbs]
            }
            guarded_json = apply_guards(mock_json, matched_kbs)
            print("Guarded Reply:", guarded_json["reply"])
            print("Flags:", guarded_json.get("flags", []))
            
    elif res['track'] == 'A_B':
        print(f" Track A_B response: {res['response']['reply']}")

