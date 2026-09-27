import re

for filename in ['lib/features/blood_hub/presentation/screens/direct_request_screen.dart', 'lib/features/blood_hub/presentation/screens/personal_emergency_screen.dart']:
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace("'${h.district}, ${h.division}',", "'${h.district}',")
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)
print("Fixed division property access")
