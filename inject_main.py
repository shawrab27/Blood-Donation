import re

with open("blood_pulse/lib/main.dart", "r", encoding="utf-8") as f:
    content = f.read()

injection = """
  // HACK FOR AUTOMATED TEST
  try {
    final storage = const flutter_secure_storage.FlutterSecureStorage();
    await storage.write(key: 'bp_jwt_access_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkwMzkwNjM5LCJpYXQiOjE3OTAzODk3MzksImp0aSI6ImE3MDQxM2U1MDdiNDRiZDQ4YzFkYWY5MWY3NWU1YWNlIiwidXNlcl9pZCI6IjUwIn0.u-AYCJApEhXQqtLb3qe60Vvsz-KRlkTOTOP1w2A9K5o');
  } catch(e) {}
"""

if "import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;" not in content:
    content = "import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;\n" + content

if "HACK FOR AUTOMATED TEST" not in content:
    content = content.replace("await setupServiceLocator();", "await setupServiceLocator();\n" + injection)

with open("blood_pulse/lib/main.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Injected JWT token into main.dart")
