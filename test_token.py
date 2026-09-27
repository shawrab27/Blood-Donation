import requests

token_res = requests.post("http://localhost:8000/api/token/", json={"username": "01711111111", "password": "password123"})
if token_res.status_code != 200:
    # try testuser
    token_res = requests.post("http://localhost:8000/api/token/", json={"username": "01601239042", "password": "password123"})
print("Token response:", token_res.status_code, token_res.text[:100])
