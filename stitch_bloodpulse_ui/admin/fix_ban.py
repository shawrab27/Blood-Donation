import sys

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/users//ban/, null, 'User banned successfully');",
    "actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/users/${currentBanUserId}/ban/`, null, 'User banned successfully');"
)

with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed ban URL!")
