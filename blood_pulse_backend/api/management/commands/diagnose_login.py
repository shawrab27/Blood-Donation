# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db.models import Q
from api.models import DonorProfile
from api.phone_utils import get_phone_variants, mask_phone, is_valid_phone, normalize_bd_phone

User = get_user_model()


class Command(BaseCommand):
    help = (
        "READ-ONLY diagnostic tool for login troubleshooting (Anomaly #2). "
        "Prints (masked) whether a matching user exists, is_active, and whether a different user has a similar number. "
        "Changes nothing in the database."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            type=str,
            help="Phone number to diagnose (e.g. 01601239009, +8801601239023)",
        )
        parser.add_argument(
            'phone_pos',
            nargs='?',
            type=str,
            default=None,
            help="Optional positional phone number",
        )

    def handle(self, *args, **options):
        raw_phone = options.get('phone') or options.get('phone_pos')
        if not raw_phone:
            self.stderr.write(self.style.ERROR("Error: --phone <number> is required."))
            return

        raw_phone = str(raw_phone).strip()
        input_masked = mask_phone(raw_phone)
        self.stdout.write(self.style.NOTICE(f"=== Diagnosing Login for Phone: {input_masked} ==="))

        is_valid = is_valid_phone(raw_phone)
        self.stdout.write(f"Valid BD mobile format: {is_valid}")
        if is_valid:
            canonical = normalize_bd_phone(raw_phone)
            self.stdout.write(f"Canonical form: {mask_phone(canonical)}")
        else:
            canonical = raw_phone

        variants = get_phone_variants(raw_phone)

        # 1. Exact/Variant matches
        user_filter = Q()
        for v in variants:
            user_filter |= Q(username__iexact=v) | Q(username__endswith=v) | Q(donorprofile__phone_number=v) | Q(donorprofile__phone_number__endswith=v)
        
        matches = list(User.objects.filter(user_filter).distinct())

        self.stdout.write(f"Matching user accounts found: {len(matches)}")
        if matches:
            for u in matches:
                p = getattr(u, 'donorprofile', None)
                p_phone = mask_phone(p.phone_number) if p else "None"
                self.stdout.write(
                    f"  -> User ID: {u.id} | username: {mask_phone(u.username)} | "
                    f"is_active: {u.is_active} | usable_password: {u.has_usable_password()} | "
                    f"profile_phone: {p_phone}"
                )
        else:
            self.stdout.write(self.style.WARNING("  No matching user account found for this exact number/variants."))

        # 2. Check for similar numbers (e.g., typos like 01601239009 vs 01601239023)
        digits = ''.join(c for c in raw_phone if c.isdigit())
        core_10 = digits[-10:] if len(digits) >= 10 else digits
        prefix_8 = core_10[:8] if len(core_10) >= 8 else core_10

        self.stdout.write("\n=== Checking for Similar Numbers in Database ===")
        if prefix_8:
            similar_profiles = DonorProfile.objects.filter(
                Q(phone_number__contains=prefix_8)
            ).select_related('user').exclude(user__in=matches)[:10]

            similar_users = User.objects.filter(
                Q(username__contains=prefix_8)
            ).exclude(id__in=[u.id for u in matches]).exclude(
                id__in=[p.user_id for p in similar_profiles]
            )[:10]

            found_similar = False
            for p in similar_profiles:
                found_similar = True
                u = p.user
                self.stdout.write(
                    f"  [SIMILAR] DonorProfile ID {p.id} (User ID {u.id}): "
                    f"phone: {mask_phone(p.phone_number)} | username: {mask_phone(u.username)} | "
                    f"is_active: {u.is_active}"
                )

            for u in similar_users:
                found_similar = True
                self.stdout.write(
                    f"  [SIMILAR] User ID {u.id}: username: {mask_phone(u.username)} | "
                    f"is_active: {u.is_active}"
                )

            if not found_similar:
                self.stdout.write("  No other accounts with similar number prefix found.")
        else:
            self.stdout.write("  Phone number too short for prefix comparison.")

        self.stdout.write(self.style.SUCCESS("\nDiagnostic complete. Database state unchanged (READ-ONLY)."))
