import os
import re

filepath = 'test/widget/assistant_screen_test.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("find.textContaining('Encrypted')", "find.textContaining('AI-assisted guidance')")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed test")
