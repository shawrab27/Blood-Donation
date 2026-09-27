# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()
from django.core.management import call_command

with open('api/models.py', 'a', encoding='utf-8') as f:
    f.write('''

class Notification(models.Model):
    user = models.ForeignKey('auth.User', on_delete=models.CASCADE, related_name='system_notifications')
    title = models.CharField(max_length=255)
    body = models.TextField()
    type = models.CharField(max_length=50, default='GENERAL')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
''')
