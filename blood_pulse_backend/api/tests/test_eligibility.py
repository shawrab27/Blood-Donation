from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from api.models import DonorProfile, DeferralRecord
from api.services.eligibility import evaluate_donor_eligibility


class EligibilityServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='testdonor', password='password123')
        self.donor = DonorProfile.objects.create(
            user=self.user,
            blood_group='O+',
            district='Dhaka',
            phone_number='+8801711223344',
            is_available=True,
            is_searchable=True,
        )

    def test_donor_with_no_previous_donation_is_eligible(self):
        res = evaluate_donor_eligibility(self.donor)
        self.assertTrue(res['is_eligible'])
        self.assertEqual(res['days_remaining'], 0)

    def test_donor_within_120_days_is_ineligible(self):
        self.donor.last_donation_date = timezone.now().date() - timedelta(days=45)
        self.donor.save()
        res = evaluate_donor_eligibility(self.donor)
        self.assertFalse(res['is_eligible'])
        self.assertEqual(res['days_remaining'], 75)

    def test_donor_after_120_days_is_eligible(self):
        self.donor.last_donation_date = timezone.now().date() - timedelta(days=125)
        self.donor.save()
        res = evaluate_donor_eligibility(self.donor)
        self.assertTrue(res['is_eligible'])
        self.assertEqual(res['days_remaining'], 0)

    def test_active_deferral_record_blocks_eligibility(self):
        DeferralRecord.objects.create(
            donor=self.donor,
            reason='Low Hemoglobin',
            reason_code='MEDICAL',
            expires_at=timezone.now() + timedelta(days=90),
            is_active=True,
        )
        res = evaluate_donor_eligibility(self.donor)
        self.assertFalse(res['is_eligible'])
        self.assertIn('Medical deferral', res['reason'])

    def test_alert_pause_blocks_eligibility(self):
        self.donor.alert_pause_until = timezone.now() + timedelta(days=7)
        self.donor.save()
        res = evaluate_donor_eligibility(self.donor)
        self.assertFalse(res['is_eligible'])
        self.assertIn('alerts are currently paused', res['reason'])
