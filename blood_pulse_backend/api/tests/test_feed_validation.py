# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from api.models import DonorProfile, District, Division, SocialPost

User = get_user_model()

class FeedPostValidationTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.division = Division.objects.create(name='Dhaka')
        self.district = District.objects.create(name='Dhaka', division=self.division)

        self.user = User.objects.create_user(
            username='donor_poster',
            first_name='Post',
            last_name='Author',
            password='password123',
        )
        self.profile = DonorProfile.objects.create(
            user=self.user,
            phone_number='01733333333',
            blood_group='B+',
            district='Dhaka',
            is_profile_complete=True,
        )
        self.client.force_authenticate(user=self.user)

    def test_post_text_only_succeeds(self):
        """A post with text only (no media) must succeed with 201 Created."""
        payload = {
            'text_content': 'Just donated blood for the 5th time today!',
            'media': [],
            'kind': 'general',
            'location': 'Dhaka',
        }
        response = self.client.post('/api/feed/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['text_content'], 'Just donated blood for the 5th time today!')
        self.assertEqual(SocialPost.objects.filter(author=self.profile).count(), 1)

    def test_post_photo_only_succeeds(self):
        """A post with a photo only (caption empty) must succeed with 201 Created."""
        payload = {
            'text_content': '',
            'media': [{'url': 'https://res.cloudinary.com/bloodpulse/image/upload/sample.jpg'}],
            'kind': 'general',
            'location': 'Dhaka',
        }
        response = self.client.post('/api/feed/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(response.data['media']), 1)
        self.assertEqual(SocialPost.objects.filter(author=self.profile).count(), 1)

    def test_post_empty_rejected_with_human_message(self):
        """A post with neither text nor media must be rejected with 400 and a human sentence."""
        payload = {
            'text_content': '',
            'media': [],
            'kind': 'general',
        }
        response = self.client.post('/api/feed/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        
        # Check that error is a clean human sentence
        res_data = response.json()
        error_text = str(res_data)
        self.assertIn("Post must contain text or at least one image.", error_text)
        # Ensure no raw JSON or python exception traces in response
        self.assertNotIn("Traceback", error_text)
        self.assertNotIn("ApiException", error_text)
