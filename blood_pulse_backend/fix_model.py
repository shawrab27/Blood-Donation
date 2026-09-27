# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

with open("api/models.py", "r", encoding="utf-8") as f:
    content = f.read()

target = "    longitude = models.FloatField(null=True, blank=True)"
replacement = "    longitude = models.FloatField(null=True, blank=True)\n    fcm_token = models.CharField(max_length=255, null=True, blank=True, help_text='Firebase Cloud Messaging device token')"

if target in content:
    content = content.replace(target, replacement)
    with open("api/models.py", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added fcm_token")
else:
    print("Target not found")
