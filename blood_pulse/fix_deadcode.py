filepath = 'lib/features/health_hub/presentation/screens/resources_hub_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("(hospital.nameEn ?? 'Unknown')", "hospital.nameEn")
content = content.replace("${(hospital.district ?? '')}, ${(hospital.division ?? '')}", "${hospital.district}, ${hospital.division}")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
