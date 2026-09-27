import requests

login_res = requests.post("http://localhost:8000/api/token/", json={"username": "01601239042", "password": "password123"}).json()
print("ACCESS:", login_res["access"])
print("REFRESH:", login_res["refresh"])
