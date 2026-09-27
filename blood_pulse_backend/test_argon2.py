# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()
from django.contrib.auth.models import User

user, _ = User.objects.get_or_create(username='argon2_test')
user.set_password('supersecret')
user.save()

reloaded = User.objects.get(username='argon2_test')
print('Password Hash:', reloaded.password)
