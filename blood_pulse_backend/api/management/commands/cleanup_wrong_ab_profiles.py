# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from api.models import DonorProfile


class Command(BaseCommand):
    help = (
        "Identify and optionally reset blood_group for incomplete profiles that were mistakenly "
        "assigned 'AB+' without explicit user confirmation. Defaults to dry-run."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--apply',
            action='store_true',
            default=False,
            help="Actually apply changes to the database. If not set, runs in read-only dry-run mode.",
        )

    def handle(self, *args, **options):
        apply_changes = options['apply']
        mode_str = "APPLY" if apply_changes else "DRY-RUN (read-only)"

        self.stdout.write(self.style.NOTICE(f"=== Cleanup Wrong AB+ Profiles [{mode_str}] ==="))

        # Query all incomplete profiles with AB+
        affected_qs = DonorProfile.objects.filter(
            blood_group='AB+',
            is_profile_complete=False,
        ).select_related('user')

        total = affected_qs.count()
        if total == 0:
            self.stdout.write(self.style.SUCCESS("No incomplete profiles found with blood_group='AB+'."))
            return

        self.stdout.write(self.style.WARNING(f"Found {total} incomplete profile(s) with blood_group='AB+':"))
        self.stdout.write("-" * 80)
        self.stdout.write(f"{'Profile ID':<12} | {'User ID':<8} | {'Username':<22} | {'Email':<25} | {'Provider':<10}")
        self.stdout.write("-" * 80)

        for p in affected_qs:
            user = p.user
            username = (user.username if user else 'N/A')[:22]
            email = (user.email if user else 'N/A')[:25]
            provider = p.auth_provider or 'unknown'
            self.stdout.write(f"{p.id:<12} | {getattr(user, 'id', 'N/A')!s:<8} | {username:<22} | {email:<25} | {provider:<10}")

        self.stdout.write("-" * 80)

        if apply_changes:
            updated_count = 0
            for p in affected_qs:
                p.blood_group = ''
                p.save(update_fields=['blood_group'])
                updated_count += 1
            self.stdout.write(self.style.SUCCESS(f"Successfully reset blood_group to '' for {updated_count} profile(s)."))
        else:
            self.stdout.write(
                self.style.NOTICE(
                    f"\n[DRY-RUN] {total} profile(s) listed above would be reset to blood_group=''.\n"
                    "No database changes were applied. To apply, rerun with --apply."
                )
            )
