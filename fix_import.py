import re
file_path = "blood_pulse_backend/assistant/views.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

if "from rest_framework.permissions import" in content:
    content = content.replace("from rest_framework.permissions import IsAuthenticated", "from rest_framework.permissions import IsAuthenticated, AllowAny")
else:
    content = "from rest_framework.permissions import AllowAny\n" + content

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Imported AllowAny")
