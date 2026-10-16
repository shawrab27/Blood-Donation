# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db.models import Q
from api.models import DonorProfile
from api.phone_utils import get_phone_variants, mask_phone

User = get_user_model()


class Command(BaseCommand):
    help = (
        "Read-only diagnostic tool for phone-based accounts. "
        "Prints matched account count, model/field details, and masked values (last 3 digits). "
        "Never exposes full phone numbers, names, or emails."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            'phone',
            type=str,
            help="Phone number to diagnose (e.g. 01601239009, +8801601239023)",
        )

    def handle(self, *args, **options):
        raw_phone = options['phone'].strip()
        variants = get_phone_variants(raw_phone)
        input_masked = mask_phone(raw_phone)

        self.stdout.write(self.style.NOTICE(f"=== Diagnosing Phone Accounts for: {input_masked} ==="))

        # Find matching User rows (by username or email)
        user_filter = Q()
        for v in variants:
            user_filter |= Q(username=v) | Q(username__endswith=v) | Q(email__icontains=v)
        user_matches = list(User.objects.filter(user_filter).distinct())

        # Find matching DonorProfile rows (by phone_number)
        profile_filter = Q()
        for v in variants:
            profile_filter |= Q(phone_number=v) | Q(phone_number__endswith=v)
        profile_matches = list(DonorProfile.objects.filter(profile_filter).select_related('user').distinct())

        # Consolidate all unique User accounts
        account_map = {}
        for u in user_matches:
            account_map[u.id] = {
                'user': u,
                'matched_on': ['User.username'],
                'profile': getattr(u, 'donorprofile', None),
            }

        for p in profile_matches:
            if p.user_id in account_map:
                if 'DonorProfile.phone_number' not in account_map[p.user_id]['matched_on']:
                    account_map[p.user_id]['matched_on'].append('DonorProfile.phone_number')
                account_map[p.user_id]['profile'] = p
            else:
                account_map[p.user_id] = {
                    'user': p.user,
                    'matched_on': ['DonorProfile.phone_number'],
                    'profile': p,
                }

        total_matched = len(account_map)
        self.stdout.write(f"Total matching accounts found: {total_matched}")

        if total_matched == 0:
            self.stdout.write(self.style.WARNING("No active or inactive accounts matched this phone number."))
            return

        for user_id, info in account_map.items():
            user = info['user']
            profile = info['profile']
            matched_fields = ', '.join(info['matched_on'])

            user_username_masked = mask_phone(user.username)
            is_active_str = "ACTIVE" if user.is_active else "INACTIVE"

            self.stdout.write("--------------------------------------------------")
            self.stdout.write(f"Account ID: {user_id} [Status: {is_active_str}]")
            self.stdout.write(f"  Matched via: {matched_fields}")
            self.stdout.write(f"  Model User: field 'username' masked value -> {user_username_masked}")

            if profile:
                profile_phone_masked = mask_phone(profile.phone_number)
                self.stdout.write(f"  Model DonorProfile (ID {profile.id}): field 'phone_number' masked value -> {profile_phone_masked}")
                self.stdout.write(f"  Profile Complete: {profile.is_profile_complete}")

                # Check for discrepancy between User.username and DonorProfile.phone_number
                user_digits = ''.join(c for c in user.username if c.isdigit())
                profile_digits = ''.join(c for c in profile.phone_number if c.isdigit())
                if user_digits and profile_digits and user_digits[-10:] != profile_digits[-10:]:
                    self.stdout.write(self.style.ERROR(
                        f"  [DISCREPANCY DETECTED] Login username ends in '{user_username_masked}' "
                        f"but DonorProfile phone ends in '{profile_phone_masked}'! "
                        f"These represent DIFFERENT phone numbers on the same account."
                    ))
                elif user_digits and profile_digits:
                    self.stdout.write(self.style.SUCCESS("  [CONSISTENT] User.username and DonorProfile.phone_number match."))
            else:
                self.stdout.write("  Model DonorProfile: None (No linked profile)")

        self.stdout.write("--------------------------------------------------")
