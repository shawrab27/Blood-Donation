from datetime import timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    DonationIssue,
    StandbyOffer,
    DeferralRecord,
    DonationHistory,
)


class LiveTrackingAndStandbyTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester = User.objects.create_user(username='req_user', password='pass')
        
        # Primary Donor
        self.donor_user = User.objects.create_user(username='primary_donor', password='pass')
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000010',
            is_available=True,
            is_searchable=True,
            latitude=23.8103,
            longitude=90.4125,
        )

        # Standby Backup Donor
        self.standby_user = User.objects.create_user(username='standby_donor', password='pass')
        self.standby_profile = DonorProfile.objects.create(
            user=self.standby_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000020',
            is_available=True,
            is_searchable=True,
            latitude=23.8110,
            longitude=90.4130,
            rating_avg=4.9,
        )

        # Destination Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True,
        )

        # Active Blood Request
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Patient Karim',
            blood_group='O+',
            component='WHOLE',
            units_needed=1,
            hospital=self.hospital,
            ward_bed='ICU Bed 2',
            contact_phone='+8801800000000',
            lat=23.7259,
            lng=90.3976,
            status='ACTIVE',
        )

        # Initial Acceptance
        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.donor_profile,
            status='ACCEPTED',
        )

    def test_donor_location_update_and_eta_calculation(self):
        self.client.force_authenticate(user=self.donor_user)
        
        # Donor sends live GPS: ~10km from hospital
        donor_lat, donor_lng = 23.8103, 90.4125
        resp = self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': donor_lat,
            'lng': donor_lng,
        })
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertEqual(data['status'], 'updated')
        self.assertGreater(data['distance_km'], 8.0)
        self.assertGreater(data['eta_minutes'], 0)

        # Requester reads the updated location and destination
        self.client.force_authenticate(user=self.requester)
        get_resp = self.client.get(f'/api/journeys/{self.acceptance.id}/location/')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        get_data = get_resp.json()
        self.assertEqual(get_data['donor_lat'], donor_lat)
        self.assertIn('destination', get_data)

    def test_unauthorized_user_location_access_forbidden(self):
        other_user = User.objects.create_user(username='stranger', password='pass')
        self.client.force_authenticate(user=other_user)

        resp = self.client.get(f'/api/journeys/{self.acceptance.id}/location/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_journey_status_transition_to_donated_updates_metrics(self):
        self.client.force_authenticate(user=self.donor_user)

        # Donor marks ON_THE_WAY
        resp1 = self.client.post(f'/api/journeys/{self.acceptance.id}/status/', {'status': 'ON_THE_WAY'})
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'ON_THE_WAY')

        # Donor completes donation: DONATED
        resp2 = self.client.post(f'/api/journeys/{self.acceptance.id}/status/', {'status': 'DONATED'})
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)

        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'DONATED')
        self.assertIsNotNone(self.acceptance.completed_at)

        self.blood_req.refresh_from_db()
        self.assertEqual(self.blood_req.status, 'FULFILLED')
        self.assertFalse(self.blood_req.is_active)

        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.fulfilled_count, 1)
        self.assertEqual(self.donor_profile.total_bags_donated, 1)
        self.assertEqual(self.donor_profile.last_donation_date, timezone.now().date())

        # Verify DonationHistory record created
        history = DonationHistory.objects.filter(donor=self.donor_profile).first()
        self.assertIsNotNone(history)
        self.assertEqual(history.bags_donated, 1)

    def test_medical_rejection_defers_donor_and_triggers_standby(self):
        self.client.force_authenticate(user=self.donor_user)

        resp = self.client.post(f'/api/journeys/{self.acceptance.id}/issue/', {
            'issue_type': 'MEDICAL_REJECTION',
            'description': 'Hemoglobin test returned 11.2 g/dL (minimum 12.5 required)',
        })
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        data = resp.json()
        self.assertTrue(data['standby_triggered'])
        self.assertIsNotNone(data['standby_offer_id'])

        # Journey failed
        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'FAILED')

        # Donor deferral applied
        self.donor_profile.refresh_from_db()
        self.assertIsNotNone(self.donor_profile.deferral_until)
        self.assertGreater(self.donor_profile.deferral_until, timezone.now())

        deferral = DeferralRecord.objects.filter(donor=self.donor_profile).first()
        self.assertIsNotNone(deferral)
        self.assertEqual(deferral.reason_code, 'MEDICAL')

        # Standby offer created for standby donor
        offer = StandbyOffer.objects.get(id=data['standby_offer_id'])
        self.assertEqual(offer.donor, self.standby_profile)
        self.assertEqual(offer.status, 'PENDING')

    def test_standby_donor_accepts_offer_and_takes_over_journey(self):
        # Create pending standby offer
        offer = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.standby_profile,
            status='PENDING',
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        self.client.force_authenticate(user=self.standby_user)
        
        # Standby donor reads offer
        get_resp = self.client.get(f'/api/standby/{offer.id}/')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        self.assertGreater(get_resp.json()['seconds_remaining'], 0)

        # Standby donor responds ACCEPT
        post_resp = self.client.post(f'/api/standby/{offer.id}/respond/', {'action': 'ACCEPT'})
        self.assertEqual(post_resp.status_code, status.HTTP_200_OK)
        self.assertIn('requester_phone', post_resp.json())
        self.assertEqual(post_resp.json()['requester_phone'], '+8801800000000')

        offer.refresh_from_db()
        self.assertEqual(offer.status, 'ACCEPTED')

        # Verify new RequestAcceptance created with is_standby=True
        new_acc = RequestAcceptance.objects.filter(request=self.blood_req, donor=self.standby_profile).first()
        self.assertIsNotNone(new_acc)
        self.assertTrue(new_acc.is_standby)
        self.assertEqual(new_acc.status, 'ACCEPTED')
