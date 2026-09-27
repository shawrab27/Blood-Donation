import sys

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/approve/, id, 'Request Approved');",
    "actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/approve/`, id, 'Request Approved');"
)
content = content.replace(
    "actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/reject/, id, 'Request Rejected');",
    "actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/reject/`, id, 'Request Rejected');"
)

with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed actionRequest URLs!")
