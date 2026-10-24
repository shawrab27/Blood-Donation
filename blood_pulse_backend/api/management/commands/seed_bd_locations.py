import os
import sys
from django.core.management.base import BaseCommand
from django.db import transaction
from django.conf import settings
from api.models import Division, District, Upazila, LocalClub, BloodRequest
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS, DISTRICT_ALIASES
from api.data.bd_upazilas import BD_DISTRICT_UPAZILAS


def is_artifact_name(name: str) -> bool:
    """Checks whether a name contains ASCII tree drawing artifacts like ├──, └──, │."""
    if not name:
        return False
    artifact_chars = {'├', '─', '└', '│', '┌', '┐', '┬', '┴', '┼'}
    return any(c in name for c in artifact_chars)


class Command(BaseCommand):
    help = "Idempotently seed official Bangladesh 8 divisions, 64 districts, and canonical upazilas. Default is --dry-run."

    def add_arguments(self, parser):
        parser.add_argument(
            '--apply',
            action='store_true',
            help='Apply changes to the database. Without this flag, runs in dry-run mode.',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Run in dry-run mode (default). Does not write any changes.',
        )
        parser.add_argument(
            '--cleanup-artifacts',
            action='store_true',
            help='Clean up tree artifact rows. Only permitted in dev/test environment and with explicit flag.',
        )
        parser.add_argument(
            '--force-production',
            action='store_true',
            help='Explicit authorization required when executing against production database (ep-proud-dew).',
        )

    def handle(self, *args, **options):
        # Critical Safety Guard: Require explicit --force-production if running on production (ep-proud-dew)
        force_prod = options.get('force_production', False)
        db_settings = settings.DATABASES.get('default', {})
        db_host = db_settings.get('HOST', '') or ''
        database_url = os.environ.get('DATABASE_URL', '') or ''
        if ('ep-proud-dew' in db_host or 'ep-proud-dew' in database_url) and not force_prod:
            self.stderr.write(self.style.ERROR(
                "CRITICAL SAFETY VIOLATION: seed_bd_locations on production database (ep-proud-dew) requires explicit --force-production flag!"
            ))
            return

        apply_changes = options.get('apply', False)
        cleanup_artifacts = options.get('cleanup_artifacts', False)
        mode_str = "APPLY" if apply_changes else "DRY-RUN"

        db_engine = db_settings.get('ENGINE', '').split('.')[-1]
        db_name = db_settings.get('NAME', '')
        host_display = db_host if db_host else "local"

        self.stdout.write(f"\n=======================================================")
        self.stdout.write(f"SEED BANGLADESH LOCATIONS: Mode [{mode_str}]")
        self.stdout.write(f"Database: {db_engine} | host={host_display} | db={db_name}")
        self.stdout.write(f"=======================================================\n")

        # Step 1: Detect and report artifact rows (tree characters)
        self.stdout.write("--- 1. ARTIFACT DETECTION REPORT ---")
        artifact_divisions = [div for div in Division.objects.all() if is_artifact_name(div.name)]
        artifact_districts = [dist for dist in District.objects.all() if is_artifact_name(dist.name)]
        artifact_upazilas = [up for up in Upazila.objects.all() if is_artifact_name(up.name)]

        self.stdout.write(
            f"Found {len(artifact_divisions)} artifact division rows, "
            f"{len(artifact_districts)} artifact district rows, "
            f"{len(artifact_upazilas)} artifact upazila rows:"
        )
        for ad in artifact_divisions:
            dists_count = ad.districts.count()
            clubs_count = LocalClub.objects.filter(division=ad).count()
            reqs_count = BloodRequest.objects.filter(division=ad).count()
            clean_disp = ad.name.encode('ascii', errors='backslashreplace').decode('ascii')
            self.stdout.write(
                f"  - Division ID {ad.id}: {clean_disp} | References: {dists_count} districts, {clubs_count} clubs, {reqs_count} blood requests"
            )

        for ad in artifact_districts:
            upazilas_count = ad.upazilas.count()
            clubs_count = LocalClub.objects.filter(district=ad).count()
            clean_disp = ad.name.encode('ascii', errors='backslashreplace').decode('ascii')
            self.stdout.write(
                f"  - District ID {ad.id}: {clean_disp} (div: {ad.division_id}) | References: {upazilas_count} upazilas, {clubs_count} clubs"
            )

        for au in artifact_upazilas:
            clean_disp = au.name.encode('ascii', errors='backslashreplace').decode('ascii')
            self.stdout.write(
                f"  - Upazila ID {au.id}: {clean_disp} (district: {au.district_id})"
            )

        # Handle optional cleanup if explicitly requested in dev/test
        if cleanup_artifacts:
            django_env = os.environ.get('DJANGO_ENV', '').lower()
            if django_env not in ('dev', 'test') and os.environ.get('USE_SQLITE') != '1' and os.environ.get('USE_TEST_POSTGRES') != '1':
                self.stderr.write("ERROR: --cleanup-artifacts is strictly forbidden outside dev/test environments!")
            else:
                self.stdout.write("\nCleaning up artifact rows (dev/test only)...")
                if apply_changes:
                    with transaction.atomic():
                        for au in artifact_upazilas:
                            au.delete()
                        for ad in artifact_districts:
                            ad.upazilas.all().delete()
                            ad.delete()
                        for ad in artifact_divisions:
                            ad.districts.all().delete()
                            ad.delete()
                    self.stdout.write("Artifact rows deleted successfully.")
                else:
                    self.stdout.write("[DRY-RUN] Would delete artifact rows and their orphaned upazila children.")

        # Step 2: Seed / Reconcile Canonical 8 Divisions, 64 Districts, and Upazilas
        self.stdout.write("\n--- 2. CANONICAL DIVISIONS, DISTRICTS & UPAZILAS RECONCILIATION ---")
        divisions_to_create = []
        divisions_existing = []
        districts_to_create = []
        districts_to_update = []
        districts_existing = []

        total_canonical_divisions = len(BD_DIVISIONS_AND_DISTRICTS)
        total_canonical_districts = sum(len(dists) for dists in BD_DIVISIONS_AND_DISTRICTS.values())
        total_canonical_upazilas = sum(len(ups) for ups in BD_DISTRICT_UPAZILAS.values())

        for div_name, dist_names in BD_DIVISIONS_AND_DISTRICTS.items():
            div = Division.objects.filter(name=div_name).first()
            if not div:
                divisions_to_create.append(div_name)
            else:
                divisions_existing.append(div_name)

            for dist_name in dist_names:
                dist = None
                if div:
                    dist = District.objects.filter(division=div, name=dist_name).first()
                    if not dist:
                        for alt_k, alt_v in DISTRICT_ALIASES.items():
                            if alt_v == dist_name:
                                dist_alt = District.objects.filter(division=div, name=alt_k).first()
                                if dist_alt:
                                    dist = dist_alt
                                    districts_to_update.append((dist_alt, dist_name))
                                    break

                if not dist and div:
                    districts_to_create.append((div, dist_name))
                elif dist and dist.name == dist_name:
                    districts_existing.append((div_name, dist_name))

        self.stdout.write(
            f"Canonical targets: {total_canonical_divisions} divisions, {total_canonical_districts} districts, {total_canonical_upazilas} upazilas\n"
            f"  - Divisions: {len(divisions_existing)} existing, {len(divisions_to_create)} to create\n"
            f"  - Districts: {len(districts_existing)} matched, {len(districts_to_update)} to rename to canonical, {len(districts_to_create)} to create\n"
            f"  - Upazilas dataset: {total_canonical_upazilas} valid upazilas across {len(BD_DISTRICT_UPAZILAS)} districts"
        )

        for old_dist, new_name in districts_to_update:
            self.stdout.write(f"  * Will update District ID {old_dist.id}: '{old_dist.name}' -> '{new_name}'")

        for d_div, d_name in districts_to_create:
            self.stdout.write(f"  * Will create District in {d_div.name}: '{d_name}'")

        if apply_changes:
            self.stdout.write("\nWriting canonical changes to database...")
            current_entity = "init"
            current_district = None
            current_upazila = None
            try:
                with transaction.atomic():
                    # 1. Seed / Reconcile Divisions & Districts
                    for div_name, dist_names in BD_DIVISIONS_AND_DISTRICTS.items():
                        current_entity = f"division={div_name}"
                        div_obj, _ = Division.objects.get_or_create(name=div_name)
                        for dist_name in dist_names:
                            current_entity = f"district={dist_name} in div={div_name}"
                            dist_obj = District.objects.filter(division=div_obj, name=dist_name).first()
                            if not dist_obj:
                                updated = False
                                for alt_k, alt_v in DISTRICT_ALIASES.items():
                                    if alt_v == dist_name:
                                        dist_alias = District.objects.filter(division=div_obj, name=alt_k).first()
                                        if dist_alias:
                                            dist_alias.name = dist_name
                                            dist_alias.save(update_fields=['name'])
                                            updated = True
                                            break
                                if not updated:
                                    District.objects.create(division=div_obj, name=dist_name)

                    # 2. Seed Canonical Upazilas for all districts
                    seeded_upazilas = 0
                    for d_name, up_names in BD_DISTRICT_UPAZILAS.items():
                        current_district = d_name
                        target_dist = District.objects.filter(name=d_name).first()
                        if not target_dist:
                            raise ValueError(f"Target district '{d_name}' does not exist in database!")
                        for up_name in up_names:
                            current_upazila = up_name
                            if len(up_name) > 100:
                                raise ValueError(
                                    f"Upazila name exceeds 100 chars (len={len(up_name)}): {up_name!r}"
                                )
                            if is_artifact_name(up_name):
                                raise ValueError(
                                    f"Upazila name contains artifact characters: {up_name!r}"
                                )
                            _, created_up = Upazila.objects.get_or_create(district=target_dist, name=up_name)
                            if created_up:
                                seeded_upazilas += 1

                self.stdout.write(self.style.SUCCESS(
                    f"Database successfully seeded/updated with canonical BD locations! ({seeded_upazilas} new upazilas created)"
                ))
            except Exception as exc:
                self.stderr.write(self.style.ERROR(
                    f"Seeding aborted and rolled back! Offending entity: district='{current_district}', "
                    f"upazila={current_upazila!r}, stage='{current_entity}'. Error: {exc}"
                ))
                raise
        else:
            self.stdout.write(self.style.WARNING("\n[DRY-RUN] No changes were written. Use --apply to execute."))

        # Final Summary Verification
        self.stdout.write("\n--- 3. PER-DIVISION VERIFICATION SUMMARY ---")
        for div_name, dist_names in BD_DIVISIONS_AND_DISTRICTS.items():
            div_qs = Division.objects.filter(name=div_name)
            if div_qs.exists():
                div = div_qs.first()
                clean_districts = div.districts.exclude(name__contains='├').exclude(name__contains='│').exclude(name__contains='└')
                self.stdout.write(
                    f"  {div_name}: canonical expected={len(dist_names)}, actual in DB={clean_districts.count()}"
                )
            else:
                self.stdout.write(f"  {div_name}: NOT FOUND in DB (will be created on --apply)")

        total_clean_upazilas = Upazila.objects.exclude(name__contains='├').exclude(name__contains='│').exclude(name__contains='└').count()
        self.stdout.write(f"\nTotal canonical upazilas in DB: {total_clean_upazilas}")
        self.stdout.write("=======================================================\n")
