# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Happy path end-to-end verification script for Blood Hub v2:
accept -> on_the_way -> arrived -> donated -> thanks
"""

import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
os.environ['DJANGO_SETTINGS_MODULE'] = 'blood_pulse_backend.test_settings'
import django
django.setup()
from django.test import Client
from django.contrib.auth.models import User
from api.models import DonorProfile, District, Division, EmailOTP
from api.services.email import hash_otp

def run_happy_path():
    client = Client()
    div, _ = Division.objects.get_or_create(name='Dhaka')
    dist, _ = District.objects.get_or_create(name='Dhaka', division=div)

    req_user, _ = User.objects.get_or_create(username='req_curl_test', email='req_curl@test.com')
    req_user.set_password('Pass1234!')
    req_user.save()
    p_req, _ = DonorProfile.objects.get_or_create(user=req_user)
    p_req.full_name = 'Requester User'
    p_req.district = 'Dhaka'
    p_req.blood_group = 'O+'
    p_req.phone_number = '+8801711111111'
    p_req.is_profile_complete = True
    p_req.save()

    don_user, _ = User.objects.get_or_create(username='don_curl_test', email='don_curl@test.com')
    don_user.set_password('Pass1234!')
    don_user.save()
    p_don, _ = DonorProfile.objects.get_or_create(user=don_user)
    p_don.full_name = 'Donor User'
    p_don.district = 'Dhaka'
    p_don.blood_group = 'O+'
    p_don.phone_number = '+8801722222222'
    p_don.last_donation_date = None
    p_don.is_available = True
    p_don.is_profile_complete = True
    p_don.save()

    token_req = client.post('/api/token/', {'username': 'req_curl_test', 'password': 'Pass1234!'}, content_type='application/json').json()['access']
    token_don = client.post('/api/token/', {'username': 'don_curl_test', 'password': 'Pass1234!'}, content_type='application/json').json()['access']
    auth_req = {'HTTP_AUTHORIZATION': f'Bearer {token_req}'}
    auth_don = {'HTTP_AUTHORIZATION': f'Bearer {token_don}'}

    print("=== BLOOD HUB V2 HAPPY PATH TRACE ===")
    # 1. POST /api/requests/ (DRAFT)
    res_draft = client.post('/api/requests/', {
        'patient_name': 'Test Patient',
        'blood_group': 'O+',
        'units_needed': 1,
        'hospital_name_other': 'Dhaka Medical College Hospital',
        'contact_phone': '+8801711111111',
        'urgency': 'URGENT',
        'scope': 'LOCAL'
    }, content_type='application/json', **auth_req)
    req_id = res_draft.json()['id']
    print('1. POST /api/requests/ (DRAFT):', res_draft.status_code, res_draft.json()['status'])

    # 2. POST /api/requests/<id>/send-otp/
    res_send_otp = client.post(f'/api/requests/{req_id}/send-otp/', {}, **auth_req)
    print(f'2. POST /api/requests/{req_id}/send-otp/:', res_send_otp.status_code, res_send_otp.json())

    # Set known OTP hash
    otp_obj = EmailOTP.objects.filter(request_id=req_id).latest('created_at')
    otp_obj.otp_hash = hash_otp('654321', req_user.email)
    otp_obj.save()

    # 3. POST /api/requests/<id>/verify-otp/
    res_verify_otp = client.post(f'/api/requests/{req_id}/verify-otp/', {'otp': '654321'}, content_type='application/json', **auth_req)
    print(f'3. POST /api/requests/{req_id}/verify-otp/:', res_verify_otp.status_code, res_verify_otp.json()['status'])

    # 4. POST /api/requests/<id>/accept/
    res_accept = client.post(f'/api/requests/{req_id}/accept/', {}, **auth_don)
    print(f'4. POST /api/requests/{req_id}/accept/:', res_accept.status_code, res_accept.json())
    match_id = res_accept.json()['id']

    # 5. POST /api/matches/<id>/status/ (ON_THE_WAY)
    res_otw = client.post(f'/api/matches/{match_id}/status/', {'status': 'ON_THE_WAY'}, content_type='application/json', **auth_don)
    print(f'5. POST /api/matches/{match_id}/status/ (ON_THE_WAY):', res_otw.status_code, res_otw.json()['status'])

    # 6. POST /api/matches/<id>/status/ (ARRIVED)
    res_arr = client.post(f'/api/matches/{match_id}/status/', {'status': 'ARRIVED'}, content_type='application/json', **auth_don)
    print(f'6. POST /api/matches/{match_id}/status/ (ARRIVED):', res_arr.status_code, res_arr.json()['status'])

    # 7. POST /api/matches/<id>/status/ (DONATED)
    res_don = client.post(f'/api/matches/{match_id}/status/', {'status': 'DONATED'}, content_type='application/json', **auth_req)
    print(f'7. POST /api/matches/{match_id}/status/ (DONATED):', res_don.status_code, res_don.json()['status'])

    # 8. POST /api/matches/<id>/thanks/
    res_thanks = client.post(f'/api/matches/{match_id}/thanks/', {'template_key': 'heartfelt', 'body': 'Thank you so much for saving a life!'}, content_type='application/json', **auth_req)
    print(f'8. POST /api/matches/{match_id}/thanks/:', res_thanks.status_code, res_thanks.json())

if __name__ == '__main__':
    run_happy_path()
