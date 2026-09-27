import re

with open('api/urls.py', 'r', encoding='utf-8') as f:
    text = f.read()

# Fix the broken import
text = text.replace(r'from .views_admin_audit import AdminAuditLogAPIView\nfrom .views_admin_donors import', 'from .views_admin_audit import AdminAuditLogAPIView\nfrom .views_admin_donors import')
text = text.replace('from .views_admin_audit import AdminAuditLogAPIView\\nfrom .views_admin_donors import', 'from .views_admin_audit import AdminAuditLogAPIView\nfrom .views_admin_donors import')

if 'path(\'admin/audit/' not in text:
    text = text.replace(
        "path('admin/donors/', AdminDonorListAPIView.as_view(), name='admin-donors-list'),",
        "path('admin/audit/', AdminAuditLogAPIView.as_view(), name='admin-audit'),\n    path('admin/donors/', AdminDonorListAPIView.as_view(), name='admin-donors-list'),"
    )

with open('api/urls.py', 'w', encoding='utf-8') as f:
    f.write(text)
