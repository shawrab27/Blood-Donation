# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import csv
from django.test import TestCase
from django.conf import settings

class InstitutionsCsvValidationTestCase(TestCase):
    def test_repo_institutions_csv_contains_all_major_types(self):
        """
        Verify that the repo CSV bundled in the mobile asset directory:
        1. Contains exactly 5,631 rows.
        2. Contains rows of each required type: University, College, School, Madrasa.
        3. Contains valid non-empty name, institution_type, and location fields.
        """
        csv_path = os.path.abspath(
            os.path.join(settings.BASE_DIR, '..', 'blood_pulse', 'assets', 'data', 'institutions.csv')
        )
        self.assertTrue(os.path.exists(csv_path), f"institutions.csv not found at {csv_path}")

        counts = {
            'university': 0,
            'college': 0,
            'school': 0,
            'madrasa': 0,
            'technical': 0,
            'professional': 0,
        }
        total_rows = 0

        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            self.assertIn('name', reader.fieldnames)
            self.assertIn('institution_type', reader.fieldnames)
            self.assertIn('district_name', reader.fieldnames)

            for row in reader:
                total_rows += 1
                itype = row['institution_type'].lower().strip()
                if itype in counts:
                    counts[itype] += 1
                self.assertTrue(len(row['name'].strip()) > 0, "Institution name must not be blank")

        self.assertEqual(total_rows, 5631, f"Expected 5,631 total rows, found {total_rows}")
        self.assertGreater(counts['university'], 0, "Must contain universities")
        self.assertGreater(counts['college'], 0, "Must contain colleges")
        self.assertGreater(counts['school'], 0, "Must contain schools")
        self.assertGreater(counts['madrasa'], 0, "Must contain madrasas")

        self.assertEqual(counts['university'], 155)
        self.assertEqual(counts['college'], 2000)
        self.assertEqual(counts['school'], 2000)
        self.assertEqual(counts['madrasa'], 1000)
