import json
import requests
from google.oauth2 import service_account
from google.cloud import firestore

env_path = 'blood_pulse_backend/.env'
cred_json = None
with open(env_path, 'r', encoding='utf-8') as f:
    for line in f:
        if line.startswith('FIREBASE_CREDENTIALS_JSON='):
            cred_json = line.split('=', 1)[1].strip().strip('\'\"')
            break

if not cred_json:
    print('No credentials found')
    exit(1)

key_dict = json.loads(cred_json)
cred = service_account.Credentials.from_service_account_info(key_dict)
project_id = key_dict['project_id']
db = firestore.Client(credentials=cred, project=project_id)

print("=" * 60)
print("TEST 1: Legitimate Room Creation & Message Write (Participants [donor_1, requester_2])")
print("=" * 60)
try:
    room_id = 'room_donor1_requester2'
    participants = ['test_donor_1', 'test_requester_2']

    # 1. Create room document with participants list
    room_doc_ref = db.collection('chat_rooms').document(room_id)
    room_doc_ref.set({
        'roomId': room_id,
        'participants': participants,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    })
    print(f"SUCCESS: Room '{room_id}' created with participants: {participants}")

    # 2. Legitimate participant writes a message
    msg_ref = room_doc_ref.collection('messages').document('msg_001')
    msg_ref.set({
        'senderId': 'test_donor_1',
        'receiverId': 'test_requester_2',
        'text': 'Hello, I am on my way to donate blood at DMCH.',
        'timestamp': firestore.SERVER_TIMESTAMP,
        'isRead': False
    })
    print("SUCCESS: Legitimate write worked! Message 'msg_001' written to room.")

    # 3. Read back message
    read_doc = msg_ref.get()
    print("SUCCESS: Read back message data:", read_doc.to_dict())

except Exception as e:
    print(f"FAILURE in Test 1: {type(e).__name__}: {e}")

print("\n" + "=" * 60)
print("TEST 2: Mirror Collection /chats/{chatId} with Participants")
print("=" * 60)
try:
    chat_id = 'chat_donor1_requester2'
    chat_doc_ref = db.collection('chats').document(chat_id)
    chat_doc_ref.set({
        'chatId': chat_id,
        'participants': ['test_donor_1', 'test_requester_2'],
        'updatedAt': firestore.SERVER_TIMESTAMP,
    })
    chat_msg_ref = chat_doc_ref.collection('messages').document('msg_chat_001')
    chat_msg_ref.set({
        'senderId': 'test_donor_1',
        'receiverId': 'test_requester_2',
        'text': 'Mirror chats collection test.',
        'timestamp': firestore.SERVER_TIMESTAMP,
        'isRead': False
    })
    print(f"SUCCESS: Chats mirror document and message written successfully.")
except Exception as e:
    print(f"FAILURE in Test 2: {type(e).__name__}: {e}")

print("\n" + "=" * 60)
print("TEST 3: Third Unrelated Account / Unauthorized Request DENIAL")
print("=" * 60)
# Attempt write to chat_rooms as an unauthorized third-party via REST API
doc_rest_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/chat_rooms/{room_id}/messages/msg_intruder"

# 1. Unauthorized Write Attempt
intruder_payload = {
    'fields': {
        'senderId': {'stringValue': 'third_party_intruder_C'},
        'text': {'stringValue': 'Attempting unauthorized write into private chat'}
    }
}
res_write = requests.patch(doc_rest_url, json=intruder_payload)
print(f"Intruder Write HTTP Status: {res_write.status_code}")
print(f"Intruder Write Response Body: {res_write.text.strip()}")
if res_write.status_code == 403:
    print(">>> ACCESS DENIED VERIFIED: Third party write was blocked with 403 PERMISSION_DENIED! <<<")
else:
    print(f">>> UNEXPECTED STATUS: {res_write.status_code} <<<")

# 2. Unauthorized Read Attempt
res_read = requests.get(f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/chat_rooms/{room_id}/messages/msg_001")
print(f"\nIntruder Read HTTP Status: {res_read.status_code}")
print(f"Intruder Read Response Body: {res_read.text.strip()}")
if res_read.status_code == 403:
    print(">>> ACCESS DENIED VERIFIED: Third party read was blocked with 403 PERMISSION_DENIED! <<<")
else:
    print(f">>> UNEXPECTED STATUS: {res_read.status_code} <<<")
