import re

with open('stitch_bloodpulse_ui/admin/donor-management.html', 'r', encoding='utf-8') as f:
    text = f.read()

# Find all ids related to donor table
ids = re.findall(r'id="([^"]*table[^"]*|[^"]*tbody[^"]*|[^"]*list[^"]*)"', text)
print('Table IDs:', ids)

# Find renderDonors function
m = re.search(r'function renderDonors\b.{0,600}', text, re.DOTALL)
if m:
    print('renderDonors:', m.group(0)[:500])
