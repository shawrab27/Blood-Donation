import os

filepath = 'lib/features/health_hub/presentation/screens/health_accessories_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Approx. ',", "'Approx. ${item.priceRange}',")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
