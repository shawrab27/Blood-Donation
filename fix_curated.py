with open('blood_pulse/lib/features/health_hub/domain/models/health_accessory_model.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("'Curated Pick'", "'Health Item'")

with open('blood_pulse/lib/features/health_hub/domain/models/health_accessory_model.dart', 'w', encoding='utf-8') as f:
    f.write(text)

with open('blood_pulse/lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("/// Curated medical supplies", "/// Medical supplies")

with open('blood_pulse/lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Curated term replaced.")
