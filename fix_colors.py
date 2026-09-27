import re

with open("blood_pulse/lib/features/health_hub/presentation/screens/resources_hub_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Make background 0xFF271816
# Add glassy red/white accents to cards and text

content = content.replace("Scaffold(", "Scaffold(\n      backgroundColor: const Color(0xFF271816),")
content = content.replace("color: AppColors.secondary", "color: Colors.white")
content = content.replace("color: AppColors.neutral", "color: Colors.white70")

# fix _hotlineCard background
content = content.replace(
    "color: Colors.white,\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.grey.shade200),",
    "color: Colors.white.withOpacity(0.05),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.white.withOpacity(0.1)),"
)

# fix _hospitalItem background
content = content.replace(
    "color: Colors.white,\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.grey.shade200),",
    "color: Colors.white.withOpacity(0.05),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.white.withOpacity(0.1)),"
)

# fix hospital icon container background
content = content.replace(
    "color: const Color(0xFFF0F4F8),",
    "color: Colors.white.withOpacity(0.1),"
)

with open("blood_pulse/lib/features/health_hub/presentation/screens/resources_hub_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated resources_hub_screen colors")
