# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework import exceptions, serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.views import TokenObtainPairView
from api.phone_utils import normalize_phone_number, is_valid_phone


class BloodPulseTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    BloodPulse universal login serializer.
    Accepts:
      - Email or phone or username in 'username', 'identifier', 'phone', or 'email'.
      - Password.
    Returns:
      - access, refresh tokens
      - is_profile_complete: server-provided flag
    On failure:
      - Generic 'Invalid credentials' HTTP 401 error, never revealing user enumeration.
    """
    default_error_messages = {
        'no_active_account': 'Invalid credentials',
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields[self.username_field].required = False
        self.fields['identifier'] = serializers.CharField(required=False, write_only=True)
        self.fields['phone'] = serializers.CharField(required=False, write_only=True)
        self.fields['email'] = serializers.CharField(required=False, write_only=True)

    def validate(self, attrs):
        login_id = (
            attrs.get('username') or
            attrs.get('identifier') or
            attrs.get('phone') or
            attrs.get('email')
        )
        if not login_id:
            raise exceptions.AuthenticationFailed(
                self.error_messages['no_active_account'],
                'no_active_account',
            )

        clean_id = str(login_id).strip()
        from django.contrib.auth.models import User
        from api.models import DonorProfile
        from api.phone_utils import normalize_phone_number, get_phone_variants, is_valid_phone

        matched_user = User.objects.filter(username__iexact=clean_id).first()
        if not matched_user and '@' in clean_id:
            matched_user = User.objects.filter(email__iexact=clean_id).first()

        if not matched_user and is_valid_phone(clean_id):
            try:
                canonical = normalize_phone_number(clean_id)
                variants = get_phone_variants(canonical)
                matched_user = User.objects.filter(username__in=variants).first()
                if not matched_user:
                    profile = DonorProfile.objects.filter(phone_number__in=variants).select_related('user').first()
                    if profile and profile.user:
                        matched_user = profile.user
            except Exception:
                pass

        attrs['username'] = matched_user.username if matched_user else clean_id

        try:
            data = super().validate(attrs)
        except exceptions.AuthenticationFailed:
            raise exceptions.AuthenticationFailed(
                self.error_messages['no_active_account'],
                'no_active_account',
            )

        # Attach server-provided is_profile_complete flag
        is_complete = False
        try:
            profile = getattr(self.user, 'donorprofile', None)
            if profile:
                is_comp, _ = profile.check_is_complete()
                is_complete = is_comp or profile.is_profile_complete
        except Exception:
            pass

        data['is_profile_complete'] = is_complete

        # Device Tracking & Session Management (Item 35)
        request = self.context.get('request')
        if request and hasattr(self, 'user') and self.user.is_authenticated:
            device_id = (
                request.data.get('device_id') or
                request.headers.get('X-Device-ID') or
                request.META.get('HTTP_X_DEVICE_ID')
            )
            device_name = (
                request.data.get('device_name') or
                request.headers.get('X-Device-Name') or
                request.META.get('HTTP_X_DEVICE_NAME', '')
            )
            platform = (
                request.data.get('platform') or
                request.headers.get('X-Platform') or
                'android'
            )
            raw_ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip()
            client_ip = ''
            if raw_ip:
                if '.' in raw_ip:
                    parts = raw_ip.split('.')
                    client_ip = '.'.join(parts[:3]) + '.***'
                elif ':' in raw_ip:
                    parts = raw_ip.split(':')
                    client_ip = ':'.join(parts[:3]) + ':****'
                else:
                    client_ip = raw_ip

            if device_id:
                from api.models import UserDevice, Notification
                from django.utils import timezone
                device = UserDevice.objects.filter(user=self.user, device_id=device_id).first()
                if device and device.is_revoked:
                    raise exceptions.PermissionDenied(
                        'This device session has been revoked. Please contact support or login from an authorized device.'
                    )

                if not device:
                    device = UserDevice.objects.create(
                        user=self.user,
                        device_id=device_id,
                        device_name=device_name or 'Mobile Device',
                        platform=platform,
                        last_ip_masked=client_ip,
                        is_revoked=False,
                        is_new=True,
                    )
                    # Create in-app notification for new device login
                    Notification.objects.create(
                        user=self.user,
                        title="New Device Login",
                        body=f"A new device ({device.device_name}) logged in to your account from {client_ip or 'unknown network'}.",
                        type="SECURITY",
                        is_read=False,
                        created_at=timezone.now(),
                    )
                else:
                    device.last_seen = timezone.now()
                    if client_ip:
                        device.last_ip_masked = client_ip
                    if device_name:
                        device.device_name = device_name
                    device.is_new = False
                    device.save(update_fields=['last_seen', 'last_ip_masked', 'device_name', 'is_new'])

                data['device_id'] = device_id

        return data


from api.throttles import LoginRateThrottle

class BloodPulseTokenObtainPairView(TokenObtainPairView):
    """
    Universal JWT login endpoint returning JSON only with rate limiting.
    """
    serializer_class = BloodPulseTokenObtainPairSerializer
    throttle_classes = [LoginRateThrottle]

