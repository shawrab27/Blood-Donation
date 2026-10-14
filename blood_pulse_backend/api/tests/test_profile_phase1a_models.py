# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from api.models import (
    DonorProfile, DonationHistory, BloodGroupChangeRequest,
    DonorReview, XPEvent, BloodRequest, RequestAcceptance,
    calculate_user_xp_and_level, award_verified_donation_xp
)
from api.serializers import DonorProfileSerializer


class ProfilePhase1AModelsTests(TestCase):
    def setUp(self):
        # Admin user
        self.admin_user = User.objects.create_superuser(
            username='admin_pulse',
            email='admin@bloodpulse.org',
            password='AdminPassword123!'
        )

        # Donor user
        self.donor_user = User.objects.create_user(
            username='donor_rahim',
            email='rahim@bloodpulse.org',
            password='Password123!',
            first_name='Rahim',
            last_name='Uddin'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801700000001',
            bio='Voluntary blood donor.',
            weight_kg=70,
            show_in_rankings=True,
            total_bags_donated=2,
            is_available=True,
            is_profile_complete=True,
        )

        # Requester user
        self.requester_user = User.objects.create_user(
            username='requester_karim',
            email='karim@bloodpulse.org',
            password='Password123!',
            first_name='Karim',
            last_name='Ahmed'
        )

        # Blood Request
        self.blood_req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Karim',
            blood_group='O+',
            units_needed=1,
            status='FULFILLED'
        )

    def test_bio_max_length_validation(self):
        """Bio longer than 120 chars must fail validation."""
        serializer = DonorProfileSerializer(
            instance=self.donor_profile,
            data={'bio': 'A' * 121},
            partial=True
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('bio', serializer.errors)

        valid_serializer = DonorProfileSerializer(
            instance=self.donor_profile,
            data={'bio': 'A' * 120},
            partial=True
        )
        self.assertTrue(valid_serializer.is_valid())

    def test_blood_group_is_read_only_for_non_staff(self):
        """Non-staff user cannot directly change their blood group."""
        class MockRequest:
            user = self.donor_user

        serializer = DonorProfileSerializer(
            instance=self.donor_profile,
            data={'blood_group': 'A+'},
            partial=True,
            context={'request': MockRequest()}
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('blood_group', serializer.errors)

    def test_blood_group_can_be_changed_by_admin(self):
        """Staff/admin CAN change blood group."""
        class MockAdminRequest:
            user = self.admin_user

        serializer = DonorProfileSerializer(
            instance=self.donor_profile,
            data={'blood_group': 'A+'},
            partial=True,
            context={'request': MockAdminRequest()}
        )
        self.assertTrue(serializer.is_valid())

    def test_donation_history_additive_fields_and_sync(self):
        """DonationHistory syncs date and donated_at, bags and bags_donated."""
        dh = DonationHistory.objects.create(
            donor=self.donor_profile,
            date=date(2026, 1, 15),
            location='Dhaka Medical College',
            hospital='DMCH',
            city='Dhaka',
            donation_type='WHOLE',
            how='VOLUNTARY',
            bags=2,
            volume_ml=450,
            source='self_reported',
            verified=False
        )
        self.assertEqual(dh.donated_at, date(2026, 1, 15))
        self.assertEqual(dh.bags_donated, 2)
        self.assertEqual(dh.source, 'self_reported')
        self.assertFalse(dh.verified)

    def test_blood_group_change_request_flow_and_one_open_request_rule(self):
        """Only one open BloodGroupChangeRequest per user allowed."""
        req1 = BloodGroupChangeRequest.objects.create(
            user=self.donor_user,
            current_group='O+',
            requested_group='A+',
            reason='Correction from recent lab test',
            lab_name='Popular Diagnostic',
            test_date=date(2026, 2, 1),
            consent=True,
            status='pending'
        )
        self.assertIsNotNone(req1.id)

        # Attempting a second open request should fail clean()
        req2 = BloodGroupChangeRequest(
            user=self.donor_user,
            current_group='O+',
            requested_group='B+',
            reason='Second request',
            status='pending'
        )
        with self.assertRaises(ValidationError):
            req2.clean()

        # Admin approval changes the user's DonorProfile.blood_group
        req1.approve(admin_user=self.admin_user, notes="Verified lab slip")
        req1.refresh_from_db()
        self.assertEqual(req1.status, 'approved')
        self.assertEqual(req1.reviewed_by, self.admin_user)

        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.blood_group, 'A+')

    def test_donor_review_rules_and_aggregates(self):
        """DonorReview rules: requester only, cannot review self, rating_avg updated."""
        # 1. Reviewer cannot be the donor themselves
        self_review = DonorReview(
            reviewer=self.donor_user,
            donor=self.donor_profile,
            blood_request=self.blood_req,
            stars=5,
            comment="Self rating"
        )
        with self.assertRaises(ValidationError):
            self_review.clean()

        # 2. Reviewer must be the requester
        unrelated_user = User.objects.create_user(username='stranger', password='pw')
        stranger_review = DonorReview(
            reviewer=unrelated_user,
            donor=self.donor_profile,
            blood_request=self.blood_req,
            stars=5
        )
        with self.assertRaises(ValidationError):
            stranger_review.clean()

        # 3. Valid review by requester updates donor rating_avg and rating_count
        review = DonorReview.objects.create(
            reviewer=self.requester_user,
            donor=self.donor_profile,
            blood_request=self.blood_req,
            stars=5,
            tag="Punctual",
            comment="Arrived immediately at hospital. Life saver!"
        )
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.rating_avg, 5.0)
        self.assertEqual(self.donor_profile.rating_count, 1)

        # 4. Only one review per blood_request
        with self.assertRaises(Exception):
            DonorReview.objects.create(
                reviewer=self.requester_user,
                donor=self.donor_profile,
                blood_request=self.blood_req,
                stars=4
            )

    def test_xp_event_idempotency_and_level_calculation(self):
        """XPEvent unique constraint prevents duplicate awards; levels computed on server."""
        dh_unverified = DonationHistory.objects.create(
            donor=self.donor_profile,
            date=date(2026, 1, 1),
            location='Hospital',
            source='self_reported',
            verified=False
        )
        # Unverified donation awards NO XP
        self.assertIsNone(award_verified_donation_xp(dh_unverified))

        dh_verified = DonationHistory.objects.create(
            donor=self.donor_profile,
            date=date(2026, 1, 10),
            location='Hospital',
            source='verified',
            verified=True
        )
        # Verified donation awards 100 XP
        event1 = award_verified_donation_xp(dh_verified)
        self.assertIsNotNone(event1)
        self.assertEqual(event1.points, 100)

        # Idempotency: awarding again returns existing event without creating duplicate
        event2 = award_verified_donation_xp(dh_verified)
        self.assertEqual(event1.id, event2.id)
        self.assertEqual(XPEvent.objects.filter(user=self.donor_user).count(), 1)

        # Calculate user level & progress
        xp_info = calculate_user_xp_and_level(self.donor_user)
        self.assertEqual(xp_info['xp'], 100)
        self.assertEqual(xp_info['level'], 2) # 100 points reaches Level 2 (thresholds: L1=0, L2=100, L3=300)
        self.assertEqual(xp_info['next_level_xp'], 300)
        self.assertEqual(xp_info['progress'], 0.0) # at L2 baseline (100-100)/(300-100) = 0.0
