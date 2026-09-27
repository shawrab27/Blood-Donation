import re

with open("blood_pulse/lib/features/blood_hub/presentation/widgets/blood_hub_view.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace Full Screen Map link
content = content.replace("onPressed: () => context.push('/live-dispatch')", "onPressed: () => context.push('/map?mode=radar')")

with open("blood_pulse/lib/features/blood_hub/presentation/widgets/blood_hub_view.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated Full Screen Map link")
