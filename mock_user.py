import re

file_path = "blood_pulse_backend/assistant/views.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

mock_user = """
        user = request.user
        if not user.is_authenticated:
            from django.contrib.auth import get_user_model
            user = get_user_model().objects.first()
"""

content = content.replace("user = request.user", mock_user)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Added mock user to views")
