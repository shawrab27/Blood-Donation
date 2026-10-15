# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date, timedelta
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    DonorProfile, DonationHistory, BloodGroupChangeRequest,
    DonorReview, XPEvent, BloodRequest, DonationMatch, RequestAcceptance,
    SocialPost, calculate_user_xp_and_level
)
from api.services.journeys import finalize_donation
from api.services.match_operations_service import _finalize_two_sided_match


@override_settings(EMAIL_PROVIDER='locmem')
class ProfileVerificationAndTabsTests(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()

        # Donor User & Profile
        self.donor_user = User.objects.create_user(
            username='donor_tareq',
            email='tareq@example.com',
            password='TestPassword123!',
            first_name='Tareq',
            last_name='Zaman'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group='A+',
            district='Chittagong',
            phone_number='+8801811112233',
            bio='Engineering student and active donor.',
            show_in_rankings=True,
            total_bags_donated=0,
            is_available=True,
            is_profile_complete=True
        )

        # Requester User & Profile
        self.requester_user = User.objects.create_user(
            username='requester_salma',
            email='salma@example.com',
            password='TestPassword123!',
            first_name='Salma',
            last_name='Akter'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group='B+',
            district='Chittagong',
            phone_number='+8801822223344',
            show_in_rankings=True,
            is_profile_complete=True
        )

        # Third User (Attacker / Other Viewer)
        self.other_user = User.objects.create_user(
            username='other_attacker',
            email='attacker@example.com',
            password='TestPassword123!'
        )
        self.other_profile = DonorProfile.objects.create(
            user=self.other_user,
            blood_group='AB+',
            district='Dhaka',
            phone_number='+8801899990000',
            show_in_rankings=True,
            is_profile_complete=True
        )

    # ──────────────────────────────────────────────────────────────────────────
    # 1. B.2: /profile/me/stories/, /profile/me/activity/, /profile/me/donations/
    # ──────────────────────────────────────────────────────────────────────────

    def test_profile_me_tabs_require_authentication(self):
        """Unauthenticated requests to /profile/me/* return 401."""
        self.client.logout()
        for endpoint in ['stories', 'activity', 'donations']:
            res = self.client.get(f'/api/profile/me/{endpoint}/')
            self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED, f"{endpoint} allowed anonymous")

    def test_profile_me_stories_ordering_and_isolation(self):
        """Stories are scoped to caller and strictly ordered by (-created_at, -id)."""
        s1 = SocialPost.objects.create(author=self.donor_profile, text_content="Old story")
        s2 = SocialPost.objects.create(author=self.donor_profile, text_content="Newer story")
        s_other = SocialPost.objects.create(author=self.other_profile, text_content="Secret other story")

        self.client.force_authenticate(user=self.donor_user)
        res = self.client.get('/api/profile/me/stories/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data['results']
        
        self.assertEqual(len(results), 2)
        # Verify ordering: newer first
        self.assertEqual(results[0]['id'], s2.id)
        self.assertEqual(results[1]['id'], s1.id)
        # Verify isolation: other user's story never returned
        story_ids = [r['id'] for r in results]
        self.assertNotIn(s_other.id, story_ids)

    def test_profile_me_activity_ordering_and_auto_verified_badge(self):
        """Activity cards are scoped to caller, ordered by (-created_at, -id), with auto_verified boolean."""
        req1 = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Jamal',
            blood_group='A+',
            units_needed=1,
            hospital_location='Chittagong Medical'
        )
        req2 = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Patient Rahim',
            blood_group='A+',
            units_needed=1,
            hospital_location='Chittagong Medical 2'
        )
        m1 = DonationMatch.objects.create(
            request=req1,
            donor=self.donor_profile,
            status='ACCEPTED'
        )
        m2 = DonationMatch.objects.create(
            request=req2,
            donor=self.donor_profile,
            status='DONATED'
        )

        self.client.force_authenticate(user=self.donor_user)
        res = self.client.get('/api/profile/me/activity/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data['results']
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]['id'], m2.id)
        self.assertFalse(results[0]['auto_verified'])
        self.assertFalse(results[1]['auto_verified'])

    def test_profile_me_donations_ordering_and_filters(self):
        """Donations return full details, correct ordering, and respect verified flag."""
        d1 = DonationHistory.objects.create(
            donor=self.donor_profile,
            donated_at=date(2025, 1, 10),
            date=date(2025, 1, 10),
            hospital='Apollo Hospital',
            city='Chittagong',
            bags=1,
            source='self_reported',
            verified=False,
            notes='Self reported donation'
        )
        d2 = DonationHistory.objects.create(
            donor=self.donor_profile,
            donated_at=date(2025, 6, 15),
            date=date(2025, 6, 15),
            hospital='CMCH',
            city='Chittagong',
            bags=1,
            source='verified',
            verified=True,
            notes='Verified emergency donation'
        )

        self.client.force_authenticate(user=self.donor_user)
        res = self.client.get('/api/profile/me/donations/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data['results']
        self.assertEqual(len(results), 2)
        # Most recent first
        self.assertEqual(results[0]['id'], d2.id)
        self.assertTrue(results[0]['verified'])
        self.assertEqual(results[0]['source'], 'verified')
        self.assertEqual(results[1]['id'], d1.id)
        self.assertFalse(results[1]['verified'])
        self.assertEqual(results[1]['source'], 'self_reported')

    def test_public_profile_detail_returns_404_for_suspended_or_inactive(self):
        """GET /api/profile/<id>/ returns 404 for suspended or inactive accounts."""
        self.donor_profile.is_suspended = True
        self.donor_profile.save()
        res = self.client.get(f'/api/profile/{self.donor_profile.id}/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

        self.donor_profile.is_suspended = False
        self.donor_profile.save()
        self.donor_user.is_active = False
        self.donor_user.save()
        res = self.client.get(f'/api/profile/{self.donor_profile.id}/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    # ──────────────────────────────────────────────────────────────────────────
    # 2. B.3: Verified Donation Lifecycle vs Self-Reported (XP & Leaderboard)
    # ──────────────────────────────────────────────────────────────────────────

    def test_verified_donation_lifecycle_end_to_end(self):
        """
        End-to-End verified donation flow:
        donate -> requester confirms -> verified=True -> XP +100 once (idempotent) -> appears in Top Donors.
        """
        req = BloodRequest.objects.create(
            requester=self.requester_user,
            patient_name='Mrs. Ayesha',
            blood_group='A+',
            units_needed=1,
            hospital_location='Chittagong General Hospital'
        )
        match = DonationMatch.objects.create(
            request=req,
            donor=self.donor_profile,
            status='ARRIVED',
            units_pledged=1
        )

        # Confirm donation via two-sided finalization
        now = timezone.now()
        _finalize_two_sided_match(req, match, now, note="Verified by requester")

        # 1. Verify DonationHistory record created with verified=True
        dh = DonationHistory.objects.filter(donor=self.donor_profile, linked_request=req).first()
        self.assertIsNotNone(dh)
        self.assertTrue(dh.verified)
        self.assertEqual(dh.source, 'verified')
        self.assertEqual(dh.bags, 1)

        # 2. Verify XPEvent created with 100 points
        xp_event = XPEvent.objects.filter(
            user=self.donor_user,
            event_type='donation',
            ref_type='DonationHistory',
            ref_id=str(dh.id)
        ).first()
        self.assertIsNotNone(xp_event)
        self.assertEqual(xp_event.points, 100)

        # Verify idempotency: calling finalize again does not add duplicate XP
        _finalize_two_sided_match(req, match, now)
        self.assertEqual(XPEvent.objects.filter(user=self.donor_user, event_type='donation').count(), 1)

        # 3. Verify total XP and level computed
        xp_data = calculate_user_xp_and_level(self.donor_user)
        self.assertEqual(xp_data['xp'], 100)
        self.assertEqual(xp_data['level'], 2)  # Level 2 threshold is 100 XP

        # 4. Verify donor appears in Top Donors
        self.client.force_authenticate(user=self.donor_user)
        res = self.client.get('/api/profile/top-donors/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        top_ids = [d['id'] for d in res.data['top_donors']]
        self.assertIn(self.donor_profile.id, top_ids)
        donor_entry = next(d for d in res.data['top_donors'] if d['id'] == self.donor_profile.id)
        self.assertEqual(donor_entry['bags'], 1)

    def test_self_reported_donation_gives_no_xp_and_no_rank(self):
        """Self-reported donation creates unverified history, 0 XP, and never appears in Top Donors."""
        dh = DonationHistory.objects.create(
            donor=self.donor_profile,
            donated_at=date(2025, 4, 1),
            date=date(2025, 4, 1),
            hospital='Private Clinic',
            bags=2,
            source='self_reported',
            verified=False
        )

        # 1. Verify NO XPEvent created
        xp_count = XPEvent.objects.filter(user=self.donor_user).count()
        self.assertEqual(xp_count, 0)
        xp_data = calculate_user_xp_and_level(self.donor_user)
        self.assertEqual(xp_data['xp'], 0)
        self.assertEqual(xp_data['level'], 1)

        # 2. Verify donor does NOT appear in Top Donors based on self-reported bags
        self.client.force_authenticate(user=self.donor_user)
        res = self.client.get('/api/profile/top-donors/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        top_ids = [d['id'] for d in res.data['top_donors']]
        self.assertNotIn(self.donor_profile.id, top_ids)

    # ──────────────────────────────────────────────────────────────────────────
    # 3. B.4: Blood Group Request Decision Deletes File Bytes
    # ──────────────────────────────────────────────────────────────────────────

    def test_admin_decision_deletes_confidential_report_file_bytes(self):
        """When admin approves or rejects a blood group change request, file bytes are wiped from storage."""
        admin_user = User.objects.create_superuser(
            username='admin_doc',
            email='admin@bloodpulse.org',
            password='AdminPassword123!'
        )

        # Create request with report bytes
        fake_pdf_bytes = b"%PDF-1.4 test confidential medical diagnostic report"
        change_req = BloodGroupChangeRequest.objects.create(
            user=self.donor_user,
            current_group='A+',
            requested_group='O+',
            reason='Hospital lab test showed retyping as O positive',
            lab_name='Popular Diagnostic Centre',
            test_date=date(2026, 1, 15),
            report_file_data=fake_pdf_bytes,
            report_file_name='diagnostic_report.pdf',
            report_file_content_type='application/pdf',
            report_file_size=len(fake_pdf_bytes),
            consent=True,
            status='pending'
        )
        self.assertIsNotNone(change_req.report_file_data)

        # Admin approves
        change_req.approve(admin_user=admin_user, notes="Verified against hospital records.")
        change_req.refresh_from_db()
        self.assertEqual(change_req.status, 'approved')
        # Crucial privacy assertion: file bytes wiped
        self.assertIsNone(change_req.report_file_data)
        # Donor profile blood group updated
        self.donor_profile.refresh_from_db()
        self.assertEqual(self.donor_profile.blood_group, 'O+')

        # Test reject also wipes file bytes
        change_req_reject = BloodGroupChangeRequest.objects.create(
            user=self.donor_user,
            current_group='O+',
            requested_group='AB+',
            reason='Retest',
            lab_name='Lab',
            test_date=date(2026, 2, 1),
            report_file_data=fake_pdf_bytes,
            consent=True,
            status='pending'
        )
        change_req_reject.reject(admin_user=admin_user, notes="Illegible scan.")
        change_req_reject.refresh_from_db()
        self.assertEqual(change_req_reject.status, 'rejected')
        self.assertIsNone(change_req_reject.report_file_data)

    # ──────────────────────────────────────────────────────────────────────────
    # 4. B.5: Additive Migrations 0053-0055 & Old Code Path Backward Compatibility
    # ──────────────────────────────────────────────────────────────────────────

    def test_additive_migrations_and_old_code_path_compatibility(self):
        """
        Verifies that code written against the pre-0053 schema can still insert and read
        DonationHistory and DonorProfile without error, and defaults populate cleanly.
        """
        # Old code path: creating DonationHistory using only legacy fields
        old_dh = DonationHistory.objects.create(
            donor=self.donor_profile,
            date=date(2024, 12, 1),
            bags_donated=2,
            location='Red Crescent Blood Bank'
        )
        old_dh.refresh_from_db()

        # Legacy fields accessible
        self.assertEqual(old_dh.date, date(2024, 12, 1))
        self.assertEqual(old_dh.bags_donated, 2)
        self.assertEqual(old_dh.location, 'Red Crescent Blood Bank')

        # Additive fields have valid, safe defaults
        self.assertFalse(old_dh.verified)
        self.assertEqual(old_dh.source, 'self_reported')
        self.assertEqual(old_dh.bags, 2)
        self.assertEqual(old_dh.volume_ml, 450)
        self.assertIsNone(old_dh.linked_request)
        self.assertEqual(old_dh.donated_at, date(2024, 12, 1))

        # Old code path: creating DonorProfile without new fields (bio, weight_kg, show_in_rankings)
        new_user = User.objects.create_user(username='legacy_user', email='leg@example.com')
        legacy_dp = DonorProfile.objects.create(
            user=new_user,
            blood_group='B-',
            district='Sylhet',
            phone_number='+8801900000099'
        )
        legacy_dp.refresh_from_db()
        self.assertTrue(legacy_dp.show_in_rankings)
        self.assertIsNone(legacy_dp.weight_kg)
        self.assertIn(legacy_dp.bio, [None, ''])
