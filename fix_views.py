import re

with open('blood_pulse_backend/api/views.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract the mixin
mixin_match = re.search(r'class AdminAuditLogMixin:.*?instance\.delete\(\)', content, re.DOTALL)
if mixin_match:
    mixin_code = mixin_match.group(0)
    # Remove from bottom
    content = content.replace(mixin_code, '')
    # Insert right before FakeAccountFlagViewSet
    target = 'class FakeAccountFlagViewSet(AdminAuditLogMixin, viewsets.ModelViewSet):'
    content = content.replace(target, mixin_code + '\n\n' + target)
    with open('blood_pulse_backend/api/views.py', 'w', encoding='utf-8') as f:
        f.write(content)
