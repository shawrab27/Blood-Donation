import sys
with open('blood_pulse_backend/api/tests/test_tick.py', 'r') as f:
    text = f.read()

new_test = '''
    def test_auto_deferral_on_maintenance_tick(self):
        from django.contrib.auth.models import User
        from api.models import DonorProfile
        from django.utils import timezone
        from datetime import timedelta
        
        user1 = User.objects.create_user(username='d1', password='pw')
        user2 = User.objects.create_user(username='d2', password='pw')
        user3 = User.objects.create_user(username='d3', password='pw')
        
        now = timezone.now().date()
        
        # d1: donated 10 days ago (should be deferred)
        DonorProfile.objects.create(user=user1, phone_number='1', is_available=True, last_donation_date=now - timedelta(days=10))
        
        # d2: donated 91 days ago, currently deferred (should be re-enabled)
        DonorProfile.objects.create(user=user2, phone_number='2', is_available=False, last_donation_date=now - timedelta(days=91))
        
        # d3: donated 100 days ago, currently deferred but suspended (should remain deferred)
        DonorProfile.objects.create(user=user3, phone_number='3', is_available=False, is_suspended=True, last_donation_date=now - timedelta(days=100))
        
        client = APIClient()
        os.environ['EMERGENCY_TICK_TOKEN'] = 'super_secret_tick_token'
        
        resp = client.get('/api/emergency/maintenance-tick/', HTTP_AUTHORIZATION='Bearer super_secret_tick_token')
        self.assertEqual(resp.status_code, 200)
        
        data = resp.json()
        self.assertEqual(data.get('auto_deferred_count'), 1)
        self.assertEqual(data.get('auto_reenabled_count'), 1)
        
        d1 = DonorProfile.objects.get(user=user1)
        self.assertFalse(d1.is_available)
        
        d2 = DonorProfile.objects.get(user=user2)
        self.assertTrue(d2.is_available)
        
        d3 = DonorProfile.objects.get(user=user3)
        self.assertFalse(d3.is_available)
'''

if 'test_auto_deferral_on_maintenance_tick' not in text:
    with open('blood_pulse_backend/api/tests/test_tick.py', 'a') as f:
        f.write(new_test)
    print('Added test_auto_deferral_on_maintenance_tick')
