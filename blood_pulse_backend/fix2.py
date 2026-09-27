# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
with open('api/views.py', 'r') as f:
    c = f.read()

c = c.replace("def react(self, request, pk=None):", "def like(self, request, pk=None):")

with open('api/views.py', 'w') as f:
    f.write(c)
