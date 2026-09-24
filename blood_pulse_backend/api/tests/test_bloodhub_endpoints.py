import uuid
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from api.models import Hospital, DonorProfile, BloodRequest, RequestAcceptance


class BloodHubEndpointsIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(username='requester_user', password='password123')
        
        # Donor
        self.donor_user = User.objects.create_user(username='donor_user', password='password123')
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            campus='Dhaka University',
            phone_number='+8801712345678',
            is_available=True,
            is_searchable=True,
            latitude=23.8103,
            longitude=90.4125,
            rating_avg=4.8,
            total_bags_donated=4,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            name_en='Dhaka Medical College Hospital',
            name_bn='ঢাকা মেডিকেল কলেজ হাসপাতাল',
            district='Dhaka',
            address='Secretariat Rd, Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
            is_referral_center=True,
        )

    def test_hospital_directory_autocomplete(self):
        response = self.client.get('/api/hospitals/directory/?q=Dhaka')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertGreaterEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'Dhaka Medical College Hospital')

    def test_donor_search_privacy_masking(self):
        response = self.client.get('/api/donors/search/?blood_group=O%2B&district=Dhaka')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['total'], 1)
        res = data['results'][0]
        # Verify phone is masked
        self.assertNotIn('+8801712345678', res['phone_masked'])
        self.assertTrue('****' in res['phone_masked'] or '***' in res['phone_masked'])

    def test_donor_map_fuzzed_coordinates(self):
        response = self.client.get('/api/donors/map/?blood_group=O%2B')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertGreaterEqual(data['count'], 1)
        donor_pin = data['donors'][0]
        # Verify coordinate is fuzzed (not exact 23.8103, 90.4125)
        self.assertNotEqual((donor_pin['lat'], donor_pin['lng']), (23.8103, 90.4125))

    def test_create_emergency_request_idempotent(self):
        req_id = str(uuid.uuid4())
        payload = {
            'patient_name': 'Abdur Rahman',
            'blood_group': 'O+',
            'component': 'WHOLE',
            'units_needed': 2,
            'urgency': 'CRITICAL_2H',
            'hospital_id': self.hospital.id,
            'ward_bed': 'ICU Bed 4',
            'attendant_name': 'Fatima',
            'contact_phone': '+8801811223344',
            'scope': 'LOCAL',
            'client_request_id': req_id,
        }

        # First POST creates request
        response = self.client.post('/api/emergency/requests/', payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        first_id = response.json()['id']
        self.assertEqual(response.json()['trust_band'], 'MEDIUM')

        # Duplicate POST with same client_request_id returns existing
        response_dup = self.client.post('/api/emergency/requests/', payload)
        self.assertEqual(response_dup.status_code, status.HTTP_200_OK)
        self.assertEqual(response_dup.json()['id'], first_id)

    def test_request_detail_role_based_masking(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Tanvir',
            blood_group='O+',
            hospital=self.hospital,
            ward_bed='Ward 3, Bed 12',
            contact_phone='+8801912345678',
        )

        # Anonymous view: phone is masked, ward_bed is protected
        anon_resp = self.client.get(f'/api/emergency/requests/{req.id}/')
        self.assertEqual(anon_resp.status_code, status.HTTP_200_OK)
        self.assertIn('****', anon_resp.json()['contact_phone_display'])
        self.assertIn('Protected', anon_resp.json()['ward_bed_display'])

        # Requester view: unmasked
        self.client.force_authenticate(user=self.requester_user)
        req_resp = self.client.get(f'/api/emergency/requests/{req.id}/')
        self.assertEqual(req_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(req_resp.json()['contact_phone_display'], '+8801912345678')
        self.assertEqual(req_resp.json()['ward_bed_display'], 'Ward 3, Bed 12')

    def test_accept_request_unmasks_contact(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient X',
            blood_group='O+',
            hospital=self.hospital,
            ward_bed='Bed 7',
            contact_phone='+8801799887766',
            status='ACTIVE',
        )

        # Donor accepts request
        self.client.force_authenticate(user=self.donor_user)
        resp = self.client.post(f'/api/emergency/requests/{req.id}/accept/')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        data = resp.json()
        self.assertEqual(data['requester_phone'], '+8801799887766')
        self.assertEqual(data['ward_bed'], 'Bed 7')

        # Now donor viewing details sees unmasked contact info
        detail_resp = self.client.get(f'/api/emergency/requests/{req.id}/')
        self.assertEqual(detail_resp.json()['contact_phone_display'], '+8801799887766')
        self.assertEqual(detail_resp.json()['ward_bed_display'], 'Bed 7')

    def test_report_fake_request_auto_quarantine(self):
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Suspect Request',
            blood_group='AB-',
            hospital=self.hospital,
            status='ACTIVE',
        )

        u1 = User.objects.create_user(username='u1', password='p')
        u2 = User.objects.create_user(username='u2', password='p')
        u3 = User.objects.create_user(username='u3', password='p')

        self.client.force_authenticate(user=u1)
        self.client.post(f'/api/emergency/requests/{req.id}/report/', {'reason': 'Fake phone'})

        self.client.force_authenticate(user=u2)
        self.client.post(f'/api/emergency/requests/{req.id}/report/', {'reason': 'Patient does not exist'})

        self.client.force_authenticate(user=u3)
        self.client.post(f'/api/emergency/requests/{req.id}/report/', {'reason': 'Scam post'})

        req.refresh_from_db()
        self.assertEqual(req.status, 'PENDING_ADMIN')
        self.assertTrue(req.escalated_to_admin)
