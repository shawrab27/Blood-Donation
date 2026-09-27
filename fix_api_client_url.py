import re

with open("blood_pulse/lib/services/api_client.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("'http://localhost:8000/api/'", "'http://localhost:8000'")

with open("blood_pulse/lib/services/api_client.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed API base URL to remove trailing /api/")
