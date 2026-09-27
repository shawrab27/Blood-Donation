# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import requests

url = 'http://localhost:8000/api/assistant/chat/'
payload = {'message': 'I weight 49kg, can I donate?', 'locale': 'en'}
try:
    response = requests.post(url, json=payload)
    print("Status:", response.status_code)
    print("Response:", response.text)
except Exception as e:
    print("Error:", e)
