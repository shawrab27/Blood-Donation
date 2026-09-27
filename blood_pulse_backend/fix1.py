# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/blood_hub/presentation/providers/donor_search_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("final response = await apiClient.get(uri.toString());", "final response = await ApiClient().get(uri.toString());")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
