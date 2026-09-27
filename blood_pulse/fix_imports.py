import re

with open("lib/services/fcm_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = "import '../features/notifications/presentation/screens/notification_wallpaper_overlay.dart';"
replacement = """import '../features/notifications/presentation/screens/notification_wallpaper_overlay.dart';
import 'api_client.dart';"""

if target in content:
    content = content.replace(target, replacement)
    with open("lib/services/fcm_service.dart", "w", encoding="utf-8") as f:
        f.write(content)
    print("Added import")
else:
    print("Target not found")
