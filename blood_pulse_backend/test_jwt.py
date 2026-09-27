# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
import jwt

user, _ = User.objects.get_or_create(username='jwt_test')
refresh = RefreshToken.for_user(user)
access_token = str(refresh.access_token)

payload = jwt.decode(access_token, options={'verify_signature': False})
print('IAT:', payload['iat'], 'EXP:', payload['exp'])
print('Difference:', payload['exp'] - payload['iat'], 'seconds')
