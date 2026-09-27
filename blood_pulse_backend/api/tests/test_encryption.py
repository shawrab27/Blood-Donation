# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.


from django.test import TestCase
from django.contrib.auth.models import User
from api.models import DonorProfile
from django.db import connection

class NIDEncryptionTests(TestCase):
    def test_nid_encryption_and_decryption(self):
        user = User.objects.create(username='test_encrypt')
        fake_nid = '1234567890'
        
        # Save it
        profile = DonorProfile.objects.create(
            user=user,
            blood_group='A+',
            district='Dhaka',
            phone_number='01700000099',
            nid_hash=fake_nid
        )
        
        # Check raw DB to ensure it's not plaintext
        with connection.cursor() as cursor:
            cursor.execute('SELECT nid_hash FROM api_donorprofile WHERE id=%s', [profile.id])
            raw_val = cursor.fetchone()[0]
            
            # The raw DB value should NOT equal the plaintext NID
            if isinstance(raw_val, memoryview):
                raw_str = raw_val.tobytes().decode('utf-8', errors='ignore')
            elif isinstance(raw_val, bytes):
                raw_str = raw_val.decode('utf-8', errors='ignore')
            else:
                raw_str = str(raw_val)
                
            self.assertNotEqual(raw_str, fake_nid)
            self.assertTrue('gAAAAA' in raw_str or raw_str.startswith('gAAAAA'))
            
        # Reload through ORM to test decryption
        reloaded = DonorProfile.objects.get(id=profile.id)
        self.assertEqual(reloaded.nid_hash, fake_nid)

