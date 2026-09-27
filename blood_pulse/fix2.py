import os

filepath = 'lib/features/assistant/presentation/screens/assistant_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'Text("AI-assisted Class IIa Clinical Reference \\u2022 Encrypted"', 
    'Text("AI-assisted guidance \u2014 not a medical diagnosis. Always consult a doctor."'
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Replaced!")
