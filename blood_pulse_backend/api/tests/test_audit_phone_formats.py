# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import io
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.core.management import call_command
from api.models import DonorProfile

User = get_user_model()


class AuditPhoneFormatsCommandTests(TestCase):
    def setUp(self):
        # Create test users and profiles with distinct phone formats
        self.u1 = User.objects.create_user(username='user_01', password='pw')
        self.u2 = User.objects.create_user(username='01711112233', password='pw')
        self.u3 = User.objects.create_user(username='user_88', password='pw')

        DonorProfile.objects.create(user=self.u1, phone_number='01711112233', blood_group='A+')
        DonorProfile.objects.create(user=self.u2, phone_number='+8801711112233', blood_group='B+')
        DonorProfile.objects.create(user=self.u3, phone_number='8801811223344', blood_group='O+')

    def test_audit_phone_formats_detects_distribution_and_duplicate(self):
        out = io.StringIO()
        call_command('audit_phone_formats', stdout=out)
        output = out.getvalue()

        # Checks format headers
        self.assertIn("Phone Format & Normalization Audit", output)
        self.assertIn("01... (11 digits)", output)
        self.assertIn("+8801... (canonical E.164)", output)
        self.assertIn("8801... (13 digits)", output)

        # Detects duplicate cluster between 01711112233 and +8801711112233
        self.assertIn("Potential Duplicate Phone Clusters]: 1", output)

        # Detects phone-like username (01711112233)
        self.assertIn("Phone-like usernames: 1", output)
        self.assertIn("Audit complete. No rows modified.", output)
