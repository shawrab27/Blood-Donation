# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Comprehensive test suite for the BloodPulse post-accept journey state machine,
timeline event logging, acceptance invariants, race condition handling,
idempotency, and standby donor selection/escalation.
"""

from datetime import timedelta
from django.utils import timezone
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestTimelineEvent,
    CompatibilityRule,
    StandbyOffer,
)
from api.services.blood_hub_lifecycle_service import (
    transition,
    IllegalStateTransitionError,
)
from api.services.standby import (
    trigger_standby_donor_offer,
    process_stale_tracking_and_standby_tick,
)


class JourneyStateMachineTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username='req_user', password='password123', email='req@example.com', first_name='Requester'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801711111111',
            is_profile_complete=True,
            is_available=False,
        )

        # Donor 1 (Eligible B+)
        self.donor_user1 = User.objects.create_user(
            username='donor_user1', password='password123', email='d1@example.com', first_name='DonorOne'
        )
        self.donor_profile1 = DonorProfile.objects.create(
            user=self.donor_user1,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801722222222',
            is_available=True,
            is_profile_complete=True,
            latitude=23.8103,
            longitude=90.4125,
        )

        # Donor 2 (Eligible O+)
        self.donor_user2 = User.objects.create_user(
            username='donor_user2', password='password123', email='d2@example.com', first_name='DonorTwo'
        )
        self.donor_profile2 = DonorProfile.objects.create(
            user=self.donor_user2,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801733333333',
            is_available=True,
            is_profile_complete=True,
            latitude=23.8120,
            longitude=90.4130,
        )

        # Hospital
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
        )

        # Compatibility rule: B+ can receive from B+, O+
        CompatibilityRule.objects.create(
            blood_group='B+',
            can_give_to='B+, AB+',
            can_receive_from='B+, B-, O+, O-',
        )
        CompatibilityRule.objects.create(
            blood_group='O+',
            can_give_to='A+, B+, AB+, O+',
            can_receive_from='O+, O-',
        )

    def test_canonical_journey_state_transitions_and_timeline_events(self):
        """Valid canonical state chain OPEN -> ACCEPTED -> DONOR_ON_THE_WAY -> ARRIVED -> DONATED -> COMPLETED writes timeline events."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )

        # 1. ACCEPTED
        req = transition(req, 'ACCEPTED', self.donor_user1, note='Donor accepted')
        self.assertEqual(req.status, 'ACCEPTED')
        events = RequestTimelineEvent.objects.filter(request=req)
        self.assertEqual(events.count(), 1)
        self.assertEqual(events.last().who, self.donor_user1)
        self.assertEqual(events.last().state, 'ACCEPTED')

        # 2. DONOR_ON_THE_WAY
        req = transition(req, 'DONOR_ON_THE_WAY', self.donor_user1, note='Donor on the way')
        self.assertEqual(req.status, 'DONOR_ON_THE_WAY')
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 2)

        # 3. ARRIVED
        req = transition(req, 'ARRIVED', self.donor_user1, note='Donor arrived at hospital')
        self.assertEqual(req.status, 'ARRIVED')
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 3)

        # 4. DONATED
        req = transition(req, 'DONATED', self.donor_user1, note='Donation completed')
        self.assertEqual(req.status, 'DONATED')
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 4)

        # 5. COMPLETED
        req = transition(req, 'COMPLETED', self.requester_user, note='Requester confirmed receipt')
        self.assertEqual(req.status, 'COMPLETED')
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 5)

    def test_illegal_state_transition_rejected(self):
        """Illegal transition directly from OPEN to COMPLETED or ARRIVED raises 409 IllegalStateTransitionError."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        with self.assertRaises(IllegalStateTransitionError):
            transition(req, 'ARRIVED', self.donor_user1)

        with self.assertRaises(IllegalStateTransitionError):
            transition(req, 'COMPLETED', self.requester_user)

    def test_idempotent_duplicate_state_transition(self):
        """Applying the same transition twice returns the request without error and does not duplicate timeline event."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        req = transition(req, 'ACCEPTED', self.donor_user1)
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 1)

        # Second identical transition
        req = transition(req, 'ACCEPTED', self.donor_user1)
        self.assertEqual(req.status, 'ACCEPTED')
        self.assertEqual(RequestTimelineEvent.objects.filter(request=req).count(), 1)

    def test_requester_cannot_accept_own_request(self):
        """Requester attempting to accept their own request is rejected with 400 Bad Request."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        self.client.force_authenticate(user=self.requester_user)
        res = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('own', str(res.data).lower())

    def test_donor_in_cooldown_cannot_accept(self):
        """Donor with last donation < 90 days ago cannot accept request."""
        self.donor_profile1.last_donation_date = timezone.now().date() - timedelta(days=30)
        self.donor_profile1.save()

        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        self.client.force_authenticate(user=self.donor_user1)
        res = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertIn(res.status_code, [status.HTTP_400_BAD_REQUEST, status.HTTP_409_CONFLICT])
        self.assertIn('cooldown', str(res.data).lower())

    def test_donor_snoozed_cannot_accept(self):
        """Donor with active emergency snooze/pause cannot accept request."""
        self.donor_profile1.emergency_alerts_paused_until = timezone.now() + timedelta(hours=2)
        self.donor_profile1.alert_pause_until = timezone.now() + timedelta(hours=2)
        self.donor_profile1.save()

        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        self.client.force_authenticate(user=self.donor_user1)
        res = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertIn(res.status_code, [status.HTTP_400_BAD_REQUEST, status.HTTP_409_CONFLICT])
        self.assertIn('pause', str(res.data).lower())

    def test_two_donors_last_unit_race_one_wins_other_gets_slot_taken(self):
        """When 1 unit is needed, first donor wins (201) and second donor receives 409 Conflict 'slot taken' / 'already filled'."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )

        # Donor 1 accepts
        self.client.force_authenticate(user=self.donor_user1)
        res1 = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Donor 2 tries to accept the now-full request
        self.client.force_authenticate(user=self.donor_user2)
        res2 = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_409_CONFLICT)
        self.assertTrue('slot' in str(res2.data).lower() or 'filled' in str(res2.data).lower() or 'units' in str(res2.data).lower())

    def test_standby_trigger_on_donor_cancellation(self):
        """When accepted donor cancels ('I can't donate'), status moves to STANDBY_SEARCHING and offer is generated."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='OPEN',
            units_needed=1,
        )
        self.client.force_authenticate(user=self.donor_user1)
        res_accept = self.client.post(f'/api/requests/{req.id}/accept/', {}, format='json')
        self.assertEqual(res_accept.status_code, status.HTTP_201_CREATED)
        acceptance_id = res_accept.data.get('acceptance_id')

        # Donor cancels via journey status transition endpoint
        res_cancel = self.client.post(
            f'/api/journeys/{acceptance_id}/status/',
            {'status': 'CANCELLED', 'reason': "I can't donate"},
            format='json',
        )
        self.assertEqual(res_cancel.status_code, status.HTTP_200_OK)

        req.refresh_from_db()
        self.assertEqual(req.status, 'STANDBY_SEARCHING')

        # An offer should have been dispatched to donor_user2 (eligible O+)
        offers = StandbyOffer.objects.filter(request=req)
        self.assertTrue(offers.exists())
        self.assertEqual(offers.first().donor, self.donor_profile2)

    def test_standby_tick_idempotency(self):
        """Running the standby maintenance tick twice does not duplicate offers or transitions."""
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='STANDBY_SEARCHING',
            units_needed=1,
        )
        # First tick creates candidate offer
        process_stale_tracking_and_standby_tick()
        count1 = StandbyOffer.objects.filter(request=req).count()

        # Second tick immediately after should be a no-op
        process_stale_tracking_and_standby_tick()
        count2 = StandbyOffer.objects.filter(request=req).count()
        self.assertEqual(count1, count2)

    def test_standby_ladder_escalation_when_no_nearby_candidate(self):
        """When no donor is within 5km, search escalates radius ladder (5 -> 25 -> 100 -> 1000 km)."""
        # Place donor 2 50 km away
        self.donor_profile2.latitude = 24.2
        self.donor_profile2.longitude = 90.4
        self.donor_profile2.save()

        req = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group='B+',
            hospital=self.hospital,
            status='STANDBY_SEARCHING',
            units_needed=1,
        )
        # Exclude donor1 so donor2 (50km away) is picked after radius ladder escalates past 5km and 25km
        offer = trigger_standby_donor_offer(req, exclude_donor_ids=[self.donor_profile1.id])
        self.assertIsNotNone(offer)
        self.assertEqual(offer.donor, self.donor_profile2)
