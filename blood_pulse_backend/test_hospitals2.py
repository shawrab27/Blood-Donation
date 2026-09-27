# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.test.client import Client

c = Client()
res = c.get('/api/hospitals/')
data = res.json()
print("/api/hospitals/:")
if 'results' in data and len(data['results']) > 0:
    print(data['results'][0].keys())
    print(data['results'][0])
else:
    print(data)

res2 = c.get('/api/hospitals/directory/')
data2 = res2.json()
print("\n/api/hospitals/directory/:")
if 'results' in data2 and len(data2['results']) > 0:
    print(data2['results'][0].keys())
    print(data2['results'][0])
else:
    print(data2)
