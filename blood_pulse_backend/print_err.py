# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

filepath = 'assistant/views.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'except Exception as e:\n            # 8. Fallback',
    'except Exception as e:\n            import traceback; traceback.print_exc()\n            # 8. Fallback'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
