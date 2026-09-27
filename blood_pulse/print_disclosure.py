import re

with open('lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

match = re.search(r"'(Products listed are curated[^']+)'", text)
if match:
    print(match.group(1))
