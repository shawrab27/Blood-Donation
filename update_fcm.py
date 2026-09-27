import re

with open("blood_pulse/lib/services/fcm_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("'/api/donors/me/fcm-token/'", "'/api/users/update-fcm/'")

with open("blood_pulse/lib/services/fcm_service.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated Flutter FCM service successfully")
