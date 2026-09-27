import re

with open("blood_pulse/lib/services/api_client.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("'https://blood-donation-liard.vercel.app/api/'", "'http://localhost:8000/api/'")

with open("blood_pulse/lib/services/api_client.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated API base URL to localhost")
