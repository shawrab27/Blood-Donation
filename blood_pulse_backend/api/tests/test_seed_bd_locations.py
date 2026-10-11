# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from io import StringIO
from django.core.management import call_command
from django.test import TestCase
from django.contrib.auth import get_user_model

from api.models import Division, District, DonorProfile
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS, EXPECTED_DIVISION_COUNTS

User = get_user_model()


class SeedBDLocationsTests(TestCase):
    """
    Step 7b: Seed BD Locations Management Command Tests:
    - 8 divisions, 64 districts created with canonical counts per division.
    - Idempotency: running --apply twice produces identical counts without duplicate records.
    - Dry-run: running without --apply or with --dry-run writes zero changes to the database.
    - Artifact detection: divisions/districts with tree formatting characters (e.g. ├──)
      are identified and reported as artifacts without being deleted in standard mode.
    - Donor search stability: donor profile district lookups before and after seed yield identical results.
    """

    def test_dry_run_creates_nothing(self):
        out = StringIO()
        call_command('seed_bd_locations', '--dry-run', stdout=out)
        output = out.getvalue()
        self.assertIn('SEED BANGLADESH LOCATIONS: Mode [DRY-RUN]', output)
        self.assertIn('[DRY-RUN] No changes were written. Use --apply to execute.', output)
        self.assertEqual(Division.objects.count(), 0)
        self.assertEqual(District.objects.count(), 0)

    def test_apply_seeds_exact_8_divisions_and_64_districts(self):
        out = StringIO()
        call_command('seed_bd_locations', '--apply', stdout=out)
        output = out.getvalue()
        self.assertIn('Canonical targets: 8 divisions, 64 districts', output)
        self.assertIn('Database successfully seeded/updated with canonical BD locations!', output)

        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)

        # Verify exact counts per division
        for div_name, expected_count in EXPECTED_DIVISION_COUNTS.items():
            div = Division.objects.get(name=div_name)
            actual_count = District.objects.filter(division=div).count()
            self.assertEqual(
                actual_count,
                expected_count,
                f"Division {div_name} expected {expected_count} districts, got {actual_count}",
            )

    def test_seed_command_is_strictly_idempotent(self):
        # First run
        call_command('seed_bd_locations', '--apply')
        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)

        # Second run
        out2 = StringIO()
        call_command('seed_bd_locations', '--apply', stdout=out2)
        output2 = out2.getvalue()
        self.assertIn('Divisions: 8 existing, 0 to create', output2)
        self.assertIn('Districts: 64 matched, 0 to rename to canonical, 0 to create', output2)
        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)

    def test_artifact_detection_and_reporting(self):
        # Create an artifact division with tree-drawing characters
        artifact_div = Division.objects.create(name="├── Bogura")
        District.objects.create(division=artifact_div, name="├── Bogura Sadar")

        out = StringIO()
        call_command('seed_bd_locations', stdout=out)
        output = out.getvalue()

        # Command should detect and report the artifact without deleting it
        self.assertIn('Found 1 artifact division rows:', output)
        self.assertIn('Bogura', output)
        self.assertTrue(Division.objects.filter(name="├── Bogura").exists())

    def test_donor_search_before_and_after_seed(self):
        # Create donor with canonical district name
        u = User.objects.create_user(username='dhaka_donor', email='dhaka_donor@bloodpulse.org', password='password')
        DonorProfile.objects.create(
            user=u,
            blood_group='A+',
            district='Dhaka',
            is_available=True,
            is_profile_complete=True,
        )

        count_before = DonorProfile.objects.filter(district='Dhaka', blood_group='A+').count()
        self.assertEqual(count_before, 1)

        # Run seed
        call_command('seed_bd_locations', '--apply')

        count_after = DonorProfile.objects.filter(district='Dhaka', blood_group='A+').count()
        self.assertEqual(count_after, 1)
