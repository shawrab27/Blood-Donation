import re

with open("blood_pulse/lib/core/app_router.dart", "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace("initialLocation: '/assistant'", "initialLocation: '/onboarding'")
with open("blood_pulse/lib/core/app_router.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Reverted app_router.dart")
