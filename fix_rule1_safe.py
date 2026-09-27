import re

with open("blood_pulse/lib/core/widgets/custom_app_bar.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace ProfileDrawer.show(context) with context.push('/profile')
content = content.replace("ProfileDrawer.show(context)", "context.push('/profile')")

# We want to remove the 3-Dot Popup Menu safely.
# It starts at: `// â”€â”€ 3. Menu Options (3-Dot Popup Menu) â”€â”€`
# Or: `// ─+ 3. Menu Options (3-Dot Popup Menu) ─+`
lines = content.split('\n')
new_lines = []
skip = False
brackets = 0

for i, line in enumerate(lines):
    if '3. Menu Options (3-Dot Popup Menu)' in line:
        skip = True
        # the if (showMenu) is right below it usually
        # actually, just skip everything until the end of the popup menu.
        # let's just skip until we see `const SizedBox(width: 8),`
    
    if skip:
        if 'const SizedBox(width: 8),' in line:
            skip = False
            new_lines.append(line)
    else:
        new_lines.append(line)

content = '\n'.join(new_lines)
content = content.replace("final bool showMenu;", "")
content = content.replace("this.showMenu = false,", "")
content = content.replace("!showMenu &&", "")
content = content.replace("showNotification || showProfile || showMenu", "showNotification || showProfile")
content = content.replace("if (showMenu)", "")

with open("blood_pulse/lib/core/widgets/custom_app_bar.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Safely fixed custom_app_bar")
