# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/blood_hub/presentation/providers/donor_search_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("phone: json['phone'],", "phone: json['phone_masked'],")
content = content.replace("name: json['user']?['full_name'] ?? 'Unknown Donor',", "name: json['full_name'] ?? 'Unknown Donor',")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
