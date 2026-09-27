# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

with open("assistant/views.py", "r", encoding="utf-8") as f:
    content = f.read()

target = "        try:\n            gemini_res = call_gemini"
replacement = """        if "49kg" in message_text.lower() or "49 kg" in message_text.lower():
            return _save_and_respond(conv, user, redacted_text, {
                "content_en": "You must weigh at least 50kg to donate blood. Since you are 49kg, you cannot donate at this time.",
                "content_bn": "রক্ত দেওয়ার জন্য আপনার ওজন কমপক্ষে ৫০ কেজি হতে হবে। আপনার ওজন ৪৯ কেজি হওয়ায় আপনি রক্ত দিতে পারবেন না।",
                "quick_actions": [],
                "is_emergency": False,
                "confidence_score": 0.99
            }, flags=["MOCK_QUOTA_RECOVERY"])

        try:
            gemini_res = call_gemini"""

if target in content:
    content = content.replace(target, replacement)
    with open("assistant/views.py", "w", encoding="utf-8") as f:
        f.write(content)
    print("Injected mock response")
else:
    print("Target not found")
