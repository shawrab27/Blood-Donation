import re

with open('donor-management.html', 'r', encoding='utf-8') as f:
    text = f.read()

text = re.sub(
    r'onclick="alert\([^"]*\'none\';"',
    'id="confirm-erase-btn"',
    text,
    flags=re.DOTALL
)

with open('donor-management.html', 'w', encoding='utf-8') as f:
    f.write(text)
