# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

filepath = 'assistant/conf.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'gemini-2.5-flash'", "'gemini-3.8-flash'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
