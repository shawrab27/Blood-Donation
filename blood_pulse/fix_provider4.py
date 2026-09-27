import os

filepath = 'lib/features/health_hub/domain/providers/health_hub_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../../blood_hub/data/blood_hub_api_service.dart';", "import '../../../blood_hub/data/blood_hub_api_service.dart';")
content = content.replace("Uri.parse('/hospitals/')", "Uri.parse('$cleanBase/hospitals/')")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
