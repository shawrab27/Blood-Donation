import re

with open("blood_pulse/lib/features/assistant/presentation/screens/assistant_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

injection = """
      Future.delayed(const Duration(seconds: 4), () {
        _sendMessage('I weigh 49kg, can I donate?');
      });
"""

content = content.replace("_checkFirstRun();", "_checkFirstRun();\n" + injection)

with open("blood_pulse/lib/features/assistant/presentation/screens/assistant_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Injected auto-send correctly")
