# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from io import StringIO
from unittest.mock import patch
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.contrib.auth import get_user_model

from api.models import Division, District, Upazila, DonorProfile
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS, EXPECTED_DIVISION_COUNTS
from api.data.bd_upazilas import BD_DISTRICT_UPAZILAS

User = get_user_model()


class SeedBDLocationsTests(TestCase):
    """
    Step 7b & H-01b: Seed BD Locations Management Command Tests:
    - 8 divisions, 64 districts created with canonical counts per division.
    - Canonical upazilas dataset validation (every name <= 100 chars, zero tree characters).
    - Idempotency: running --apply twice produces identical counts without duplicate records.
    - Dry-run: running without --apply or with --dry-run writes zero changes to the database.
    - Artifact detection: divisions/districts/upazilas with tree formatting characters (e.g. ├──)
      are identified and reported as artifacts without being deleted in standard mode.
    - Atomic rollback: failure during upazila seeding rolls back entire transaction leaving zero partial rows.
    - Offending name reporting: prints exact district and upazila on error.
    - Production safety guard: blocks execution if connected to ep-proud-dew.
    """

    def test_dry_run_creates_nothing(self):
        out = StringIO()
        call_command('seed_bd_locations', '--dry-run', stdout=out)
        output = out.getvalue()
        self.assertIn('SEED BANGLADESH LOCATIONS: Mode [DRY-RUN]', output)
        self.assertIn('[DRY-RUN] No changes were written. Use --apply to execute.', output)
        self.assertEqual(Division.objects.count(), 0)
        self.assertEqual(District.objects.count(), 0)
        self.assertEqual(Upazila.objects.count(), 0)

    def test_apply_seeds_exact_8_divisions_64_districts_and_canonical_upazilas(self):
        out = StringIO()
        call_command('seed_bd_locations', '--apply', stdout=out)
        output = out.getvalue()
        self.assertIn('Canonical targets: 8 divisions, 64 districts', output)
        self.assertIn('Database successfully seeded/updated with canonical BD locations!', output)

        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)
        self.assertEqual(Upazila.objects.count(), 492)

        # Verify exact counts per division
        for div_name, expected_count in EXPECTED_DIVISION_COUNTS.items():
            div = Division.objects.get(name=div_name)
            actual_count = District.objects.filter(division=div).count()
            self.assertEqual(
                actual_count,
                expected_count,
                f"Division {div_name} expected {expected_count} districts, got {actual_count}",
            )

        # Verify Pirojpur canonical upazilas (7 clean, no parsing leftovers)
        pirojpur_dist = District.objects.get(name='Pirojpur')
        pirojpur_ups = list(Upazila.objects.filter(district=pirojpur_dist).values_list('name', flat=True).order_by('name'))
        expected_pirojpur = sorted([
            'Bhandaria', 'Indurkani', 'Kawkhali', 'Mathbaria', 'Nazirpur', 'Nesarabad', 'Pirojpur Sadar'
        ])
        self.assertEqual(pirojpur_ups, expected_pirojpur)

    def test_seed_command_is_strictly_idempotent(self):
        # First run
        call_command('seed_bd_locations', '--apply')
        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)
        self.assertEqual(Upazila.objects.count(), 492)

        # Second run
        out2 = StringIO()
        call_command('seed_bd_locations', '--apply', stdout=out2)
        output2 = out2.getvalue()
        self.assertIn('Divisions: 8 existing, 0 to create', output2)
        self.assertIn('Districts: 64 matched, 0 to rename to canonical, 0 to create', output2)
        self.assertIn('(0 new upazilas created)', output2)
        self.assertEqual(Division.objects.count(), 8)
        self.assertEqual(District.objects.count(), 64)
        self.assertEqual(Upazila.objects.count(), 492)

    def test_all_upazila_names_in_dataset_are_clean_and_valid(self):
        tree_chars = {'├', '─', '└', '│', '┌', '┐', '┬', '┴', '┼'}
        canonical_districts = set()
        for dist_list in BD_DIVISIONS_AND_DISTRICTS.values():
            canonical_districts.update(dist_list)

        self.assertEqual(len(BD_DISTRICT_UPAZILAS), 64)
        self.assertEqual(set(BD_DISTRICT_UPAZILAS.keys()), canonical_districts)

        total_ups = 0
        for dist_name, up_names in BD_DISTRICT_UPAZILAS.items():
            self.assertGreater(len(up_names), 0, f"District {dist_name} has empty upazila list")
            seen_in_district = set()
            for up_name in up_names:
                total_ups += 1
                # Must be <= 100 characters for VarChar(100) DB column
                self.assertLessEqual(
                    len(up_name),
                    100,
                    f"Upazila '{up_name}' in district '{dist_name}' exceeds 100 chars (len={len(up_name)})"
                )
                # Must not contain tree characters
                for tc in tree_chars:
                    self.assertNotIn(
                        tc,
                        up_name,
                        f"Upazila '{up_name}' in district '{dist_name}' contains tree character '{tc}'"
                    )
                # Must not contain control characters or colons
                for bad_c in ':\n\r\t':
                    self.assertNotIn(
                        bad_c,
                        up_name,
                        f"Upazila '{up_name}' in district '{dist_name}' contains illegal char '{bad_c}'"
                    )
                # No duplicates inside the same district
                self.assertNotIn(
                    up_name,
                    seen_in_district,
                    f"Duplicate upazila '{up_name}' in district '{dist_name}'"
                )
                seen_in_district.add(up_name)

        self.assertEqual(total_ups, 492)

    def test_seeding_atomic_rollback_on_failure_leaves_zero_partial_rows_and_prints_offending(self):
        """Simulate an invalid upazila name in the dictionary to verify transaction rollback."""
        mock_upazilas = {
            'Dhaka': ['Dhamrai', 'Dohar'],
            'Faridpur': ['Alfa-danga', 'A' * 150],  # 150 chars exceeds 100 char limit!
        }

        err = StringIO()
        with patch('api.management.commands.seed_bd_locations.BD_DISTRICT_UPAZILAS', mock_upazilas):
            with self.assertRaises(ValueError):
                call_command('seed_bd_locations', '--apply', stderr=err)

        err_output = err.getvalue()
        # Verify the offending entity is printed
        self.assertIn("Offending entity: district='Faridpur'", err_output)
        self.assertIn("Upazila name exceeds 100 chars", err_output)

        # Verify atomic rollback: neither Dhaka nor Faridpur upazilas were persisted!
        self.assertEqual(Upazila.objects.count(), 0)

    def test_artifact_detection_and_reporting(self):
        artifact_div = Division.objects.create(name="├── Bogura")
        artifact_dist = District.objects.create(division=artifact_div, name="├── Bogura Sadar")
        Upazila.objects.create(district=artifact_dist, name="├── Bogura North")

        out = StringIO()
        call_command('seed_bd_locations', stdout=out)
        output = out.getvalue()

        self.assertIn('Found 1 artifact division rows, 1 artifact district rows, 1 artifact upazila rows:', output)
        self.assertTrue(Division.objects.filter(name="├── Bogura").exists())
        self.assertTrue(District.objects.filter(name="├── Bogura Sadar").exists())
        self.assertTrue(Upazila.objects.filter(name="├── Bogura North").exists())

    def test_production_safety_guard_blocks_execution(self):
        err = StringIO()
        with patch.dict('os.environ', {'DATABASE_URL': 'postgres://user:pass@ep-proud-dew.neon.tech/neondb'}):
            call_command('seed_bd_locations', '--apply', stderr=err)

        err_output = err.getvalue()
        self.assertIn('CRITICAL SAFETY VIOLATION', err_output)
        self.assertIn('ep-proud-dew', err_output)
        self.assertEqual(Division.objects.count(), 0)

    def test_donor_search_before_and_after_seed(self):
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
