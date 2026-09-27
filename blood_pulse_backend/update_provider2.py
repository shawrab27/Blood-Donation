# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/profile/domain/providers/profile_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("        import 'dart:convert';\n", "")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
