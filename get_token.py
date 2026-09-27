import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
import json

User = get_user_model()
user = User.objects.first()
if not user:
    user = User.objects.create(username="testuser", phone_number="01711111111", is_profile_complete=True)

refresh = RefreshToken.for_user(user)
access_token = str(refresh.access_token)

print(json.dumps({
    "access": access_token,
    "refresh": str(refresh)
}))
