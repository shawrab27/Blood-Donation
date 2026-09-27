# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import requests

base_url = 'http://localhost:8000/api'
login_data = {'username': 'testuser', 'password': 'Password123!'}
r = requests.post(f'{base_url}/token/', json=login_data)

if r.status_code == 200:
    token = r.json().get('access')
    headers = {'Authorization': f'Bearer {token}'}
    
    # Test FCM update
    fcm_data = {'token': 'test-token-123'}
    r_fcm = requests.post(f'{base_url}/users/update-fcm/', json=fcm_data, headers=headers)
    print("RAW HTTP RESPONSE:", r_fcm.status_code, r_fcm.text)
else:
    print("Login failed")
