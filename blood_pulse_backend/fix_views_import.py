# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = 'api/views.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("DonationHistory, RecentLog", "DonationHistory, RecentLog, HealthAccessory")
content = content.replace("DonationGuideSectionSerializer,", "DonationGuideSectionSerializer, HealthAccessorySerializer,")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
