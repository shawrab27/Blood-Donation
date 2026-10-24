# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from api.models import DonorProfile, Division, District
from api.serializers import DonorProfileSerializer

class AuthGapsTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.division = Division.objects.create(name='Dhaka')
        self.district = District.objects.create(division=self.division, name='Dhaka')

    def test_google_user_unfinished_registration_can_update_blood_group(self):
        """
        G2 (a): Google user who left registration unfinished (is_profile_complete=False)
        registers again with blood_group: must succeed, no 'cannot be altered' error.
        """
        user = User.objects.create_user(
            username='google_user_test',
            email='test_google@gmail.com',
            first_name='Google',
            last_name='User'
        )
        # Incomplete profile with a default or prior tentative blood group (missing district)
        profile = DonorProfile.objects.create(
            user=user,
            blood_group='A+',
            phone_number='01711000001',
            district='',
            is_profile_complete=False
        )

        self.client.force_authenticate(user=user)

        # 1. Test via ProfileMeView PATCH
        response = self.client.patch('/api/profile/me/', {'blood_group': 'B+'}, format='json')
        if response.status_code != 200:
            print("DEBUG PATCH ERROR:", response.data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        profile.refresh_from_db()
        self.assertEqual(profile.blood_group, 'B+')

        # 2. Test via DonorProfileSerializer
        serializer = DonorProfileSerializer(
            instance=profile,
            data={'blood_group': 'O+'},
            partial=True
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        serializer.save()
        profile.refresh_from_db()
        self.assertEqual(profile.blood_group, 'O+')

    def test_complete_registration_submit_containing_is_verified_silently_ignored(self):
        """
        G2 (b): Complete Registration submit containing is_verified:
        must succeed with the field silently ignored (never raises ValidationError).
        """
        user = User.objects.create_user(
            username='donor_submit_test',
            email='donor_submit@gmail.com'
        )
        profile = DonorProfile.objects.create(
            user=user,
            blood_group='O+',
            phone_number='01711000002',
            district='Dhaka',
            is_verified=False,
            is_profile_complete=False
        )
        self.client.force_authenticate(user=user)

        # Attempt to set is_verified=True in payload
        serializer = DonorProfileSerializer(
            instance=profile,
            data={'is_verified': True, 'weight_kg': 65},
            partial=True
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        saved_instance = serializer.save()
        profile.refresh_from_db()
        # Field must be silently ignored, not modified
        self.assertFalse(profile.is_verified)
        self.assertEqual(profile.weight_kg, 65)

    def test_blood_group_change_after_registration_completed_rejected_with_human_message(self):
        """
        G2 (c): blood_group change after registration completed (is_profile_complete=True):
        rejected with human message (S3), never raw JSON or allowed alteration.
        """
        user = User.objects.create_user(
            username='completed_donor',
            email='completed@gmail.com',
            first_name='Completed',
            last_name='Donor'
        )
        profile = DonorProfile.objects.create(
            user=user,
            blood_group='AB+',
            phone_number='01711000003',
            district='Dhaka',
            is_profile_complete=True
        )
        self.client.force_authenticate(user=user)

        # Attempt to alter blood group via PATCH
        response = self.client.patch('/api/profile/me/', {'blood_group': 'O+'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        error_msg = response.data.get('blood_group')
        self.assertTrue(error_msg)
        self.assertIn("cannot be directly modified", str(error_msg[0]))

        # Attempt to alter blood group via Serializer
        serializer = DonorProfileSerializer(
            instance=profile,
            data={'blood_group': 'O+'},
            partial=True
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn('blood_group', serializer.errors)
        self.assertIn("Blood group cannot be altered once registered", str(serializer.errors['blood_group'][0]))
