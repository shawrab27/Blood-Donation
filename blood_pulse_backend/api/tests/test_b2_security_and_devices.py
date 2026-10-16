# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken, OutstandingToken, BlacklistedToken
from api.models import UserDevice, Notification, DonorProfile


class B2SecurityAndDevicesTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user_a = User.objects.create_user(
            username='01711111111',
            email='usera@example.com',
            password='Password123!',
            first_name='Alice'
        )
        self.profile_a = DonorProfile.objects.create(
            user=self.user_a,
            phone_number='01711111111',
            district='Dhaka',
            blood_group='A+'
        )

        self.user_b = User.objects.create_user(
            username='01722222222',
            email='userb@example.com',
            password='Password123!',
            first_name='Bob'
        )
        self.profile_b = DonorProfile.objects.create(
            user=self.user_b,
            phone_number='01722222222',
            district='Chittagong',
            blood_group='B+'
        )

    def test_guest_cannot_access_protected_device_endpoints(self):
        """Unauthenticated requests must be rejected with 401."""
        endpoints = [
            ('get', '/api/account/devices/'),
            ('post', '/api/account/devices/1/revoke/'),
            ('post', '/api/account/devices/logout-all/'),
            ('post', '/api/auth/password-change/'),
        ]
        for method, path in endpoints:
            handler = getattr(self.client, method)
            resp = handler(path)
            self.assertEqual(
                resp.status_code, 401,
                f"Guest was not rejected with 401 on {method.upper()} {path}"
            )

    def test_device_creation_on_login_and_list(self):
        """Logging in registers a UserDevice; GET /account/devices/ lists user devices with current indicator."""
        resp = self.client.post(
            '/api/token/',
            {
                'phone': '01711111111',
                'password': 'Password123!',
            },
            HTTP_X_DEVICE_ID='device-alice-1',
            HTTP_X_DEVICE_NAME='Pixel 8',
            HTTP_X_PLATFORM='android',
            REMOTE_ADDR='103.145.10.45',
        )
        self.assertEqual(resp.status_code, 200, resp.data)

        device = UserDevice.objects.filter(user=self.user_a, device_id='device-alice-1').first()
        self.assertIsNotNone(device)
        self.assertEqual(device.platform, 'android')
        self.assertEqual(device.device_name, 'Pixel 8')
        self.assertTrue(device.last_ip_masked.endswith('***'))

        # Fetch list as user_a
        self.client.force_authenticate(user=self.user_a)
        list_resp = self.client.get(
            '/api/account/devices/',
            HTTP_X_DEVICE_ID='device-alice-1'
        )
        self.assertEqual(list_resp.status_code, 200)
        devices = list_resp.data.get('devices', [])
        self.assertEqual(len(devices), 1)
        self.assertTrue(devices[0]['is_current'])
        self.assertEqual(devices[0]['device_id'], 'device-alice-1')

    def test_user_cannot_revoke_other_user_device_idor(self):
        """User A attempting to revoke User B's device gets 403 Forbidden."""
        device_b = UserDevice.objects.create(
            user=self.user_b,
            device_id='device-bob-1',
            device_name='iPhone 15',
            platform='ios',
            last_ip_masked='103.145.10.***'
        )

        self.client.force_authenticate(user=self.user_a)
        resp = self.client.post(f'/api/account/devices/{device_b.id}/revoke/')
        self.assertEqual(resp.status_code, 403)
        device_b.refresh_from_db()
        self.assertFalse(device_b.is_revoked)

    def test_user_can_revoke_own_device(self):
        """User A can revoke their own device."""
        device_a = UserDevice.objects.create(
            user=self.user_a,
            device_id='device-alice-old',
            device_name='Samsung S20',
            platform='android'
        )

        self.client.force_authenticate(user=self.user_a)
        resp = self.client.post(f'/api/account/devices/{device_a.id}/revoke/')
        self.assertEqual(resp.status_code, 200)
        device_a.refresh_from_db()
        self.assertTrue(device_a.is_revoked)

    def test_revoked_device_login_blocked(self):
        """A revoked device cannot be used to obtain new tokens (HTTP 403)."""
        UserDevice.objects.create(
            user=self.user_a,
            device_id='device-compromised',
            device_name='Unknown Phone',
            platform='android',
            is_revoked=True
        )

        resp = self.client.post(
            '/api/token/',
            {
                'phone': '01711111111',
                'password': 'Password123!',
            },
            HTTP_X_DEVICE_ID='device-compromised',
            HTTP_X_PLATFORM='android'
        )
        self.assertEqual(resp.status_code, 403)
        self.assertIn('revoked', resp.data.get('detail', '').lower())

    def test_new_device_login_creates_security_notification(self):
        """Login from an unfamiliar device generates an in-app security alert."""
        resp = self.client.post(
            '/api/token/',
            {
                'phone': '01711111111',
                'password': 'Password123!',
            },
            HTTP_X_DEVICE_ID='new-device-unknown',
            HTTP_X_DEVICE_NAME='Windows Chrome',
            HTTP_X_PLATFORM='web'
        )
        self.assertEqual(resp.status_code, 200)

        notif = Notification.objects.filter(
            user=self.user_a,
            title__icontains='New Device Login'
        ).first()
        self.assertIsNotNone(notif)
        self.assertIn('Windows Chrome', notif.body)

    def test_logout_all_devices_with_include_current(self):
        """Logout-all revokes devices and blacklists tokens."""
        d1 = UserDevice.objects.create(user=self.user_a, device_id='dev-1')
        d2 = UserDevice.objects.create(user=self.user_a, device_id='dev-2')

        refresh = RefreshToken.for_user(self.user_a)

        self.client.force_authenticate(user=self.user_a)
        resp = self.client.post(
            '/api/account/devices/logout-all/?include_current=true',
            {'refresh': str(refresh)},
            HTTP_X_DEVICE_ID='dev-1'
        )
        self.assertEqual(resp.status_code, 200)

        d1.refresh_from_db()
        d2.refresh_from_db()
        self.assertTrue(d1.is_revoked)
        self.assertTrue(d2.is_revoked)

    def test_password_change_revokes_other_sessions(self):
        """Changing password revokes other devices and blacklists outstanding tokens."""
        d_current = UserDevice.objects.create(user=self.user_a, device_id='cur-device')
        d_other = UserDevice.objects.create(user=self.user_a, device_id='other-device')

        refresh_cur = RefreshToken.for_user(self.user_a)
        refresh_other = RefreshToken.for_user(self.user_a)

        self.client.force_authenticate(user=self.user_a)
        resp = self.client.post(
            '/api/auth/password-change/',
            {
                'old_password': 'Password123!',
                'new_password': 'NewStrongPassword2026!',
                'refresh': str(refresh_cur),
            },
            HTTP_X_DEVICE_ID='cur-device'
        )
        self.assertEqual(resp.status_code, 200, resp.data)

        d_current.refresh_from_db()
        d_other.refresh_from_db()
        self.assertFalse(d_current.is_revoked)
        self.assertTrue(d_other.is_revoked)

        # Check user password changed
        self.user_a.refresh_from_db()
        self.assertTrue(self.user_a.check_password('NewStrongPassword2026!'))

    def test_media_upload_safety_validation(self):
        """Media upload endpoint validates extension, mime type, and file integrity."""
        self.client.force_authenticate(user=self.user_a)

        # 1. Invalid extension
        fake_txt = SimpleUploadedFile("malicious.txt", b"print('hack')", content_type="text/plain")
        resp = self.client.post('/api/media/upload/', {'file': fake_txt}, format='multipart')
        self.assertEqual(resp.status_code, 400)

        # 2. Fake image (wrong content with image extension)
        fake_png = SimpleUploadedFile("fake.png", b"not-a-valid-image-stream", content_type="image/png")
        resp2 = self.client.post('/api/media/upload/', {'file': fake_png}, format='multipart')
        self.assertEqual(resp2.status_code, 400)

    def test_admin_endpoints_reject_non_staff(self):
        """Non-staff user cannot access admin audit logs or staff endpoints."""
        self.client.force_authenticate(user=self.user_a)

        resp1 = self.client.get('/api/admin/audit-logs/')
        self.assertEqual(resp1.status_code, 403)

        resp2 = self.client.get('/api/admin/staff/')
        self.assertEqual(resp2.status_code, 403)
