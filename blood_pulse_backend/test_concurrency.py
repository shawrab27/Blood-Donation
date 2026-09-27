# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import django
import threading
import requests

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth.models import User
from api.models import BloodRequest, DonorProfile, RequestAcceptance
from rest_framework.test import APIClient

def setup_data():
    User.objects.filter(username__in=['requester1', 'donor1', 'donor2']).delete()
    BloodRequest.objects.all().delete()
    RequestAcceptance.objects.all().delete()

    requester = User.objects.create_user('requester1', 'req@test.com', 'testpass')
    donor1 = User.objects.create_user('donor1', 'donor1@test.com', 'testpass')
    DonorProfile.objects.create(user=donor1, blood_group='O+', phone_number='1234567891')
    donor2 = User.objects.create_user('donor2', 'donor2@test.com', 'testpass')
    DonorProfile.objects.create(user=donor2, blood_group='O+', phone_number='1234567892')

    req = BloodRequest.objects.create(
        requester=requester,
        patient_name='Test Patient',
        blood_group='O+',
        units_needed=1,
        status='ACTIVE'
    )
    return req, donor1, donor2

def accept_request(client, req_id, results, index):
    response = client.post(f'/api/emergency/requests/{req_id}/accept/')
    results[index] = response.status_code

def main():
    req, donor1, donor2 = setup_data()
    print(f"Created BloodRequest {req.id} needing {req.units_needed} units.")

    client1 = APIClient()
    client1.force_authenticate(user=donor1)
    
    client2 = APIClient()
    client2.force_authenticate(user=donor2)

    results = [None, None]
    
    t1 = threading.Thread(target=accept_request, args=(client1, req.id, results, 0))
    t2 = threading.Thread(target=accept_request, args=(client2, req.id, results, 1))

    t1.start()
    t2.start()

    t1.join()
    t2.join()

    print(f"Donor 1 acceptance status code: {results[0]}")
    print(f"Donor 2 acceptance status code: {results[1]}")
    
    acceptances = RequestAcceptance.objects.filter(request=req)
    print(f"Total acceptances in DB: {acceptances.count()}")
    for a in acceptances:
        print(f" - Acceptance by {a.donor.user.username}, status: {a.status}")

if __name__ == '__main__':
    main()
