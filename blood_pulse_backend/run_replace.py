# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
root_dir = '../blood_pulse/lib'

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    orig_content = content
    
    # Just straightforward simple string replaces
    content = content.replace("Dhaka Medical College Hospital (Ward 4)", "Hospital")
    content = content.replace("Dhaka Medical College Hospital", "General Hospital")
    content = content.replace("Dhaka Medical College", "General Hospital")
    content = content.replace("Dhaka Medical / City General", "City General")
    content = content.replace("Square Hospital, Dhaka", "City Clinic")
    content = content.replace("Square Hospital, Panthapath", "City Clinic")
    content = content.replace("Square Hospital", "City Clinic")
    content = content.replace("Apollo Health", "Medical Partner")
    content = content.replace("Apollo", "Medical Partner")
        
    if orig_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

for root, _, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
print('Done.')
