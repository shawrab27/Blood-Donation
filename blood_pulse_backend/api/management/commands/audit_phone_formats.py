# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from collections import defaultdict
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from api.models import DonorProfile
from api.phone_utils import normalize_bd_phone, mask_phone, BD_MOBILE_REGEX

User = get_user_model()


class Command(BaseCommand):
    help = (
        "Read-only audit of phone number formats across DonorProfile and User models. "
        "Prints format distribution (01..., 8801..., +8801..., other), potential duplicates "
        "after canonical normalization (masked values, IDs only), and phone-like usernames. "
        "Strictly read-only; never modifies database rows."
    )

    def handle(self, *args, **options):
        self.stdout.write(self.style.MIGRATE_HEADING("=== Phone Format & Normalization Audit (Read-Only) ==="))

        # 1. Format Breakdown in DonorProfile
        profiles = list(DonorProfile.objects.all().values('id', 'phone_number'))
        total_profiles = len(profiles)

        format_counts = {
            '01... (11 digits)': 0,
            '8801... (13 digits)': 0,
            '+8801... (canonical E.164)': 0,
            'other / unparseable': 0,
            'empty / null': 0,
        }

        normalized_map = defaultdict(list)
        unparseable = []

        for p in profiles:
            raw = (p['phone_number'] or '').strip()
            pid = p['id']

            if not raw:
                format_counts['empty / null'] += 1
                continue

            # Classify raw format
            if raw.startswith('+8801'):
                format_counts['+8801... (canonical E.164)'] += 1
            elif raw.startswith('8801'):
                format_counts['8801... (13 digits)'] += 1
            elif raw.startswith('01'):
                format_counts['01... (11 digits)'] += 1
            else:
                format_counts['other / unparseable'] += 1

            # Attempt normalization
            try:
                canonical = normalize_bd_phone(raw)
                normalized_map[canonical].append(pid)
            except (ValueError, TypeError):
                unparseable.append((pid, mask_phone(raw)))

        self.stdout.write(f"\n[DonorProfile Phone Formats] Total profiles: {total_profiles}")
        for fmt, count in format_counts.items():
            pct = (count / total_profiles * 100) if total_profiles else 0
            self.stdout.write(f"  - {fmt:32}: {count:5} ({pct:5.1f}%)")

        # 2. Potential Duplicates After Normalization
        duplicates = {k: v for k, v in normalized_map.items() if len(v) > 1}
        self.stdout.write(f"\n[Potential Duplicate Phone Clusters]: {len(duplicates)}")
        if duplicates:
            for canon, ids in duplicates.items():
                self.stdout.write(
                    f"  - Canonical: {mask_phone(canon)} -> DonorProfile IDs: {ids} (count: {len(ids)})"
                )
        else:
            self.stdout.write("  No duplicate phone numbers found across profiles.")

        if unparseable:
            self.stdout.write(f"\n[Unparseable Phone Numbers]: {len(unparseable)}")
            for pid, masked in unparseable[:10]:
                self.stdout.write(f"  - DonorProfile #{pid}: {masked}")
            if len(unparseable) > 10:
                self.stdout.write(f"  ... and {len(unparseable) - 10} more.")

        # 3. Phone-Like Usernames in User Model
        users = list(User.objects.all().values('id', 'username'))
        total_users = len(users)
        phone_like_users = []

        for u in users:
            uname = (u['username'] or '').strip()
            uid = u['id']
            # Test whether username matches BD mobile phone pattern or is numeric BD mobile
            if BD_MOBILE_REGEX.match(uname):
                phone_like_users.append((uid, mask_phone(uname)))

        self.stdout.write(f"\n[User.username Phone Audit] Total users: {total_users}")
        self.stdout.write(f"  Phone-like usernames: {len(phone_like_users)}")
        if phone_like_users:
            for uid, masked in phone_like_users[:10]:
                self.stdout.write(f"  - User #{uid}: username={masked}")
            if len(phone_like_users) > 10:
                self.stdout.write(f"  ... and {len(phone_like_users) - 10} more.")

        self.stdout.write(self.style.SUCCESS("\nAudit complete. No rows modified.\n"))
