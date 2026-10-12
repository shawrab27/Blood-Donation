# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import io
from PIL import Image
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.core.management import call_command, CommandError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient

from api.models import (
    DonorProfile, SocialPost, District, Division, MediaUploadRecord, UserLocationState
)
from api.data.district_centroids import find_nearest_district

class Step10DFeedTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Divisions & Districts
        self.div_dhaka = Division.objects.create(name='Dhaka')
        self.dist_dhaka = District.objects.create(name='Dhaka', division=self.div_dhaka)

        self.div_rangpur = Division.objects.create(name='Rangpur')
        self.dist_rangpur = District.objects.create(name='Rangpur', division=self.div_rangpur)

        self.div_ctg = Division.objects.create(name='Chattogram')
        self.dist_ctg = District.objects.create(name='Chattogram', division=self.div_ctg)

        # Users
        self.user_dhaka = User.objects.create_user(username='dhaka_user', password='pass', first_name='DhakaUser')
        self.profile_dhaka = DonorProfile.objects.create(
            user=self.user_dhaka, phone_number='+8801700111111', district='Dhaka', blood_group='O+'
        )

        self.user_rangpur = User.objects.create_user(username='rangpur_user', password='pass', first_name='RangpurUser')
        self.profile_rangpur = DonorProfile.objects.create(
            user=self.user_rangpur, phone_number='+8801700222222', district='Rangpur', blood_group='A+'
        )

    def test_nearest_district_centroid_mapping(self):
        # Dhaka coordinates ~ (23.8103, 90.4125)
        near_dhaka = find_nearest_district(23.8120, 90.4100)
        self.assertEqual(near_dhaka, 'Dhaka')

        # Rangpur coordinates ~ (25.7439, 89.2752)
        near_rangpur = find_nearest_district(25.7500, 89.2800)
        self.assertEqual(near_rangpur, 'Rangpur')

    def test_media_upload_with_exif_stripping_and_storage(self):
        self.client.force_authenticate(user=self.user_dhaka)

        # Create dummy image in memory
        img = Image.new('RGB', (100, 100), color='red')
        img_io = io.BytesIO()
        img.save(img_io, format='JPEG')
        img_bytes = img_io.getvalue()

        upload_file = SimpleUploadedFile("test_photo.jpg", img_bytes, content_type="image/jpeg")

        res = self.client.post('/api/media/upload/', {'file': upload_file}, format='multipart')
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertIn('url', data)
        self.assertIn('public_id', data)
        self.assertTrue(MediaUploadRecord.objects.filter(public_id=data['public_id']).exists())

    def test_media_upload_max_size_rejection(self):
        self.client.force_authenticate(user=self.user_dhaka)
        # Create a file larger than 5MB
        big_content = b'0' * (5 * 1024 * 1024 + 1024)
        big_file = SimpleUploadedFile("huge.jpg", big_content, content_type="image/jpeg")
        res = self.client.post('/api/media/upload/', {'file': big_file}, format='multipart')
        self.assertEqual(res.status_code, 400)
        self.assertIn('exceeds', res.json().get('error', '').lower())

    def test_user_location_sync_and_feed_district_awareness(self):
        self.client.force_authenticate(user=self.user_dhaka)

        # 1. Initially user is Dhaka
        res_loc = self.client.post('/api/users/location/', {'lat': 23.8103, 'lng': 90.4125})
        self.assertEqual(res_loc.status_code, 200)
        self.assertEqual(res_loc.json()['district_name'], 'Dhaka')

        # 2. Seed posts in Dhaka and Rangpur
        p_dhaka = SocialPost.objects.create(
            author=self.profile_dhaka,
            text_content="Dhaka post 1",
            district=self.dist_dhaka,
            division=self.div_dhaka
        )
        p_rangpur = SocialPost.objects.create(
            author=self.profile_rangpur,
            text_content="Rangpur post 1",
            district=self.dist_rangpur,
            division=self.div_rangpur
        )

        # Query feed with scope=near
        feed_dhaka = self.client.get('/api/feed/?scope=near')
        self.assertEqual(feed_dhaka.status_code, 200)
        results = feed_dhaka.json()['results']
        self.assertTrue(any(p['id'] == p_dhaka.id for p in results))

        # 3. User travels to Rangpur -> send Rangpur coordinates
        res_travel = self.client.post('/api/users/location/', {'lat': 25.7439, 'lng': 89.2752})
        self.assertEqual(res_travel.status_code, 200)
        self.assertEqual(res_travel.json()['district_name'], 'Rangpur')
        self.assertTrue(res_travel.json()['changed'])

        # Now feed with scope=near prioritizes Rangpur
        feed_rangpur = self.client.get('/api/feed/?scope=near')
        self.assertEqual(feed_rangpur.status_code, 200)
        self.assertEqual(feed_rangpur.json()['district'], 'Rangpur')

    def test_keyset_pagination_consistency(self):
        # Create 20 posts with monotonic timestamps
        posts = []
        base_time = timezone.now() - timedelta(hours=5)
        for i in range(20):
            p = SocialPost.objects.create(
                author=self.profile_dhaka,
                text_content=f"Post #{i}",
                district=self.dist_dhaka,
                division=self.div_dhaka
            )
            SocialPost.objects.filter(id=p.id).update(created_at=base_time + timedelta(minutes=i))
            posts.append(p)

        # Fetch page 1 (size 15)
        res1 = self.client.get('/api/feed/?scope=national')
        self.assertEqual(res1.status_code, 200)
        data1 = res1.json()
        self.assertEqual(len(data1['results']), 15)
        self.assertTrue(data1['has_more'])
        self.assertIsNotNone(data1['next_cursor'])

        # Fetch page 2 using cursor
        cursor = data1['next_cursor']
        res2 = self.client.get(f'/api/feed/?scope=national&cursor={cursor}')
        self.assertEqual(res2.status_code, 200)
        data2 = res2.json()
        self.assertEqual(len(data2['results']), 5)
        self.assertFalse(data2['has_more'])

        # Ensure no duplicates between page 1 and page 2
        p1_ids = {p['id'] for p in data1['results']}
        p2_ids = {p['id'] for p in data2['results']}
        self.assertEqual(len(p1_ids.intersection(p2_ids)), 0)

    def test_soft_deleted_posts_hidden(self):
        p = SocialPost.objects.create(
            author=self.profile_dhaka,
            text_content="To be deleted",
            district=self.dist_dhaka,
            division=self.div_dhaka
        )
        self.client.force_authenticate(user=self.user_dhaka)

        # Visible in feed
        res = self.client.get('/api/feed/?scope=national')
        self.assertTrue(any(item['id'] == p.id for item in res.json()['results']))

        # Soft delete via endpoint
        del_res = self.client.delete(f'/api/feed/{p.id}/')
        self.assertEqual(del_res.status_code, 200)

        p.refresh_from_db()
        self.assertIsNotNone(p.deleted_at)

        # Hidden in feed
        res2 = self.client.get('/api/feed/?scope=national')
        self.assertFalse(any(item['id'] == p.id for item in res2.json()['results']))

    def test_post_creation_rate_limit(self):
        from django.core.cache import cache
        cache.clear()
        self.client.force_authenticate(user=self.user_dhaka)
        for i in range(10):
            res = self.client.post('/api/feed/', {
                'text_content': f'Valid post #{i}',
                'kind': 'general'
            })
            self.assertEqual(res.status_code, 201)

        # 11th post within an hour exceeds throttle
        res_blocked = self.client.post('/api/feed/', {
            'text_content': '11th post spam',
            'kind': 'general'
        })
        self.assertEqual(res_blocked.status_code, 429)

    def test_seed_feed_demo_refuses_without_confirmation(self):
        with self.assertRaises(CommandError):
            call_command('seed_feed_demo')

    def test_seed_feed_demo_creates_posts(self):
        call_command('seed_feed_demo', '--districts', 'Dhaka', '--posts-per-district', '5', '--i-understand-this-creates-fake-posts')
        count = SocialPost.objects.filter(district__name='Dhaka').count()
        self.assertGreaterEqual(count, 5)
