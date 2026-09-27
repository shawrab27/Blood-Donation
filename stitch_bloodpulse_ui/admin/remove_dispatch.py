import os
import re

html_files = [f for f in os.listdir('.') if f.endswith('.html')]

for filename in html_files:
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We want to remove the full <a> tag that contains "Emergency Dispatch" anywhere inside it.
    # non-greedy .*?
    new_content = re.sub(r'<a [^>]*>.*?Emergency Dispatch.*?</a>', '', content, flags=re.DOTALL)
    
    if new_content != content:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Removed from {filename}')
