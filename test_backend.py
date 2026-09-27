import requests
import json

base_url = 'http://localhost:8000/api'

# 1. Login to get token
login_data = {'username': 'testuser', 'password': 'Password123!'}
r = requests.post(f'{base_url}/token/', json=login_data)
if r.status_code == 200:
    token = r.json().get('access')
    headers = {'Authorization': f'Bearer {token}'}
    
    # 2. Test FCM update
    fcm_data = {'token': 'dummy_fcm_token_12345'}
    r_fcm = requests.post(f'{base_url}/users/update-fcm/', json=fcm_data, headers=headers)
    print("FCM Update Response:", r_fcm.status_code, r_fcm.text)
    
    # 3. Test Assistant Chat (Guarded Response)
    chat_data = {'message': 'I weigh 49kg, can I donate?', 'locale': 'en'}
    r_chat = requests.post(f'{base_url}/assistant/chat/', json=chat_data, headers=headers)
    print("Chat Response:", r_chat.status_code, r_chat.text)
else:
    print("Login failed:", r.status_code, r.text)

