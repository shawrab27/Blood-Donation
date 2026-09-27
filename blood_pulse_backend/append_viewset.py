# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = 'api/views.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

viewset = '''
class HealthAccessoryViewSet(viewsets.ModelViewSet):
    queryset = HealthAccessory.objects.filter(is_active=True).order_by('display_order')
    serializer_class = HealthAccessorySerializer
    permission_classes = [permissions.AllowAny]  # Keep it accessible for now
'''

content += viewset

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
