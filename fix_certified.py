with open('blood_pulse/lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("'Certified diagnostic devices, test strips, recovery supplements & voluntary donor gear.'", "'Diagnostic devices, test strips, recovery supplements & voluntary donor gear.'")
text = text.replace("'DGDA / ISO Certified'", "'Quality Standards'")

with open('blood_pulse/lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Certified term replaced.")
