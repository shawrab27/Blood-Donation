import re

with open("blood_pulse_backend/assistant/views.py", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace('"content_en": "You must weigh', '"reply": "You must weigh')
content = content.replace('"content_bn":', '"reply_bn":')

with open("blood_pulse_backend/assistant/views.py", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed mock response keys")
