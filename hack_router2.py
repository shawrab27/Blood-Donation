import re

with open("blood_pulse/lib/core/app_router.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("initialLocation: '/chat'", "initialLocation: '/assistant'")

with open("blood_pulse/lib/core/app_router.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated router to /assistant")
