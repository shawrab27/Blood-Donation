# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import sys
import time
from unittest.mock import patch, MagicMock
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status

from api.models import BloodRequest, DonorProfile, RequestAcceptance
from api.services.storage import CloudinaryStorage


class CloudinaryMedicalFilesH1Tests(TestCase):
    """
    Tests H-1 Item 4:
    - Cloudinary medical files use authenticated delivery for uploads
    - generate_signed_url produces signed expiring URLs with future expiration
    - API returns signed, expiring URLs only to participants (requester, accepted donor, staff)
    - Public / unauthorized viewers receive None for medical files
    """

    def setUp(self):
        self.client = APIClient()

        # Users with completed profiles
        self.requester = User.objects.create_user(
            username='01711111111',
            email='requester@example.com',
            password='Password123!',
            first_name='Requester',
            last_name='User'
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester,
            blood_group='O+',
            district='Dhaka',
            phone_number='01711111111',
            is_available=True,
            is_profile_complete=True
        )

        self.accepted_donor = User.objects.create_user(
            username='01722222222',
            email='donor@example.com',
            password='Password123!',
            first_name='Accepted',
            last_name='Donor'
        )
        self.accepted_profile = DonorProfile.objects.create(
            user=self.accepted_donor,
            blood_group='O+',
            district='Dhaka',
            phone_number='01722222222',
            is_available=True,
            is_profile_complete=True
        )

        self.stranger_donor = User.objects.create_user(
            username='01733333333',
            email='stranger@example.com',
            password='Password123!',
            first_name='Stranger',
            last_name='Donor'
        )
        self.stranger_profile = DonorProfile.objects.create(
            user=self.stranger_donor,
            blood_group='A+',
            district='Dhaka',
            phone_number='01733333333',
            is_available=True,
            is_profile_complete=True
        )

        self.staff_user = User.objects.create_superuser(
            username='admin_staff',
            email='admin@example.com',
            password='Password123!',
            first_name='Admin',
            last_name='Staff'
        )
        self.staff_profile = DonorProfile.objects.create(
            user=self.staff_user,
            blood_group='B+',
            district='Dhaka',
            phone_number='01744444444',
            is_available=True,
            is_profile_complete=True
        )

        # Create BloodRequest with medical files
        dummy_photo = SimpleUploadedFile("patient.jpg", b"fake-patient-photo", content_type="image/jpeg")
        dummy_slip = SimpleUploadedFile("slip.jpg", b"fake-requisition-slip", content_type="image/jpeg")

        self.blood_req = BloodRequest.objects.create(
            requester=self.requester,
            patient_name='Patient Care',
            blood_group='O+',
            district='Dhaka',
            hospital_name_other='Dhaka Medical College',
            patient_photo=dummy_photo,
            requisition_slip=dummy_slip,
            status='ACCEPTED'
        )

        # Connect accepted donor
        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_req,
            donor=self.accepted_profile,
            status='ACCEPTED'
        )

    def test_cloudinary_upload_authenticated_delivery_with_mock(self):
        """Authenticated delivery flag is passed to Cloudinary uploader for medical uploads."""
        storage = CloudinaryStorage()
        mock_uploader = MagicMock()
        mock_uploader.upload.return_value = {
            'secure_url': 'https://res.cloudinary.com/testcloud/image/authenticated/patient_photo.jpg',
            'public_id': 'medical/patient_photo',
            'width': 640,
            'height': 480,
        }
        storage._uploader = mock_uploader
        storage._configured = True

        result = storage.upload_image(
            b'fake-image-bytes',
            'patient_photo.jpg',
            folder='bloodpulse/medical',
            delivery_type='authenticated'
        )

        self.assertEqual(result['delivery_type'], 'authenticated')
        mock_uploader.upload.assert_called_once()
        _, kwargs = mock_uploader.upload.call_args
        self.assertEqual(kwargs.get('type'), 'authenticated')

    def test_cloudinary_generate_signed_url_with_mock(self):
        """generate_signed_url requests signed URL with future expires_at from cloudinary.utils."""
        mock_cloud_utils = MagicMock()
        mock_cloud_utils.cloudinary_url.return_value = (
            'https://res.cloudinary.com/testcloud/image/authenticated/s--mock--/v1/patient.jpg',
            {}
        )
        mock_cloudinary = MagicMock()
        mock_cloudinary.utils = mock_cloud_utils

        with patch.dict(sys.modules, {'cloudinary': mock_cloudinary, 'cloudinary.utils': mock_cloud_utils}):
            storage = CloudinaryStorage()
            storage._configured = True
            storage._uploader = MagicMock()

            now = int(time.time())
            signed = storage.generate_signed_url(
                'medical/patient',
                resource_type='image',
                delivery_type='authenticated',
                expires_in_seconds=3600
            )

            mock_cloud_utils.cloudinary_url.assert_called_once()
            _, kwargs = mock_cloud_utils.cloudinary_url.call_args
            self.assertEqual(kwargs.get('type'), 'authenticated')
            self.assertTrue(kwargs.get('sign_url'))
            self.assertGreaterEqual(kwargs.get('expires_at'), now + 3500)
            self.assertIn('s--mock--', signed)

    def test_public_and_unauthorized_viewers_receive_none_for_medical_files(self):
        """Anonymous and non-participant users cannot see medical files (receive None)."""
        # Anonymous GET on emergency request endpoint
        resp_anon = self.client.get(f'/api/emergency/requests/{self.blood_req.id}/')
        self.assertEqual(resp_anon.status_code, status.HTTP_200_OK)
        self.assertIsNone(resp_anon.data.get('patient_photo'))
        self.assertIsNone(resp_anon.data.get('requisition_slip'))

        # Stranger donor GET on emergency request endpoint
        self.client.force_authenticate(user=self.stranger_donor)
        resp_stranger = self.client.get(f'/api/emergency/requests/{self.blood_req.id}/')
        self.assertEqual(resp_stranger.status_code, status.HTTP_200_OK)
        self.assertIsNone(resp_stranger.data.get('patient_photo'))
        self.assertIsNone(resp_stranger.data.get('requisition_slip'))

        # Stranger donor GET on requests V2 endpoint
        resp_stranger_v2 = self.client.get(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(resp_stranger_v2.status_code, status.HTTP_200_OK)
        self.assertIsNone(resp_stranger_v2.data.get('patient_photo'))
        self.assertIsNone(resp_stranger_v2.data.get('requisition_slip'))

    def test_participants_receive_signed_expiring_urls(self):
        """Requester, accepted donor, and staff receive signed expiring URLs."""
        # 1. Requester
        self.client.force_authenticate(user=self.requester)
        resp_req = self.client.get(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(resp_req.status_code, status.HTTP_200_OK)
        photo_url = resp_req.data.get('patient_photo')
        slip_url = resp_req.data.get('requisition_slip')
        self.assertIsNotNone(photo_url)
        self.assertIsNotNone(slip_url)
        self.assertTrue('exp=' in photo_url or 'sig=' in photo_url)
        self.assertTrue('exp=' in slip_url or 'sig=' in slip_url)

        # 2. Accepted donor
        self.client.force_authenticate(user=self.accepted_donor)
        resp_acc = self.client.get(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(resp_acc.status_code, status.HTTP_200_OK)
        self.assertIsNotNone(resp_acc.data.get('patient_photo'))
        self.assertIsNotNone(resp_acc.data.get('requisition_slip'))
        self.assertTrue('exp=' in resp_acc.data.get('patient_photo') or 'sig=' in resp_acc.data.get('patient_photo'))

        # 3. Staff user
        self.client.force_authenticate(user=self.staff_user)
        resp_staff = self.client.get(f'/api/requests/{self.blood_req.id}/')
        self.assertEqual(resp_staff.status_code, status.HTTP_200_OK)
        self.assertIsNotNone(resp_staff.data.get('patient_photo'))
        self.assertIsNotNone(resp_staff.data.get('requisition_slip'))
