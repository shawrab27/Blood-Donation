# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = 'api/urls.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("from .views import (", "from .views import (\\n    HealthAccessoryViewSet,")
content = content.replace("router.register(r'health-hub/recovery-timeline', RecoveryTimelineStepViewSet, basename='recovery-timeline')", "router.register(r'health-hub/recovery-timeline', RecoveryTimelineStepViewSet, basename='recovery-timeline')\\nrouter.register(r'health-accessories', HealthAccessoryViewSet, basename='health-accessories')")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content.replace("\\n", "\n"))
