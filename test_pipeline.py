import os
import sys
import django

# Setup Django environment
backend_path = os.path.join(os.path.dirname(__file__), 'blood_pulse_backend')
sys.path.insert(0, backend_path)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from api.models import DonorProfile, BloodRequest, EmailVerificationCode

def run_pipeline_test():
    print("==================================================")
    print("TESTING BLOODPULSE END-TO-END PIPELINE")
    print("==================================================")
    
    client = APIClient()
    
    # Step 0: Ensure a test user exists
    username = "test_pipeline_user"
    email = "pipeline_test@bloodpulse.org"
    password = "TestPassword123!"
    
    user, created = User.objects.get_or_create(username=username, defaults={"email": email})
    user.set_password(password)
    user.first_name = "Pipeline"
    user.last_name = "Tester"
    user.email = email
    user.save()
    
    profile, _ = DonorProfile.objects.get_or_create(
        user=user,
        defaults={
            "phone_number": "+8801711998877",
            "blood_group": "O-",
            "district": "Dhaka",
            "is_available": True,
            "is_verified": True,
            "email_verified": False,
        }
    )
    profile.phone_number = "+8801711998877"
    profile.blood_group = "O-"
    profile.district = "Dhaka"
    profile.save()
    
    # Authenticate via JWT token
    login_resp = client.post('/api/token/', {'username': username, 'password': password})
    if login_resp.status_code != 200:
        print(f"[-] Login failed: {login_resp.status_code}, {login_resp.data}")
        return False
    access_token = login_resp.data['access']
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
    print(f"[+] User authenticated with JWT Token.")

    # 1. Test GET /api/donors/
    print("\n--- 1. Testing GET /api/donors/ ---")
    donors_resp = client.get('/api/donors/')
    print(f"Status: {donors_resp.status_code}")
    assert donors_resp.status_code == status.HTTP_200_OK, "Failed to get donors"
    print(f"[PASS] Donors returned: {len(donors_resp.data) if isinstance(donors_resp.data, list) else donors_resp.data.get('count', len(donors_resp.data.get('results', [])))}")

    # 2. Test POST /api/auth/send-verification-email/
    print("\n--- 2. Testing POST /api/auth/send-verification-email/ ---")
    send_resp = client.post('/api/auth/send-verification-email/', {'email': email})
    print(f"Status: {send_resp.status_code}, Response: {send_resp.data}")
    assert send_resp.status_code == status.HTTP_200_OK, "Failed to send verification email"
    latest_code = EmailVerificationCode.objects.filter(user=user, is_used=False).first()
    assert latest_code is not None, "Verification code not created in DB"
    print(f"[PASS] Verification code generated in DB: {latest_code.code} for {latest_code.email}")

    # 3. Test POST /api/auth/verify-email-code/
    print("\n--- 3. Testing POST /api/auth/verify-email-code/ ---")
    verify_resp = client.post('/api/auth/verify-email-code/', {'code': latest_code.code, 'email': email})
    print(f"Status: {verify_resp.status_code}, Response: {verify_resp.data}")
    assert verify_resp.status_code == status.HTTP_200_OK, "Failed to verify email code"
    profile.refresh_from_db()
    assert profile.email_verified == True, "Profile email_verified is not True"
    print(f"[PASS] OTP verified successfully! profile.email_verified = {profile.email_verified}")

    # 4. Test POST /api/requests/
    print("\n--- 4. Testing POST /api/requests/ ---")
    req_payload = {
        "patient_name": "Sarah Jenkins",
        "blood_group": "O-",
        "urgency_level": "Critical",
        "hospital_location": "City General Trauma Wing, Dhaka",
        "contact_number": "+8801711223344",
        "reason": "Emergency surgery blood transfusion requirement",
        "units_needed": 2,
    }
    create_req_resp = client.post('/api/requests/', req_payload)
    print(f"Status: {create_req_resp.status_code}, Response: {create_req_resp.data}")
    assert create_req_resp.status_code in [status.HTTP_200_OK, status.HTTP_201_CREATED], "Failed to create blood request"
    print(f"[PASS] Emergency request broadcast successfully created! ID: {create_req_resp.data.get('id')}")

    # 5. Test GET /api/requests/
    print("\n--- 5. Testing GET /api/requests/ ---")
    list_req_resp = client.get('/api/requests/')
    print(f"Status: {list_req_resp.status_code}")
    assert list_req_resp.status_code == status.HTTP_200_OK, "Failed to list requests"
    print(f"[PASS] Requests listed successfully: {len(list_req_resp.data) if isinstance(list_req_resp.data, list) else list_req_resp.data.get('count', len(list_req_resp.data.get('results', [])))}")

    print("\n==================================================")
    print("ALL 5 BACKEND PIPELINE STEPS PASSED WITH 100% SUCCESS!")
    print("==================================================")
    return True

if __name__ == '__main__':
    success = run_pipeline_test()
    if not success:
        sys.exit(1)
