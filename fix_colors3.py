import re

with open("blood_pulse/lib/features/health_hub/presentation/screens/resources_hub_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("appBar: BloodPulseAppBar(", "appBar: BloodPulseAppBar(\n        backgroundColor: const Color(0xFF271816),")

with open("blood_pulse/lib/features/health_hub/presentation/screens/resources_hub_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated AppBar background")
