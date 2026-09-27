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
    print(list(data['results'][0].keys()))
elif isinstance(data, list) and len(data) > 0:
    print(list(data[0].keys()))
else:
    print("Empty array or dictionary with no results.")

res2 = c.get('/api/hospitals/directory/')
data2 = res2.json()
print("\n/api/hospitals/directory/:")
if 'results' in data2 and len(data2['results']) > 0:
    print(list(data2['results'][0].keys()))
elif isinstance(data2, list) and len(data2) > 0:
    print(list(data2[0].keys()))
else:
    print("Empty array or dictionary with no results.")
