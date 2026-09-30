# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from api.models import DonorProfile, SocialPost

class FeedIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='+8801700000002', password='password', first_name="Test")
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='+8801700000002'
        )
        self.client.force_authenticate(user=self.user)
        self.post = SocialPost.objects.create(
            author=self.profile,
            text_content="Hello world"
        )

    def test_post_empty_content(self):
        res = self.client.post('/api/posts/', {'text_content': ''})
        self.assertEqual(res.status_code, 400, "Expected 400 for empty post content")

    def test_like_idempotent(self):
        # Like the post twice
        res1 = self.client.post(f'/api/posts/{self.post.id}/like/')
        self.assertEqual(res1.status_code, 200)
        res2 = self.client.post(f'/api/posts/{self.post.id}/like/')
        self.assertEqual(res2.status_code, 200)
        
        self.post.refresh_from_db()
        self.assertEqual(self.post.likes_count, 1, "Likes count should be 1 (idempotent)")

    def test_comment_nonexistent_post(self):
        res = self.client.post('/api/posts/99999/comment/', {'text': 'Nice!'})
        self.assertEqual(res.status_code, 404, "Expected 404 for commenting on nonexistent post")

    def test_repost_behavior(self):
        res = self.client.post(f'/api/posts/{self.post.id}/repost/')
        self.assertEqual(res.status_code, 201, "Expected 201 for repost")
        
        # Check it links to original_post_id
        data = res.json()
        self.assertIn('original_post', data)
        self.assertEqual(data['original_post'], self.post.id)
