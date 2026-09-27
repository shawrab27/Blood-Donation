import re

with open("blood_pulse/lib/main.dart", "r", encoding="utf-8") as f:
    content = f.read()

# We need to add flutter_secure_storage import if not present, and the injection.
# But wait, flutter_secure_storage might be imported already.
injection = """
  // INJECTED TEST TOKEN
  const storage = FlutterSecureStorage();
  await storage.write(key: 'bp_jwt_access_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkwMzkxNDY2LCJpYXQiOjE3OTAzOTA1NjYsImp0aSI6IjEwY2JkNTYwYjFkNDRmMzU4ODM5OTM3ZjBhNjk5MDU5IiwidXNlcl9pZCI6IjEifQ.Fl43zkoWUfJb3qcpkKL0LpKw0JHN7jFGwjkup-VdWYM');
"""

if "FlutterSecureStorage" not in content:
    content = "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n" + content

# find `void main() async {` or similar
content = content.replace("WidgetsFlutterBinding.ensureInitialized();", "WidgetsFlutterBinding.ensureInitialized();\n" + injection)

with open("blood_pulse/lib/main.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Injected valid JWT into main.dart")
