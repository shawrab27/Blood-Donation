import os

filepath = 'lib/features/social/social_feed_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("padding: const EdgeInsets.only(bottom: 16.0, top: (index == 2) ? 24.0 : 0.0),", "padding: EdgeInsets.only(bottom: 16.0, top: (index == 2) ? 24.0 : 0.0),")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
