filepath = 'lib/features/health_hub/presentation/screens/resources_hub_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import '../../blood_hub/data/blood_hub_api_service.dart';", "import '../../../blood_hub/data/blood_hub_api_service.dart';")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
