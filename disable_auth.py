import re

file_path = "blood_pulse_backend/assistant/views.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("permission_classes([IsAuthenticated])", "permission_classes([AllowAny])")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated assistant views permissions correctly")
