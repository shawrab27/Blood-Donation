import os
import csv
from collections import Counter
from django.core.management.base import BaseCommand
from django.conf import settings
from api.models import Institution
from api.management.commands.institution_import_utils import (
    DISTRICT_ALIAS_MAP,
    get_district_cache,
    parse_banbeis_file,
    load_institution_aliases_from_csv,
)


class Command(BaseCommand):
    help = 'Import institutions from official BANBEIS Excel files based on file_types.csv'

    def add_arguments(self, parser):
        parser.add_argument(
            'data_dir',
            nargs='?',
            default='data/institutions',
            help='Directory containing Excel files and file_types.csv'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Perform a dry run without saving to the database'
        )

    def handle(self, *args, **options):
        data_dir = options['data_dir']
        dry_run = options['dry_run']

        if not os.path.isabs(data_dir):
            data_dir = os.path.join(settings.BASE_DIR, data_dir)

        csv_path = os.path.join(data_dir, 'file_types.csv')
        if not os.path.exists(csv_path):
            self.stderr.write(self.style.ERROR(f"file_types.csv not found at {csv_path}"))
            return

        with open(csv_path, 'r', encoding='utf-8') as f:
            file_configs = list(csv.DictReader(f))

        district_map = get_district_cache()

        self.stdout.write("=" * 80)
        self.stdout.write("DISTRICT ALIAS MAP & VERIFICATION")
        self.stdout.write("=" * 80)
        for raw_alias, target_name in DISTRICT_ALIAS_MAP.items():
            matched = district_map.get(target_name)
            m_id = matched.id if matched else 'None'
            m_name = matched.name if matched else 'NOT FOUND'
            self.stdout.write(f"  Excel '{raw_alias}' -> DB '{target_name}' (ID: {m_id}, Name: '{m_name}')")

        seen_records = {}
        file_summary = []
        unmatched_districts = Counter()

        self.stdout.write("\n" + "=" * 80)
        self.stdout.write(f"BANBEIS INSTITUTION IMPORT (DRY-RUN: {dry_run})")
        self.stdout.write("=" * 80)

        for cfg in file_configs:
            file_name = cfg['file_name'].strip()
            itype = cfg['type'].strip()
            status = cfg['status'].strip()

            if status != 'CONFIRMED' or itype == 'SKIP' or not itype:
                self.stdout.write(f"Skipping '{file_name}' (status={status}, type={itype})")
                continue

            file_path = os.path.join(data_dir, file_name)
            if not os.path.exists(file_path):
                self.stderr.write(self.style.ERROR(f"File not found: {file_path}"))
                continue

            parsed = parse_banbeis_file(file_path, file_name, itype, district_map)
            unmatched_districts.update(parsed['unmatched_districts'])

            inserted = 0
            updated = 0
            for item in parsed['records']:
                dkey = item['dedupe_key']
                rec_copy = dict(item)
                del rec_copy['dedupe_key']
                if dkey in seen_records:
                    updated += 1
                    seen_records[dkey].update(rec_copy)
                else:
                    inserted += 1
                    seen_records[dkey] = rec_copy

            file_summary.append({
                'file': file_name,
                'type': itype,
                'read': parsed['rows_read'],
                'inserted': inserted,
                'updated': updated,
                'rejected': parsed['rejected'],
            })

        self.stdout.write("\n" + "=" * 80)
        self.stdout.write("PER-FILE IMPORT REPORT TABLE")
        self.stdout.write("=" * 80)
        header_line = f"{'File':<25} | {'Type':<12} | {'Rows Read':>9} | {'Inserted':>8} | {'Updated':>7} | {'Rejected':>8}"
        self.stdout.write(header_line)
        self.stdout.write("-" * len(header_line))

        total_read = sum(s['read'] for s in file_summary)
        total_inserted = sum(s['inserted'] for s in file_summary)
        total_updated = sum(s['updated'] for s in file_summary)
        total_rejected = sum(len(s['rejected']) for s in file_summary)

        for s in file_summary:
            rej_cnt = len(s['rejected'])
            self.stdout.write(
                f"{s['file']:<25} | {s['type']:<12} | {s['read']:>9} | {s['inserted']:>8} | "
                f"{s['updated']:>7} | {rej_cnt:>8}"
            )
        self.stdout.write("-" * len(header_line))
        self.stdout.write(
            f"{'TOTAL':<25} | {'':<12} | {total_read:>9} | {total_inserted:>8} | "
            f"{total_updated:>7} | {total_rejected:>8}"
        )

        self.stdout.write("\n" + "=" * 80)
        self.stdout.write("UNMATCHED DISTRICT_NAME VALUES (AFTER ALIAS MAPPING)")
        self.stdout.write("=" * 80)
        if unmatched_districts:
            for dname, cnt in sorted(unmatched_districts.items(), key=lambda x: -x[1]):
                self.stdout.write(f"  {dname:<20}: {cnt} rows")
        else:
            self.stdout.write("  None (100% of rows matched to District table!)")

        if dry_run:
            self.stdout.write(self.style.SUCCESS("\n[DRY RUN COMPLETE] Zero database rows were modified or created."))
            return

        self.stdout.write(f"\nExecuting REAL import: processing {len(seen_records)} institutions into database...")
        existing_institutions = {inst.eiin: inst for inst in Institution.objects.all() if inst.eiin}
        to_create = []
        to_update = []
        unchanged_count = 0

        for key, rec in seen_records.items():
            eiin = rec['eiin']
            if eiin and eiin in existing_institutions:
                inst = existing_institutions[eiin]
                changed = False
                for field in ['name', 'institution_type', 'district', 'division_name', 'district_name', 'upazila_name', 'source_file']:
                    if getattr(inst, field) != rec[field]:
                        setattr(inst, field, rec[field])
                        changed = True
                if changed:
                    to_update.append(inst)
                else:
                    unchanged_count += 1
            else:
                to_create.append(Institution(**rec))

        if to_create:
            Institution.objects.bulk_create(to_create, batch_size=2000)
            self.stdout.write(f"Inserted: {len(to_create)} new institutions.")
        else:
            self.stdout.write("Inserted: 0 new institutions.")

        if to_update:
            fields_to_update = ['name', 'institution_type', 'district', 'division_name', 'district_name', 'upazila_name', 'source_file']
            Institution.objects.bulk_update(to_update, fields_to_update, batch_size=2000)
            self.stdout.write(f"Updated: {len(to_update)} existing institutions.")
        else:
            self.stdout.write("Updated: 0 institutions.")

        self.stdout.write(f"Unchanged: {unchanged_count} institutions.")
        final_count = Institution.objects.count()
        self.stdout.write(self.style.SUCCESS(f"Total institutions in database: {final_count}"))

        # Load aliases if aliases.csv exists
        aliases_csv_path = os.path.join(data_dir, 'aliases.csv')
        if os.path.exists(aliases_csv_path):
            load_institution_aliases_from_csv(aliases_csv_path, stdout=self.stdout)
