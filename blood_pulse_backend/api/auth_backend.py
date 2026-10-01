# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model
from django.db.models import Q


class MultiFieldModelBackend(ModelBackend):
    """
    BloodPulse universal authentication backend.
    Allows users to log in with:
    1. Exact or case-insensitive username (e.g. '01601239046' or 'nasim')
    2. Full name or first name (e.g. 'nasim' matches first_name or full name)
    3. Phone number in any standard format (+880..., 880..., 01..., etc.)
    4. Verified Email address
    5. Associated DonorProfile phone number
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        UserModel = get_user_model()
        if username is None:
            username = kwargs.get(UserModel.USERNAME_FIELD)
        if not username or not password:
            return None

        clean_user = username.strip()

        # Phone digits extraction and normalization
        phone_digits = ''.join(filter(str.isdigit, clean_user))
        phone_variants = set()
        if len(phone_digits) >= 10:
            core_10 = phone_digits[-10:]
            phone_variants.add(core_10)
            phone_variants.add('0' + core_10)
            phone_variants.add('880' + core_10)
            phone_variants.add('+880' + core_10)
            phone_variants.add(phone_digits)
            if not phone_digits.startswith('+'):
                phone_variants.add('+' + phone_digits)

        # Query filter building
        q = (
            Q(username__iexact=clean_user) |
            Q(email__iexact=clean_user) |
            Q(first_name__iexact=clean_user) |
            Q(last_name__iexact=clean_user)
        )

        for pv in phone_variants:
            q |= (
                Q(username=pv) |
                Q(username__endswith=pv) |
                Q(donorprofile__phone_number=pv) |
                Q(donorprofile__phone_number__endswith=pv)
            )

        if ' ' in clean_user:
            parts = clean_user.split(None, 1)
            q |= Q(first_name__iexact=parts[0], last_name__iexact=parts[1])

        # Also support sub-string name match if exact didn't yield
        candidates = UserModel.objects.filter(q).distinct()

        for user in candidates:
            if user.check_password(password) and self.user_can_authenticate(user):
                return user

        # Fallback: check if clean_user matches first_name case-insensitively with partial
        fallback_candidates = UserModel.objects.filter(
            Q(first_name__icontains=clean_user) | Q(username__icontains=clean_user)
        ).distinct()
        for user in fallback_candidates:
            if user.check_password(password) and self.user_can_authenticate(user):
                return user

        return None
