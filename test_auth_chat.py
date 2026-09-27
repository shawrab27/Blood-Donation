import requests

login_res = requests.post("http://localhost:8000/api/token/", json={"username": "01601239042", "password": "password123"}).json()
access_token = login_res["access"]

chat_res = requests.post(
    "http://localhost:8000/api/assistant/chat/",
    headers={"Authorization": f"Bearer {access_token}"},
    json={"message": "I weigh 49kg, can I donate?", "locale": "en"}
)

print("STATUS CODE:", chat_res.status_code)
print("RESPONSE BODY:")
print(chat_res.text)
