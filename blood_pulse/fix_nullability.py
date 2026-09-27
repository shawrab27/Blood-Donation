filepath = 'lib/features/health_hub/presentation/screens/resources_hub_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('hospital.nameEn,', "hospital.nameEn ?? 'Unknown Hospital',")
content = content.replace("hospital.phone ??", "hospital.phone ??")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
