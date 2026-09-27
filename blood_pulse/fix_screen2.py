import os

filepath = 'lib/features/health_hub/presentation/screens/resources_hub_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the broken interpolation
content = content.replace("', ',", "'${hospital.district}, ${hospital.division}',")

# Also, hospital object might be dynamic if I didn't specify type, wait...
# No, dart infers hospital type. BUT the flutter analyze error said "receiver can be null".
# Wait, maybe `hospitalsAsync.when(data: (hospitals) {...})` infer `hospitals` as `List<HospitalModel>?` in some cases? 
# Or `hospitals` is a `List<HospitalModel?>`?
# Let's type it explicitly `data: (List<HospitalModel> hospitals) { ... }`.
content = content.replace("data: (hospitals) {", "data: (List<HospitalModel> hospitals) {")
# and remove the ?? 'Unknown Hospital' because nameEn is not nullable
content = content.replace("hospital.nameEn ?? 'Unknown Hospital'", "hospital.nameEn")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
