from datetime import timedelta
from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from api.models import DonorProfile, GuideApplication, AreaGuide, District, Division


class GuideApplicationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='donor1',
            email='donor1@example.com',
            password='password123',
            first_name='Rahim',
            last_name='Uddin'
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='01712345678',
            district='Dhaka',
            blood_group='A+'
        )
        self.division = Division.objects.create(name='Dhaka')
        self.district = District.objects.create(division=self.division, name='Dhaka')
        self.client.force_authenticate(user=self.user)

    def test_gating_incomplete_account(self):
        self.profile.phone_number = ''
        self.profile.save()

        # GET check
        res = self.client.get('/api/v1/communities/guide-application/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['status'], 'gated')
        self.assertFalse(res.data['can_apply'])

        # POST check
        post_res = self.client.post('/api/v1/communities/guide-application/', {
            'intro': 'I want to be a guide in Dhanmondi.',
            'allow_calls': True,
        })
        self.assertEqual(post_res.status_code, 403)

    def test_valid_submission_creates_pending(self):
        res = self.client.post('/api/v1/communities/guide-application/', {
            'intro': 'I am active in Dhanmondi blood donor community.',
            'allow_calls': True,
            'district': self.district.id,
            'area_name': 'Dhanmondi, Dhaka',
        })
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data['status'], 'pending')
        self.assertEqual(res.data['button_state'], 'Pending review')

        # Check model instance
        app = GuideApplication.objects.filter(user=self.user).first()
        self.assertIsNotNone(app)
        self.assertEqual(app.status, GuideApplication.STATUS_PENDING)
        self.assertTrue(app.allow_calls)

        # Subsequent GET shows pending
        get_res = self.client.get('/api/v1/communities/guide-application/')
        self.assertEqual(get_res.status_code, 200)
        self.assertEqual(get_res.data['button_state'], 'Pending review')
        self.assertFalse(get_res.data['can_apply'])

    def test_rejection_cooldown_14_days(self):
        # Create rejected application reviewed 5 days ago
        app = GuideApplication.objects.create(
            user=self.user,
            intro='Previous intro',
            status=GuideApplication.STATUS_REJECTED,
            reviewed_at=timezone.now() - timedelta(days=5),
            rejection_reason='Verification document unclear'
        )

        # GET should show rejected with reapply date
        res = self.client.get('/api/v1/communities/guide-application/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['status'], 'rejected')
        self.assertIn('Rejected (Apply again on', res.data['button_state'])
        self.assertFalse(res.data['can_apply'])

        # POST should be rejected
        post_res = self.client.post('/api/v1/communities/guide-application/', {
            'intro': 'Trying to reapply early',
            'allow_calls': False,
        })
        self.assertEqual(post_res.status_code, 400)
        self.assertIn('14 days', post_res.data['error'])

    def test_admin_approval_action(self):
        from api.admin import GuideApplicationAdmin
        from django.contrib.admin.sites import AdminSite

        app = GuideApplication.objects.create(
            user=self.user,
            district=self.district,
            area_name='Dhanmondi',
            intro='I want to serve as guide',
            allow_calls=True,
            status=GuideApplication.STATUS_PENDING
        )

        admin = GuideApplicationAdmin(GuideApplication, AdminSite())
        class MockRequest:
            user = User.objects.create_superuser('admin', 'admin@example.com', 'adminpass')
        mock_req = MockRequest()
        mock_req._messages = []

        admin.message_user = lambda req, msg: None
        admin.approve_applications(mock_req, GuideApplication.objects.filter(id=app.id))

        app.refresh_from_db()
        self.assertEqual(app.status, GuideApplication.STATUS_APPROVED)
        self.profile.refresh_from_db()
        self.assertTrue(self.profile.is_guide)

        # AreaGuide created
        guide = AreaGuide.objects.filter(district=self.district, name='Rahim Uddin').first()
        self.assertIsNotNone(guide)
        self.assertTrue(guide.is_active)
