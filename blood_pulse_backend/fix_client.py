# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

filepath = 'assistant/pipeline/gemini_client.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('Part.from_text(', 'Part.from_text(text=')
# And types.Content requires role and parts kwargs? Wait, it is already using kwargs: `types.Content(role="user", parts=[...])`

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
