# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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
        self.requester = User.objects.create_user(username='req_user', password='pass', first_name="Test")
        
        # Primary Donor
        self.donor_user = User.objects.create_user(username='primary_donor', password='pass', first_name="Test")
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
        self.standby_user = User.objects.create_user(username='standby_donor', password='pass', first_name="Test")
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
        other_user = User.objects.create_user(username='stranger', password='pass', first_name="Test")
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
        
        # Requester confirms
        self.client.force_authenticate(user=self.requester)
        resp3 = self.client.post(f'/api/journeys/{self.acceptance.id}/status/', {'status': 'CONFIRMED'})
        self.assertEqual(resp3.status_code, status.HTTP_200_OK)

        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'CONFIRMED')
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

    def test_auto_confirm_stale_donations(self):
        from api.services.journeys import auto_confirm_stale_donations
        from datetime import timedelta
        from django.utils import timezone

        self.acceptance.status = 'DONATED'
        self.acceptance.donated_at = timezone.now() - timedelta(hours=50)
        self.acceptance.save()

        closed = auto_confirm_stale_donations(hours=48)
        self.assertEqual(len(closed), 1)
        self.assertEqual(closed[0].id, self.acceptance.id)

        self.acceptance.refresh_from_db()
        self.assertEqual(self.acceptance.status, 'CONFIRMED')
        self.assertTrue(self.acceptance.auto_confirmed)
        self.assertIsNotNone(self.acceptance.completed_at)
        
        self.blood_req.refresh_from_db()
        self.assertEqual(self.blood_req.status, 'FULFILLED')

    def test_location_update_throttled_server_side(self):
        self.client.force_authenticate(user=self.donor_user)

        # 1st update succeeds
        resp1 = self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': 23.8105,
            'lng': 90.4128,
        })
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.assertEqual(resp1.json()['status'], 'updated')

        # Immediate 2nd update within 10s is throttled
        resp2 = self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': 23.8106,
            'lng': 90.4129,
        })
        self.assertEqual(resp2.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertEqual(resp2.json()['status'], 'throttled')
        self.assertIn('retry_after_seconds', resp2.json())

        # Advance last_location_update by 15s -> 3rd update succeeds
        self.acceptance.refresh_from_db()
        self.acceptance.last_location_update = timezone.now() - timedelta(seconds=15)
        self.acceptance.save(update_fields=['last_location_update'])

        resp3 = self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': 23.8107,
            'lng': 90.4130,
        })
        self.assertEqual(resp3.status_code, status.HTTP_200_OK)
        self.assertEqual(resp3.json()['status'], 'updated')

    def test_location_stopped_on_inactive_journey_and_privacy_shielded(self):
        # Requester sees location while journey is active
        self.client.force_authenticate(user=self.donor_user)
        self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': 23.8103,
            'lng': 90.4125,
        })

        # Mark journey arrived -> inactive
        self.acceptance.status = 'ARRIVED'
        self.acceptance.save(update_fields=['status'])

        # Posting location while stopped returns 200 with ignored status
        post_resp = self.client.post(f'/api/journeys/{self.acceptance.id}/location/', {
            'lat': 23.8103,
            'lng': 90.4125,
        })
        self.assertEqual(post_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(post_resp.json()['status'], 'ignored')

        # Requester cannot see coordinates once journey is inactive (privacy rule)
        self.client.force_authenticate(user=self.requester)
        get_resp = self.client.get(f'/api/journeys/{self.acceptance.id}/location/')
        self.assertEqual(get_resp.status_code, status.HTTP_200_OK)
        data = get_resp.json()
        self.assertFalse(data['is_tracking_active'])
        self.assertIsNone(data['donor_lat'])
        self.assertIsNone(data['donor_lng'])

    def test_standby_auto_triggered_when_donor_cancels_active_journey(self):
        self.client.force_authenticate(user=self.donor_user)

        cancel_resp = self.client.post(f'/api/journeys/{self.acceptance.id}/status/', {
            'status': 'CANCELLED',
            'reason': 'Flat tire on bike, unable to reach hospital in time',
        })
        self.assertEqual(cancel_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(cancel_resp.json()['status'], 'CANCELLED')
        self.assertTrue(cancel_resp.json()['standby_triggered'])

        # Standby offer created for ranked standby donor
        offer = StandbyOffer.objects.filter(request=self.blood_req, donor=self.standby_profile).first()
        self.assertIsNotNone(offer)
        self.assertEqual(offer.status, 'PENDING')

    def test_cleanup_stale_tracking_command_dry_run_and_execution(self):
        from django.core.management import call_command
        from io import StringIO

        now = timezone.now()

        # 1. Stale standby offer
        stale_offer = StandbyOffer.objects.create(
            request=self.blood_req,
            donor=self.standby_profile,
            status='PENDING',
            expires_at=now - timedelta(minutes=5),
        )

        # 2. Inactive no-show journey
        self.acceptance.status = 'ON_THE_WAY'
        self.acceptance.started_at = now - timedelta(minutes=75)
        self.acceptance.last_location_update = now - timedelta(minutes=70)
        self.acceptance.save(update_fields=['status', 'started_at', 'last_location_update'])
        stale_acc = self.acceptance

        out = StringIO()
        call_command('cleanup_stale_tracking', '--timeout-minutes', '60', '--dry-run', stdout=out)
        output = out.getvalue()
        self.assertIn('[DRY-RUN]', output)
        self.assertIn('Expired Standby Offers: 1', output)
        self.assertIn('Timed-out No-Show Journeys: 1', output)

        # Dry-run must not mutate database
        stale_offer.refresh_from_db()
        self.assertEqual(stale_offer.status, 'PENDING')
        stale_acc.refresh_from_db()
        self.assertEqual(stale_acc.status, 'ON_THE_WAY')

        # Real run mutates database
        out_real = StringIO()
        call_command('cleanup_stale_tracking', '--timeout-minutes', '60', stdout=out_real)
        real_output = out_real.getvalue()
        self.assertIn('Cleanup completed successfully.', real_output)

        stale_offer.refresh_from_db()
        self.assertEqual(stale_offer.status, 'EXPIRED')

        stale_acc.refresh_from_db()
        self.assertEqual(stale_acc.status, 'FAILED')
        self.assertIn('Automated no-show timeout', stale_acc.cancellation_reason)

        self.donor_profile.refresh_from_db()
        self.assertGreater(self.donor_profile.no_show_count, 0)

