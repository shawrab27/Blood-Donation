# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth.models import User
from api.models import BloodRequest, DonorProfile, RequestAcceptance
from rest_framework.test import APIClient

def setup_data():
    User.objects.filter(username__in=['zombie_user', 'other_req']).delete()
    
    zombie = User.objects.create_user('zombie_user', 'zombie@test.com', 'testpass')
    profile = DonorProfile.objects.create(user=zombie, blood_group='O+', phone_number='9999999999', is_available=True)
    
    # Create an active blood request by the zombie user
    req = BloodRequest.objects.create(
        requester=zombie,
        patient_name='Zombie Patient',
        blood_group='O+',
        units_needed=1,
        status='ACTIVE'
    )

    # Create 5 past successful donations (RequestAcceptances) by the zombie user
    other_requester = User.objects.create_user('other_req', 'other@test.com', 'testpass')
    for i in range(5):
        past_req = BloodRequest.objects.create(
            requester=other_requester,
            patient_name=f'Past Patient {i}',
            blood_group='A+',
            units_needed=1,
            status='FULFILLED'
        )
        RequestAcceptance.objects.create(
            request=past_req,
            donor=profile,
            status='FULFILLED'
        )

    return zombie, profile, req

def main():
    zombie, profile, req = setup_data()
    print(f"Before deletion: BloodRequest exists? {BloodRequest.objects.filter(id=req.id).exists()}")
    print(f"Before deletion: RequestAcceptances by user? {RequestAcceptance.objects.filter(donor=profile).count()}")

    client = APIClient()
    client.force_authenticate(user=zombie)
    
    response = client.delete(f'/api/donors/{profile.id}/')
    
    print(f"Delete status code: {response.status_code}")
    print(f"After deletion: BloodRequest exists? {BloodRequest.objects.filter(id=req.id).exists()}")
    print(f"After deletion: RequestAcceptances by user? {RequestAcceptance.objects.filter(donor__id=profile.id).count()}")

if __name__ == '__main__':
    main()
