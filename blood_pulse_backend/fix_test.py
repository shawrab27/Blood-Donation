# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/test/widget/assistant_screen_test.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("find.textContaining('Encrypted'),", "find.textContaining('AI-assisted guidance'),")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
