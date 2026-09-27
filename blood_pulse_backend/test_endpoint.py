# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import urllib.request
import json

url = "http://127.0.0.1:8000/api/health-accessories/"
req = urllib.request.Request(url)
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        print(f"Total: {data['count'] if 'count' in data else len(data)}")
        if 'results' in data and len(data['results']) > 0:
            print("First item:", data['results'][0]['name_en'], "-", data['results'][0]['affiliate_url'])
        elif len(data) > 0:
            print("First item:", data[0]['name_en'], "-", data[0]['affiliate_url'])
except Exception as e:
    print(e)
