# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from api.models import BloodRequest, DonorProfile
from api.services.waves import get_candidate_donors_for_wave


class WaveEngineTests(TestCase):
    def setUp(self):
        # Create Requester
        self.req_user = User.objects.create_user(username='requester', password='password', first_name="Test")
        
        # Create Candidate Donors
        self.u1 = User.objects.create_user(username='donor_dhaka_local', password='password', first_name="Test")
        self.d1 = DonorProfile.objects.create(
            user=self.u1,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000001',
            is_available=True,
            is_searchable=True,
            latitude=23.8103,
            longitude=90.4125,
            rating_avg=4.9,
            alert_count=10,
            response_count=9,
        )

        self.u2 = User.objects.create_user(username='donor_chattogram', password='password', first_name="Test")
        self.d2 = DonorProfile.objects.create(
            user=self.u2,
            blood_group='O+',
            district='Chattogram',
            phone_number='+8801700000002',
            is_available=True,
            is_searchable=True,
            latitude=22.3569,
            longitude=91.7832,
            rating_avg=4.5,
        )

        # Incompatible donor (A+)
        self.u3 = User.objects.create_user(username='donor_incompatible', password='password', first_name="Test")
        self.d3 = DonorProfile.objects.create(
            user=self.u3,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801700000003',
            is_available=True,
            is_searchable=True,
            latitude=23.8105,
            longitude=90.4126,
        )

        # Request in Dhaka for O+ blood
        self.blood_req = BloodRequest.objects.create(
            requester=self.req_user,
            patient_name='Patient 1',
            blood_group='O+',
            component='WHOLE',
            district='Dhaka',
            lat=23.8104,
            lng=90.4125,
            scope='NATIONWIDE',
            effective_scope='NATIONWIDE',
            mode='EMERGENCY',
        )

    def test_wave_1_selects_local_compatible_donor(self):
        candidates = get_candidate_donors_for_wave(self.blood_req, wave_number=1)
        donor_ids = [c['donor'].id for c in candidates]
        self.assertIn(self.d1.id, donor_ids)
        self.assertNotIn(self.d2.id, donor_ids) # Chattogram is outside Wave 1 radius
        self.assertNotIn(self.d3.id, donor_ids) # A+ is incompatible with O+ recipient

    def test_wave_4_selects_nationwide_donor(self):
        candidates = get_candidate_donors_for_wave(self.blood_req, wave_number=4)
        donor_ids = [c['donor'].id for c in candidates]
        self.assertIn(self.d1.id, donor_ids)
        self.assertIn(self.d2.id, donor_ids) # In Wave 4, nationwide donors are included
        self.assertNotIn(self.d3.id, donor_ids) # Still excludes incompatible donor
