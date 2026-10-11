import os
import sys
from django.core.management.base import BaseCommand
from django.db import transaction
from api.models import Division, District, Upazila, LocalClub, BloodRequest
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS, DISTRICT_ALIASES


def is_artifact_name(name: str) -> bool:
    """Checks whether a name contains ASCII tree drawing artifacts like ├──, └──, │."""
    if not name:
        return False
    artifact_chars = {'├', '─', '└', '│'}
    return any(c in name for c in artifact_chars)


class Command(BaseCommand):
    help = "Idempotently seed official Bangladesh 8 divisions and 64 districts. Default is --dry-run."

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

    def handle(self, *args, **options):
        apply_changes = options.get('apply', False)
        cleanup_artifacts = options.get('cleanup_artifacts', False)
        mode_str = "APPLY" if apply_changes else "DRY-RUN"

        self.stdout.write(f"\n=======================================================")
        self.stdout.write(f"SEED BANGLADESH LOCATIONS: Mode [{mode_str}]")
        self.stdout.write(f"=======================================================\n")

        # Step 1: Detect and report artifact rows (tree characters)
        self.stdout.write("--- 1. ARTIFACT DETECTION REPORT ---")
        artifact_divisions = []
        for div in Division.objects.all():
            if is_artifact_name(div.name):
                artifact_divisions.append(div)

        artifact_districts = []
        for dist in District.objects.all():
            if is_artifact_name(dist.name):
                artifact_districts.append(dist)

        self.stdout.write(f"Found {len(artifact_divisions)} artifact division rows:")
        for ad in artifact_divisions:
            dists_count = ad.districts.count()
            clubs_count = LocalClub.objects.filter(division=ad).count()
            reqs_count = BloodRequest.objects.filter(division=ad).count()
            clean_disp = ad.name.encode('ascii', errors='backslashreplace').decode('ascii')
            self.stdout.write(
                f"  - Division ID {ad.id}: {clean_disp} | References: {dists_count} districts, {clubs_count} clubs, {reqs_count} blood requests"
            )

        self.stdout.write(f"\nFound {len(artifact_districts)} artifact district rows:")
        for ad in artifact_districts:
            upazilas_count = ad.upazilas.count()
            clubs_count = LocalClub.objects.filter(district=ad).count()
            clean_disp = ad.name.encode('ascii', errors='backslashreplace').decode('ascii')
            self.stdout.write(
                f"  - District ID {ad.id}: {clean_disp} (div: {ad.division_id}) | References: {upazilas_count} upazilas, {clubs_count} clubs"
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
                        # Unlink or delete upazilas referencing artifact districts
                        for ad in artifact_districts:
                            ad.upazilas.all().delete()
                            ad.delete()
                        for ad in artifact_divisions:
                            ad.districts.all().delete()
                            ad.delete()
                    self.stdout.write("Artifact rows deleted successfully.")
                else:
                    self.stdout.write("[DRY-RUN] Would delete artifact rows and their orphaned upazila children.")

        # Step 2: Seed / Reconcile Canonical 8 Divisions and 64 Districts
        self.stdout.write("\n--- 2. CANONICAL DIVISIONS & DISTRICTS RECONCILIATION ---")
        divisions_to_create = []
        divisions_existing = []
        districts_to_create = []
        districts_to_update = []
        districts_existing = []

        total_canonical_divisions = len(BD_DIVISIONS_AND_DISTRICTS)
        total_canonical_districts = sum(len(dists) for dists in BD_DIVISIONS_AND_DISTRICTS.values())

        for div_name, dist_names in BD_DIVISIONS_AND_DISTRICTS.items():
            div = Division.objects.filter(name=div_name).first()
            if not div:
                divisions_to_create.append(div_name)
                div_id_display = "(new)"
            else:
                divisions_existing.append(div_name)
                div_id_display = f"(id: {div.id})"

            for dist_name in dist_names:
                # Find matching district
                # Check direct match under division
                dist = None
                if div:
                    dist = District.objects.filter(division=div, name=dist_name).first()
                    if not dist:
                        # Check alternate alias (e.g. Chapainawabganj vs Chapai Nawabganj)
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
            f"Canonical targets: {total_canonical_divisions} divisions, {total_canonical_districts} districts\n"
            f"  - Divisions: {len(divisions_existing)} existing, {len(divisions_to_create)} to create\n"
            f"  - Districts: {len(districts_existing)} matched, {len(districts_to_update)} to rename to canonical, {len(districts_to_create)} to create"
        )

        for old_dist, new_name in districts_to_update:
            self.stdout.write(f"  * Will update District ID {old_dist.id}: '{old_dist.name}' -> '{new_name}'")

        for d_div, d_name in districts_to_create:
            self.stdout.write(f"  * Will create District in {d_div.name}: '{d_name}'")

        if apply_changes:
            self.stdout.write("\nWriting canonical changes to database...")
            with transaction.atomic():
                for div_name, dist_names in BD_DIVISIONS_AND_DISTRICTS.items():
                    div_obj, created = Division.objects.get_or_create(name=div_name)
                    for dist_name in dist_names:
                        # Check if district already exists with canonical name
                        dist_obj = District.objects.filter(division=div_obj, name=dist_name).first()
                        if not dist_obj:
                            # Check if existing district exists under alias name and update it
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

            self.stdout.write(self.style.SUCCESS("Database successfully seeded/updated with canonical BD locations!"))
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

        self.stdout.write("=======================================================\n")
