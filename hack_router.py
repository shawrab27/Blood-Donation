import re

with open("blood_pulse/lib/core/app_router.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Instead of redirecting to login, we redirect to chat if it's the splash or onboarding
content = content.replace("initialLocation: '/'", "initialLocation: '/chat'")
content = content.replace("redirect: (context, state) {", "redirect: (context, state) { return null;")

with open("blood_pulse/lib/core/app_router.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated router for direct chat access")
