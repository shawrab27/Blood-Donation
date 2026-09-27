import re
import glob
import os

files = glob.glob('blood_pulse/lib/**/*.dart', recursive=True)
for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    if 'showMenu:' in content:
        content = re.sub(r'showMenu:\s*(true|false),', '', content)
        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed {file}")
