# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import re

filepath = 'api/urls.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("UnreadNotificationCountView,", "UnreadNotificationCountView, NotificationListView,")
content = content.replace(
    "path('notifications/unread-count/', UnreadNotificationCountView.as_view(), name='unread-notification-count'),",
    "path('notifications/', NotificationListView.as_view(), name='notifications-list'),\n    path('notifications/unread-count/', UnreadNotificationCountView.as_view(), name='unread-notification-count'),"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
