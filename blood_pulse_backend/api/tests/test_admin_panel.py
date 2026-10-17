# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from rest_framework import status
from api.models import (
    Hospital, DonorProfile, BloodRequest, RequestAcceptance,
    DirectMessage, StandbyOffer, UserDevice, DonationMatch, EmergencyNotification
)

User = get_user_model()


class AdminPanelRegistrationTests(TestCase):
    def setUp(self):
        self.staff_user = User.objects.create_superuser(
            username='staff_admin',
            email='staff@example.com',
            password='AdminPassword123!',
            is_staff=True,
            is_superuser=True
        )
        self.regular_user = User.objects.create_user(
            username='donor_user',
            email='donor@example.com',
            password='DonorPassword123!'
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.regular_user,
            blood_group='O+',
            phone_number='01700000001',
            district='Dhaka'
        )
        self.hospital = Hospital.objects.create(
            name='Dhaka Medical College Hospital',
            district='Dhaka',
            lat=23.7259,
            lng=90.3976,
            is_verified=True
        )
        self.blood_request = BloodRequest.objects.create(
            requester=self.staff_user,
            patient_name='Emergency Patient',
            blood_group='O+',
            district='Dhaka',
            hospital=self.hospital,
            units_needed=2,
            request_mode='CRITICAL'
        )
        self.acceptance = RequestAcceptance.objects.create(
            request=self.blood_request,
            donor=self.donor_profile,
            status='ACCEPTED'
        )

    def test_unauthenticated_admin_access_redirects_to_login(self):
        response = self.client.get('/admin/api/directmessage/')
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)

    def test_staff_admin_can_access_all_registered_models(self):
        self.client.force_login(self.staff_user)

        model_endpoints = [
            '/admin/api/directmessage/',
            '/admin/api/standbyoffer/',
            '/admin/api/userdevice/',
            '/admin/api/donationmatch/',
            '/admin/api/emergencynotification/',
            '/admin/api/donorprofile/',
            '/admin/api/bloodrequest/',
        ]
        for url in model_endpoints:
            with self.subTest(url=url):
                response = self.client.get(url)
                self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_direct_message_admin_dismiss_report_action(self):
        self.client.force_login(self.staff_user)
        msg = DirectMessage.objects.create(
            acceptance=self.acceptance,
            sender=self.staff_user,
            recipient=self.regular_user,
            content='Testing direct message report dismissal',
            is_reported=True,
            report_reason='Spam probe'
        )

        response = self.client.post('/admin/api/directmessage/', {
            'action': 'dismiss_reports',
            '_selected_action': [msg.pk]
        })
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)
        msg.refresh_from_db()
        self.assertFalse(msg.is_reported)
        self.assertEqual(msg.report_reason, '')

    def test_user_device_admin_revoke_and_restore_actions(self):
        self.client.force_login(self.staff_user)
        device = UserDevice.objects.create(
            user=self.regular_user,
            device_id='device_test_123',
            device_name='Pixel 8',
            platform='android',
            is_revoked=False
        )

        # Test revoke
        response = self.client.post('/admin/api/userdevice/', {
            'action': 'revoke_selected_devices',
            '_selected_action': [device.pk]
        })
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)
        device.refresh_from_db()
        self.assertTrue(device.is_revoked)

        # Test restore
        response = self.client.post('/admin/api/userdevice/', {
            'action': 'restore_selected_devices',
            '_selected_action': [device.pk]
        })
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)
        device.refresh_from_db()
        self.assertFalse(device.is_revoked)

    def test_standby_offer_admin_expire_action(self):
        self.client.force_login(self.staff_user)
        offer = StandbyOffer.objects.create(
            request=self.blood_request,
            donor=self.donor_profile,
            status='PENDING',
            expires_at=timezone.now() + timedelta(minutes=5)
        )

        response = self.client.post('/admin/api/standbyoffer/', {
            'action': 'expire_selected_offers',
            '_selected_action': [offer.pk]
        })
        self.assertEqual(response.status_code, status.HTTP_302_FOUND)
        offer.refresh_from_db()
        self.assertEqual(offer.status, 'EXPIRED')

    def test_donation_match_admin_actions(self):
        self.client.force_login(self.staff_user)
        match = DonationMatch.objects.create(
            request=self.blood_request,
            donor=self.donor_profile,
            status='ACCEPTED',
            role='PRIMARY'
        )

        # Mark arrived
        self.client.post('/admin/api/donationmatch/', {
            'action': 'mark_arrived',
            '_selected_action': [match.pk]
        })
        match.refresh_from_db()
        self.assertEqual(match.status, 'ARRIVED')

        # Mark donated
        self.client.post('/admin/api/donationmatch/', {
            'action': 'mark_donated',
            '_selected_action': [match.pk]
        })
        match.refresh_from_db()
        self.assertEqual(match.status, 'DONATED')
