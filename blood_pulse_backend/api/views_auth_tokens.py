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
        attrs['username'] = clean_id

        try:
            data = super().validate(attrs)
        except exceptions.AuthenticationFailed:
            # Guarantee generic 'Invalid credentials' message for any auth failure
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
        return data


class BloodPulseTokenObtainPairView(TokenObtainPairView):
    """
    Universal JWT login endpoint returning JSON only.
    """
    serializer_class = BloodPulseTokenObtainPairSerializer
