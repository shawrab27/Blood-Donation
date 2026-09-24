from django.test import TestCase
from api.services.compat import (
    get_compatible_donor_groups,
    is_compatible,
    normalize_blood_group,
)


class CompatibilityServiceTests(TestCase):
    def test_normalize_blood_group(self):
        self.assertEqual(normalize_blood_group('A_POS'), 'A+')
        self.assertEqual(normalize_blood_group('O_NEG'), 'O-')
        self.assertEqual(normalize_blood_group('b+'), 'B+')
        self.assertEqual(normalize_blood_group('AB-'), 'AB-')

    def test_rbc_compatibility_matrix(self):
        # O- is universal red blood cell donor
        for recipient in ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']:
            self.assertTrue(is_compatible('O-', recipient, 'RBC'))
            self.assertTrue(is_compatible('O-', recipient, 'WHOLE'))

        # AB+ is universal red blood cell recipient
        for donor in ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']:
            self.assertTrue(is_compatible(donor, 'AB+', 'RBC'))

        # Incompatible pairings
        self.assertFalse(is_compatible('A+', 'O+', 'RBC'))
        self.assertFalse(is_compatible('B+', 'A+', 'RBC'))
        self.assertFalse(is_compatible('AB+', 'A+', 'RBC'))
        self.assertFalse(is_compatible('A+', 'A-', 'RBC'))

    def test_plasma_compatibility_matrix(self):
        # AB is universal plasma donor
        for recipient in ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']:
            self.assertTrue(is_compatible('AB+', recipient, 'PLASMA'))

        # O can only give plasma to O
        self.assertTrue(is_compatible('O+', 'O+', 'PLASMA'))
        self.assertFalse(is_compatible('O+', 'A+', 'PLASMA'))
        self.assertFalse(is_compatible('O+', 'AB+', 'PLASMA'))
