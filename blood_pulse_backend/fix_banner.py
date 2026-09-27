# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/assistant/presentation/screens/assistant_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'AI-assisted Class IIa Clinical Reference \u2022 Encrypted',
    'AI-assisted guidance \u2014 not a medical diagnosis. Always consult a doctor.'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
