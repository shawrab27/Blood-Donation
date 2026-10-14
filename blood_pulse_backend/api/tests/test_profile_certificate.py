# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from api.models import DonorProfile, DonationHistory
from api.services.certificate_service import (
    generate_donor_certificate_pdf,
    generate_verification_token,
    verify_certificate_token,
)

User = get_user_model()


@override_settings(EMAIL_PROVIDER='locmem')
class ProfileCertificateTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user_bengali = User.objects.create_user(
            username='rafiq_ahmed',
            email='rafiq@example.com',
            password='password123',
            first_name='রফিক',
            last_name='আহমেদ',
        )
        self.profile_bengali = DonorProfile.objects.create(
            user=self.user_bengali,
            phone_number='+8801711112222',
            blood_group='O+',
            is_profile_complete=True,
            total_bags_donated=2,
            district='Dhaka',
        )

        self.user_zero = User.objects.create_user(
            username='zero_donations',
            email='zero@example.com',
            password='password123',
            first_name='Zero',
            last_name='Donor',
        )
        self.profile_zero = DonorProfile.objects.create(
            user=self.user_zero,
            phone_number='+8801711113333',
            blood_group='A+',
            is_profile_complete=True,
            total_bags_donated=0,
            district='Chittagong',
        )

    def test_bengali_name_pdf_generation(self):
        """Test PDF generation with Bengali donor name produces valid PDF bytes."""
        pdf_bytes = generate_donor_certificate_pdf(self.profile_bengali, verified_bags=2)
        self.assertTrue(pdf_bytes.startswith(b'%PDF'))
        self.assertGreater(len(pdf_bytes), 1000)

    def test_certificate_download_blocked_with_zero_verified_donations(self):
        """Donors with 0 verified donations receive 400 NO_VERIFIED_DONATION."""
        # Add an unverified donation to ensure unverified does NOT grant certificate
        DonationHistory.objects.create(
            donor=self.profile_zero,
            donated_at=date(2025, 1, 1),
            hospital='Test Hospital',
            source='self_reported',
            verified=False,
            bags=1,
        )

        self.client.force_authenticate(user=self.user_zero)
        url = reverse('profile-me-certificate')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.json().get('code'), 'NO_VERIFIED_DONATION')

    def test_certificate_download_success_with_verified_donations(self):
        """Donors with >= 1 verified donation successfully download PDF."""
        DonationHistory.objects.create(
            donor=self.profile_bengali,
            donated_at=date(2025, 6, 1),
            hospital='Dhaka Medical College Hospital',
            source='verified',
            verified=True,
            bags=2,
        )

        self.client.force_authenticate(user=self.user_bengali)
        url = reverse('profile-me-certificate')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response['Content-Type'], 'application/pdf')
        self.assertIn('BloodPulse_Certificate_BP-D', response['Content-Disposition'])
        self.assertTrue(response.content.startswith(b'%PDF'))

    def test_certificate_verification_valid_token(self):
        """Valid signed certificate token returns minimal public facts."""
        issue_date = date(2026, 3, 15)
        token = generate_verification_token(self.profile_bengali, verified_bags=2, issue_date=issue_date)

        url = reverse('profile-certificate-verify')
        response = self.client.get(f"{url}?token={token}")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertTrue(data['valid'])
        self.assertEqual(data['name'], 'রফিক আহমেদ')
        self.assertEqual(data['blood_group'], 'O+')
        self.assertEqual(data['verified_bags'], 2)
        self.assertEqual(data['donor_id'], f"BP-D{self.profile_bengali.id:06d}")
        # Verify no sensitive PII is returned
        self.assertNotIn('phone_number', data)
        self.assertNotIn('weight_kg', data)

    def test_certificate_verification_tampered_token(self):
        """Tampered or invalid certificate token returns 400 Bad Request."""
        url = reverse('profile-certificate-verify')
        response = self.client.get(f"{url}?token=invalid-tampered-token-12345")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.json()['valid'])
