# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth.models import User
from api.models import DonorProfile, SocialPost
from rest_framework.test import APIClient

User.objects.filter(username="feed_user").delete()
user = User.objects.create_user(username="feed_user", password="password")
donor = DonorProfile.objects.create(user=user, phone_number="0101010101")
post = SocialPost.objects.create(author=donor, text_content="This is a real feed post from the E2E test!")

client = APIClient()
# List should be accessible to AllowAny as per get_permissions()
response = client.get('/api/posts/')
print(f"Status Code: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    if 'results' in data: # Pagination
        posts = data['results']
    else:
        posts = data
    print(f"Number of posts: {len(posts)}")
    if len(posts) > 0:
        print(f"First post text: {posts[0].get('text_content')}")
        print(f"First post author: {posts[0].get('author_name')}")
