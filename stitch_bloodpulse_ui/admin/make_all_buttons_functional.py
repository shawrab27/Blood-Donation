import os
import glob
from bs4 import BeautifulSoup

def get_sidebar_and_header_from_template():
    with open('wave-engine-control.html', 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')
    sidebar = soup.find('aside')
    header = soup.find('header')
    return str(sidebar), str(header)

sidebar_html, header_html = get_sidebar_and_header_from_template()

placeholder_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta content="width=device-width, initial-scale=1.0" name="viewport"/>
    <title>BloodPulse Admin</title>
    <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200" rel="stylesheet"/>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&display=swap" rel="stylesheet"/>
    <script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
    <script>
        tailwind.config = {{
            theme: {{
                extend: {{
                    colors: {{
                        primary: '#C30121',
                        secondary: '#2B2B2B',
                        tertiary: '#0D68AA',
                        surface: '#FDF3F3',
                    }},
                    fontFamily: {{
                        body: ['Inter', 'sans-serif'],
                        button: ['Inter', 'sans-serif'],
                        headline: ['Georgia', 'serif'],
                        label: ['Inter', 'sans-serif']
                    }}
                }}
            }}
        }}
    </script>
</head>
<body class="bg-[#FDF3F3] text-[#2B2B2B] font-body flex w-full h-screen overflow-hidden">
    {sidebar_html}
    <div class="pl-72 w-full flex flex-col h-screen">
        {header_html}
        <main class="flex-1 w-full pt-16 bg-[#FDF3F3] px-lg overflow-y-auto">
            <div class="flex items-center justify-center h-full">
                <div class="text-center space-y-4">
                    <span class="material-symbols-outlined text-6xl text-neutral-300">construction</span>
                    <h2 class="text-2xl font-headline font-bold text-neutral-700">PAGE_TITLE</h2>
                    <p class="text-neutral-500 font-medium">This module is currently under development.</p>
                </div>
            </div>
        </main>
    </div>
</body>
</html>
"""

html_files = glob.glob('*.html')

# Phase 1: Ensure all data-paths have .html versions assigned in ALL files
data_path_to_file = {
    'wave-engine-control': 'wave-engine-control.html',
    'trust-and-fraud-engine': 'trust-fraud-engine.html',
    'role-and-permission-editor': 'role-permission-editor.html',
    'donor-management': 'donor-management.html',
}

for filepath in html_files:
    if filepath == 'admin-login.html':
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')
        
    sidebar = soup.find('aside') or soup.find('nav')
    if sidebar:
        links = sidebar.find_all('a')
        for a in links:
            dpath = a.get('data-path')
            if not dpath:
                continue
            
            # If we haven't mapped this data-path to a file yet, assign it one
            if dpath not in data_path_to_file:
                data_path_to_file[dpath] = f"{dpath}.html"
            
            # Now update the href
            target_href = data_path_to_file[dpath]
            if a.get('href') != target_href:
                a['href'] = target_href
                
        # Save back the file with updated hrefs
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(str(soup))

# Phase 2: Create placeholder files for any files that do not exist
for dpath, target_file in data_path_to_file.items():
    if not os.path.exists(target_file):
        title = dpath.replace('-', ' ').title()
        content = placeholder_template.replace("PAGE_TITLE", title + " Module")
        
        # We also need to update the sidebar inside the placeholder to have active states correct, but for a placeholder, it's fine if it's generic.
        # Let's fix the links inside the placeholder template too so it doesn't have dead links!
        ph_soup = BeautifulSoup(content, 'lxml')
        ph_sidebar = ph_soup.find('aside')
        if ph_sidebar:
            for a in ph_sidebar.find_all('a'):
                dp = a.get('data-path')
                if dp in data_path_to_file:
                    a['href'] = data_path_to_file[dp]
                    
                # Fix active state
                if dp == dpath:
                    # Make it active
                    a['class'] = a.get('class', []) + ['bg-[#C30121]', 'text-white', 'shadow-sm']
                    # Remove hover classes that conflict
                    a['class'] = [c for c in a['class'] if not c.startswith('hover:')]
                    # Replace text-white/90 with text-white
                    a['class'] = [c.replace('text-white/90', 'text-white') for c in a['class']]
                else:
                    # Make it inactive
                    if 'bg-[#C30121]' in a.get('class', []):
                        a['class'].remove('bg-[#C30121]')
                        a['class'].remove('shadow-sm')
                        a['class'].append('text-white/90')
                        a['class'].append('hover:bg-white/10')
                        
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(str(ph_soup))
        print(f"Created placeholder: {target_file}")
    else:
        print(f"File exists: {target_file}")

print("All sidebars updated to use functional links.")
