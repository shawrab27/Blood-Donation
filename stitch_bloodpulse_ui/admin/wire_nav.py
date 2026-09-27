import os
from bs4 import BeautifulSoup
import glob

# Mapping text values to real file names
page_map = {
    'Wave Engine Control': 'wave-engine-control.html',
    'Trust & Fraud Engine': 'trust-fraud-engine.html',
    'Role & Permissions': 'role-permission-editor.html',
    'Donor Management': 'donor-management.html',
}

html_files = glob.glob('*.html')

for filepath in html_files:
    if filepath == 'admin-login.html':
        continue
        
    print(f"Processing {filepath}")
    with open(filepath, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')
        
    modified = False
    
    # Find all sidebar nav links
    sidebar = soup.find('aside') or soup.find('nav') # fallback for different layouts
    if sidebar:
        links = sidebar.find_all('a')
        for a in links:
            # find the span with the text
            text_span = a.find('span', string=lambda t: t and any(k in t for k in page_map.keys()))
            if text_span:
                for k, v in page_map.items():
                    if k in text_span.text:
                        if a.get('href') == '#' or not a.get('href') or a.get('href').endswith('#'):
                            a['href'] = v
                            modified = True
                            print(f"  -> Linked '{k}' to {v}")
                            break
    
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(str(soup))
        print(f"Saved {filepath}")
