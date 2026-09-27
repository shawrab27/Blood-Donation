import os

filepath = 'lib/features/assistant/presentation/screens/assistant_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = re.sub(
    r'"AI-assisted Class IIa Clinical Reference • Encrypted"', 
    r'"AI-assisted guidance — not a medical diagnosis. Always consult a doctor."', 
    content
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Replaced Class IIa text")
