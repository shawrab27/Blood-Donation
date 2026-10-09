import json
import base64
import requests
import sys

BASE_URL = "http://127.0.0.1:8080/v1/projects/bloodpulse-283dc/databases/(default)/documents"

def make_jwt(uid, is_admin=False):
    header = base64.urlsafe_b64encode(json.dumps({"alg": "none", "typ": "JWT"}).encode()).decode().rstrip("=")
    payload = {
        "sub": uid,
        "user_id": uid,
        "aud": "bloodpulse-283dc",
        "iss": "https://securetoken.google.com/bloodpulse-283dc",
        "auth_time": 1700000000,
    }
    if is_admin:
        payload["admin"] = True
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{header}.{payload_b64}."

def test_rules():
    print("=== Testing Firestore Security Rules ===")
    
    # 1. Test deprecated /chats/{chatId} is locked down
    token_alice = make_jwt("alice")
    headers_alice = {"Authorization": f"Bearer {token_alice}", "Content-Type": "application/json"}
    
    r_chats_write = requests.post(
        f"{BASE_URL}/chats?documentId=chat_test",
        headers=headers_alice,
        json={"fields": {"msg": {"stringValue": "hello"}}}
    )
    print(f"1. POST /chats/chat_test -> status {r_chats_write.status_code}")
    assert r_chats_write.status_code == 403, f"Expected 403, got {r_chats_write.status_code}: {r_chats_write.text}"
    print("   [PASS] Deprecated /chats path is strictly blocked.")

    # 2. Test unauthenticated access to /tracking
    r_unauth = requests.get(f"{BASE_URL}/tracking/match_99")
    print(f"2. Unauthenticated GET /tracking/match_99 -> status {r_unauth.status_code}")
    assert r_unauth.status_code == 403, f"Expected 403, got {r_unauth.status_code}"
    print("   [PASS] Unauthenticated access to /tracking is blocked.")

    # 3. Create tracking doc by participant donor
    token_donor = make_jwt("donor_uid_1")
    headers_donor = {"Authorization": f"Bearer {token_donor}", "Content-Type": "application/json"}
    
    tracking_data = {
        "fields": {
            "donorUid": {"stringValue": "donor_uid_1"},
            "requesterUid": {"stringValue": "req_uid_2"},
            "status": {"stringValue": "IN_TRANSIT"},
            "donorLocation": {
                "mapValue": {
                    "fields": {
                        "latitude": {"doubleValue": 23.75},
                        "longitude": {"doubleValue": 90.38}
                    }
                }
            }
        }
    }
    r_create_tracking = requests.patch(
        f"{BASE_URL}/tracking/match_101",
        headers=headers_donor,
        json=tracking_data
    )
    print(f"3. Participant donor create /tracking/match_101 -> status {r_create_tracking.status_code}")
    assert r_create_tracking.status_code == 200, f"Expected 200, got {r_create_tracking.status_code}: {r_create_tracking.text}"
    print("   [PASS] Participant donor can initialize tracking document.")

    # 4. Third-party user attempts to read /tracking/match_101
    token_stranger = make_jwt("stranger_uid_3")
    headers_stranger = {"Authorization": f"Bearer {token_stranger}", "Content-Type": "application/json"}
    
    r_stranger_read = requests.get(
        f"{BASE_URL}/tracking/match_101",
        headers=headers_stranger
    )
    print(f"4. Stranger GET /tracking/match_101 -> status {r_stranger_read.status_code}")
    assert r_stranger_read.status_code == 403, f"Expected 403, got {r_stranger_read.status_code}"
    print("   [PASS] Third-party stranger cannot read tracking document.")

    # 5. Donor updates donorLocation (allowed field)
    donor_update = {
        "fields": {
            "donorUid": {"stringValue": "donor_uid_1"},
            "requesterUid": {"stringValue": "req_uid_2"},
            "donorLocation": {
                "mapValue": {
                    "fields": {
                        "latitude": {"doubleValue": 23.76},
                        "longitude": {"doubleValue": 90.39}
                    }
                }
            }
        }
    }
    r_donor_update = requests.patch(
        f"{BASE_URL}/tracking/match_101?updateMask.fieldPaths=donorLocation",
        headers=headers_donor,
        json=donor_update
    )
    print(f"5. Donor update donorLocation -> status {r_donor_update.status_code}")
    assert r_donor_update.status_code == 200, f"Expected 200, got {r_donor_update.status_code}: {r_donor_update.text}"
    print("   [PASS] Donor can update permitted field donorLocation.")

    # 6. Chat rooms participant isolation
    chat_room_data = {
        "fields": {
            "roomId": {"stringValue": "room_alpha"},
            "participants": {
                "arrayValue": {
                    "values": [
                        {"stringValue": "donor_uid_1"},
                        {"stringValue": "req_uid_2"}
                    ]
                }
            }
        }
    }
    r_create_room = requests.patch(
        f"{BASE_URL}/chat_rooms/room_alpha",
        headers=headers_donor,
        json=chat_room_data
    )
    print(f"6. Participant create /chat_rooms/room_alpha -> status {r_create_room.status_code}")
    assert r_create_room.status_code == 200, f"Expected 200: {r_create_room.text}"
    print("   [PASS] Participant can create chat room.")

    # Stranger tries to read /chat_rooms/room_alpha
    r_stranger_room = requests.get(
        f"{BASE_URL}/chat_rooms/room_alpha",
        headers=headers_stranger
    )
    print(f"7. Stranger GET /chat_rooms/room_alpha -> status {r_stranger_room.status_code}")
    assert r_stranger_room.status_code == 403, f"Expected 403: {r_stranger_room.text}"
    print("   [PASS] Stranger blocked from reading chat room.")

    print("\nALL FIRESTORE RULES TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    test_rules()
