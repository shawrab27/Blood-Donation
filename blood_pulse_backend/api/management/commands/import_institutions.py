import os
import re
import csv
import random
import unicodedata
from collections import Counter
import openpyxl
from django.core.management.base import BaseCommand
from django.conf import settings
from api.models import Institution, District

DISTRICT_ALIAS_MAP = {
    'netrakona': 'netrokona',
    'nawabganj': 'chapainawabganj',
    'brahamanbaria': 'brahmanbaria',
    'coxs bazar': "cox's bazar",
    'jhalokati': 'jhalokathi',
    'maulvibazar': 'moulvibazar',
    'norail': 'narail',
}


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

    def _normalize(self, val):
        if val is None:
            return None
        s = unicodedata.normalize('NFC', str(val)).strip()
        s = re.sub(r'\s+', ' ', s)
        return s if s else None

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

        # Pre-cache District table for exact case-insensitive lookup
        district_map = {d.name.strip().lower(): d for d in District.objects.exclude(name__contains='\u2502')}

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
        karigori_eiins = set()
        sotontro_eiins = set()
        all_inserted_samples = []

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

            header_row = 2 if file_name in ['college.xlsx', 'school_list.xlsx'] else 1
            wb = openpyxl.load_workbook(file_path, data_only=True)
            ws = wb.active

            # Map column headers by exact NAME
            headers = [ws.cell(header_row, c).value for c in range(1, ws.max_column + 1)]
            col_map = {}
            for idx, h in enumerate(headers, start=1):
                if not h:
                    continue
                hl = str(h).strip().lower()
                if hl in ['institute_name', 'institution_name', 'name']:
                    col_map['name'] = idx
                elif hl in ['eiin_no', 'eiin']:
                    col_map['eiin'] = idx
                elif hl in ['division_name', 'division']:
                    col_map['division'] = idx
                elif hl in ['district_name', 'district']:
                    col_map['district'] = idx
                elif hl in ['thana_name', 'thana', 'upazila_name', 'upazila']:
                    col_map['thana'] = idx

            if 'name' not in col_map:
                self.stderr.write(self.style.ERROR(f"Ambiguous or missing name column in {file_name}! STOPPING."))
                return

            rows_read = 0
            inserted = 0
            updated = 0
            rejected = []

            for r in range(header_row + 1, ws.max_row + 1):
                raw_name = ws.cell(r, col_map['name']).value if 'name' in col_map else None
                raw_eiin = ws.cell(r, col_map['eiin']).value if 'eiin' in col_map else None
                raw_div = ws.cell(r, col_map['division']).value if 'division' in col_map else None
                raw_dist = ws.cell(r, col_map['district']).value if 'district' in col_map else None
                raw_thana = ws.cell(r, col_map['thana']).value if 'thana' in col_map else None

                if all(v is None or str(v).strip() == '' for v in [raw_name, raw_eiin, raw_div, raw_dist, raw_thana]):
                    continue

                rows_read += 1
                name = self._normalize(raw_name)
                if not name:
                    rejected.append((r, "Empty institution name"))
                    continue

                eiin = self._normalize(raw_eiin)
                div_name = self._normalize(raw_div)
                dist_name = self._normalize(raw_dist)
                upazila_name = self._normalize(raw_thana)

                clean_dist = dist_name.lower() if dist_name else ''
                matched_district = district_map.get(clean_dist)
                if not matched_district and clean_dist in DISTRICT_ALIAS_MAP:
                    matched_district = district_map.get(DISTRICT_ALIAS_MAP[clean_dist])

                if dist_name and not matched_district:
                    unmatched_districts[dist_name] += 1

                if file_name == 'karigori.xlsx' and eiin:
                    karigori_eiins.add(eiin)
                elif file_name == 'sotontro karigori.xlsx' and eiin:
                    sotontro_eiins.add(eiin)

                dedupe_key = ('eiin', eiin) if eiin else ('name_dist', name.lower(), (dist_name or '').lower())
                record_dict = {
                    'name': name,
                    'eiin': eiin,
                    'institution_type': itype,
                    'district': matched_district,
                    'division_name': div_name,
                    'district_name': dist_name,
                    'upazila_name': upazila_name,
                    'source_file': file_name,
                }

                if dedupe_key in seen_records:
                    updated += 1
                    seen_records[dedupe_key].update(record_dict)
                else:
                    inserted += 1
                    seen_records[dedupe_key] = record_dict
                    raw_row_tuple = (raw_eiin, raw_name, raw_div, raw_dist, raw_thana)
                    all_inserted_samples.append((raw_row_tuple, record_dict))

            file_summary.append({
                'file': file_name,
                'type': itype,
                'read': rows_read,
                'inserted': inserted,
                'updated': updated,
                'rejected': rejected,
            })

        # --- REPORT SUMMARY TABLES ---
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

        # REAL IMPORT: Idempotent upsert
        self.stdout.write(f"\nExecuting REAL import: processing {len(seen_records)} institutions into local SQLite...")
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
            batch_size = 2000
            Institution.objects.bulk_create(to_create, batch_size=batch_size)
            self.stdout.write(f"Inserted: {len(to_create)} new institutions.")
        else:
            self.stdout.write("Inserted: 0 new institutions.")

        if to_update:
            batch_size = 2000
            fields_to_update = ['name', 'institution_type', 'district', 'division_name', 'district_name', 'upazila_name', 'source_file']
            Institution.objects.bulk_update(to_update, fields_to_update, batch_size=batch_size)
            self.stdout.write(f"Updated: {len(to_update)} existing institutions.")
        else:
            self.stdout.write("Updated: 0 institutions.")

        self.stdout.write(f"Unchanged: {unchanged_count} institutions.")
        final_count = Institution.objects.count()
        self.stdout.write(self.style.SUCCESS(f"Total institutions in database: {final_count}"))
