---
name: django-security
description: Django security best practices, authentication, authorization, CSRF protection, SQL injection prevention, XSS prevention, and secure deployment configurations. Based on ECC standards. Use when reviewing Django authentication, authorization, input handling, issue #33 security remediation, or deployment settings.
metadata:
  origin: ECC
  version: "1.0.0"
---

# Django Security Best Practices (BloodPulse Hardening)

Production security guidelines and safeguards for the BloodPulse Django REST Framework backend to resolve issue #33, safeguard donor privacy, and prevent unauthorized data tampering.

## When to Activate

- Remediation and review of issue #33 (Backend Security & Hardening).
- Implementing authentication, JWT, OTP, and user permissions.
- Hardening production settings (`DEBUG = False`, HTTPS, secure cookies).
- Guarding donor sensitive health/contact data.
- Defending against CSRF, XSS, and SQL injection vulnerabilities.

---

## 1. Production Settings Configuration (Issue #33 Hardening)

```python
# blood_pulse_backend/settings.py
import os
from pathlib import Path
from django.core.exceptions import ImproperlyConfigured

# 1. CRITICAL: Never deploy with DEBUG = True
DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')

# 2. Secret Key must come from environment variable
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')
if not SECRET_KEY and not DEBUG:
    raise ImproperlyConfigured('DJANGO_SECRET_KEY environment variable is required for production')

# 3. HTTPS and Cookie Protection
SECURE_SSL_REDIRECT = not DEBUG
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SAMESITE = 'Lax'

# 4. Strict Transport Security (HSTS)
if not DEBUG:
    SECURE_HSTS_SECONDS = 31536000  # 1 year
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

# 5. Browser Defenses
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'
```

---

## 2. API Security & Rate Limiting (DRF Throttling)

Protect against brute force and SMS/OTP abuse in blood request broadcasting:

```python
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',
        'user': '1000/day',
        'otp_request': '5/hour',
        'blood_request_create': '10/hour',
    }
}
```

### Custom Sensitive Action Throttle

```python
from rest_framework.throttling import UserRateThrottle

class OTPRateThrottle(UserRateThrottle):
    scope = 'otp_request'

class BloodRequestCreateThrottle(UserRateThrottle):
    scope = 'blood_request_create'
```

---

## 3. Donor Data Protection & Object-Level Permissions

Prevent donors or external users from modifying another user's blood requests or profile:

```python
# api/permissions.py
from rest_framework import permissions

class IsOwnerOrAdminOnly(permissions.BasePermission):
    """Allow full write access only to the resource owner or staff."""
    
    def has_object_permission(self, request, view, obj):
        # Read-only permissions for safe methods (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Write permissions require matching the owner
        owner = getattr(obj, 'user', getattr(obj, 'created_by', None))
        return owner == request.user or request.user.is_staff
```

---

## 4. SQL Injection Prevention & Safe ORM

- **Rule 1**: Always use the Django ORM query methods (`filter()`, `exclude()`, `annotate()`).
- **Rule 2**: If using `extra()` or `raw()`, NEVER format or concatenate user strings directly.

```python
# DANGEROUS (SQL Injection):
# Donor.objects.raw(f"SELECT * FROM donors WHERE district = '{user_input}'")

# SAFE:
Donor.objects.filter(district__iexact=user_input)

# SAFE parameterized raw query (if absolutely necessary):
Donor.objects.raw("SELECT * FROM donors WHERE district = %s", [user_input])
```

---

## 5. Password Validation & Security

```python
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 10}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
```

---

## 6. Security Audit Checklist

- [ ] Is `DEBUG = False` enforced in staging and production?
- [ ] Is `SECRET_KEY` pulled from environment and excluded from git?
- [ ] Are all API endpoints throttled against brute-force attacks?
- [ ] Are phone numbers and donor sensitive data masked for unauthorized viewers?
- [ ] Has `python manage.py check --deploy` executed with 0 errors?
