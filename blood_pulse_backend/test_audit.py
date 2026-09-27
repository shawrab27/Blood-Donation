# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()
from django.contrib.auth.models import User
from api.models import AuditLog, DonorProfile, FakeAccountFlag
from rest_framework.test import APIClient

admin, _ = User.objects.get_or_create(username='audit_admin', is_staff=True, is_superuser=True)
donor_user, _ = User.objects.get_or_create(username='flagged_user')
donor, _ = DonorProfile.objects.get_or_create(user=donor_user, blood_group='B+', district='Sylhet', phone_number='01899112233')
flag, _ = FakeAccountFlag.objects.get_or_create(donor=donor, reason='Suspicious pattern', resolved=False)

client = APIClient()
client.force_authenticate(user=admin)
response = client.patch(f'/api/flags/{flag.id}/', {'resolved': True})
print('Response Status:', response.status_code)

log = AuditLog.objects.filter(object_id=flag.id).order_by('-timestamp').first()
if log:
    print(f'AuditLog Row: ID={log.id} User={log.user.username} Action={log.action} Changes={log.changes}')
else:
    print('No AuditLog row found!')
