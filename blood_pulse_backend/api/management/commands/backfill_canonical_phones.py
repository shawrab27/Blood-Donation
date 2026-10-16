# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.db import transaction
from api.models import DonorProfile
from api.phone_utils import normalize_phone_number, mask_phone, is_valid_phone


class Command(BaseCommand):
    help = (
        "Backfill tool to canonicalize phone numbers on DonorProfile and linked User. "
        "Defaults to --dry-run mode for safety. Run with --apply to commit changes. "
        "Never prints unmasked PII."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--apply',
            action='store_true',
            default=False,
            help="Apply changes to the database. If omitted, runs in safe dry-run mode.",
        )

    def handle(self, *args, **options):
        apply_changes = options['apply']
        mode_str = "APPLY (CHANGES WILL BE SAVED)" if apply_changes else "DRY RUN (NO CHANGES SAVED)"
        self.stdout.write(self.style.NOTICE(f"=== Canonical Phone Backfill: {mode_str} ==="))

        profiles = DonorProfile.objects.select_related('user').all()
        total_profiles = profiles.count()
        self.stdout.write(f"Auditing {total_profiles} profiles...")

        updated_count = 0
        skipped_count = 0
        error_count = 0

        with transaction.atomic():
            for p in profiles:
                old_phone = p.phone_number
                user = p.user

                if not is_valid_phone(old_phone):
                    self.stdout.write(self.style.WARNING(
                        f"Profile ID {p.id}: phone '{mask_phone(old_phone)}' is not a valid BD mobile number. Skipping."
                    ))
                    error_count += 1
                    continue

                canonical_phone = normalize_phone_number(old_phone)

                needs_profile_update = (old_phone != canonical_phone)

                # Check if linked user username looks like a phone and needs canonicalization
                user_needs_update = False
                if user and is_valid_phone(user.username):
                    canonical_user = normalize_phone_number(user.username)
                    if user.username != canonical_user:
                        user_needs_update = True

                if not needs_profile_update and not user_needs_update:
                    skipped_count += 1
                    continue

                # Check for collision on DonorProfile
                if needs_profile_update:
                    collision = DonorProfile.objects.filter(phone_number=canonical_phone).exclude(pk=p.pk).first()
                    if collision:
                        self.stdout.write(self.style.ERROR(
                            f"Profile ID {p.id}: canonical collision with Profile ID {collision.id} ({mask_phone(canonical_phone)}). Skipping."
                        ))
                        error_count += 1
                        continue

                updated_count += 1
                action_tag = "[APPLIED]" if apply_changes else "[DRY-RUN WOULD UPDATE]"
                self.stdout.write(
                    f"{action_tag} Profile ID {p.id}: {mask_phone(old_phone)} -> {mask_phone(canonical_phone)}"
                )

                if apply_changes:
                    p.phone_number = canonical_phone
                    p.save(update_fields=['phone_number'])

                    if user_needs_update and user:
                        user.username = normalize_phone_number(user.username)
                        user.save(update_fields=['username'])

            if not apply_changes:
                # Force rollback in dry-run mode
                transaction.set_rollback(True)

        self.stdout.write("--------------------------------------------------")
        self.stdout.write(
            f"Summary: {updated_count} candidates to update, {skipped_count} already canonical, {error_count} skipped/errors."
        )
        if not apply_changes:
            self.stdout.write(self.style.NOTICE("Dry run complete. No database changes were made."))
