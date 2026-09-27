import re

with open("blood_pulse/lib/core/widgets/custom_app_bar.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace ProfileDrawer.show(context) with context.push('/profile')
content = content.replace("ProfileDrawer.show(context)", "context.push('/profile')")

# Remove the popup menu entirely
popup_regex = re.compile(r'// ─+ 3\. Menu Options \(3-Dot Popup Menu\) ─+.*?if \(showMenu\).*?PopupMenuButton<String>\(.*?\]\,\n\s*\)\,', re.DOTALL)
content = popup_regex.sub('', content)
popup_regex2 = re.compile(r'// ─+ 3\. Menu Options.*?if \(showMenu\).*?PopupMenuButton.*?\]\,\n\s*\)\,', re.DOTALL)
content = popup_regex2.sub('', content)

# But wait, it might be easier to just remove showMenu entirely.
content = content.replace("final bool showMenu;", "")
content = content.replace("this.showMenu = false,", "")
content = content.replace("!showMenu &&", "")
content = content.replace("showNotification || showProfile || showMenu", "showNotification || showProfile")

with open("blood_pulse/lib/core/widgets/custom_app_bar.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed custom_app_bar")
