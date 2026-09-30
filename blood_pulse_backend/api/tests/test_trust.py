# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from api.models import Hospital, DonorProfile
from api.services.trust import calculate_trust_score, resolve_effective_scope


class TrustServiceTests(TestCase):
    def setUp(self):
        self.hospital = Hospital.objects.create(
            name='Test Medical College',
            district='Dhaka',
            is_verified=True,
        )
        self.user = User.objects.create_user(username='gooduser', password='pass', first_name="Test")
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='A+',
            district='Dhaka',
            phone_number='+8801999887766',
            fulfilled_count=2,
            no_show_count=0,
        )

    def test_trust_score_calculation(self):
        # Base (50) + verified hospital (15) + slip (20) + photo (10) + attendant (5) + fulfilled (10) = 110 -> clamped to 100
        score, band = calculate_trust_score(
            hospital=self.hospital,
            has_requisition_slip=True,
            has_patient_photo=True,
            attendant_name='Rahim',
            contact_phone='+8801700000000',
            requester=self.user,
        )
        self.assertEqual(score, 100)
        self.assertEqual(band, 'HIGH')

    def test_unverified_request_low_band(self):
        # Base (50) with no hospital and no slip
        bad_user = User.objects.create_user(username='baduser', password='pass', first_name="Test")
        DonorProfile.objects.create(
            user=bad_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='+8801555443322',
            no_show_count=1, # -25 penalty
        )
        score, band = calculate_trust_score(
            hospital=None,
            has_requisition_slip=False,
            requester=bad_user,
        )
        # 50 - 25 = 25
        self.assertEqual(score, 25)
        self.assertEqual(band, 'LOW')

    def test_scope_capping(self):
        # LOW trust band caps NATIONWIDE to LOCAL
        self.assertEqual(resolve_effective_scope('NATIONWIDE', 'LOW'), 'LOCAL')
        self.assertEqual(resolve_effective_scope('DIVISION', 'LOW'), 'LOCAL')

        # MEDIUM trust band caps NATIONWIDE to DISTRICT
        self.assertEqual(resolve_effective_scope('NATIONWIDE', 'MEDIUM'), 'DISTRICT')
        self.assertEqual(resolve_effective_scope('DISTRICT', 'MEDIUM'), 'DISTRICT')

        # HIGH trust band permits NATIONWIDE
        self.assertEqual(resolve_effective_scope('NATIONWIDE', 'HIGH'), 'NATIONWIDE')
