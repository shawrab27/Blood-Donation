# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.apps import apps
from django.db import connection, transaction
from api.fields import (
    EncryptedCharField,
    EncryptedBinaryField,
    get_primary_cipher,
    get_multi_cipher,
)


class Command(BaseCommand):
    help = (
        "Re-encrypts all database records that were encrypted with a legacy or fallback key "
        "using the new primary FIELD_ENCRYPTION_KEY. Runs in dry-run mode by default."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            default=True,
            help="Simulate the re-encryption process and report counts without modifying database rows (default: True).",
        )
        parser.add_argument(
            '--confirm',
            action='store_true',
            default=False,
            help="Confirm execution to perform the actual in-place database re-encryption.",
        )
        parser.add_argument(
            '--batch-size',
            type=int,
            default=100,
            help="Number of records to re-encrypt per transaction batch (default: 100).",
        )

    def handle(self, *args, **options):
        dry_run = not options['confirm'] or options.get('dry_run_explicit', False)
        if options['confirm']:
            dry_run = False

        batch_size = max(1, options['batch_size'])
        mode_label = "DRY-RUN (no database changes)" if dry_run else "REAL RUN (database updates enabled)"

        self.stdout.write("=" * 70)
        self.stdout.write("       BLOODPULSE FIELD RE-ENCRYPTION UTILITY       ")
        self.stdout.write("=" * 70)
        self.stdout.write(f"Execution Mode : {mode_label}")
        self.stdout.write(f"Batch Size     : {batch_size}")
        self.stdout.write("-" * 70)

        primary_cipher = get_primary_cipher()
        multi_cipher = get_multi_cipher()

        # Discover all models with EncryptedCharField or EncryptedBinaryField
        target_fields = []
        for model in apps.get_models():
            for field in model._meta.get_fields():
                if isinstance(field, (EncryptedCharField, EncryptedBinaryField)):
                    target_fields.append((model, field))

        if not target_fields:
            self.stdout.write(self.style.WARNING("No encrypted model fields discovered in the application."))
            return

        grand_total_scanned = 0
        grand_total_current = 0
        grand_total_rotated = 0
        grand_total_unrecoverable = 0

        for model, field in target_fields:
            table_name = model._meta.db_table
            col_name = field.column
            pk_col = model._meta.pk.column

            self.stdout.write(f"\nInspecting {model.__name__}.{field.name} (table: {table_name}, column: {col_name})...")

            # Fetch non-null raw values directly via cursor to inspect raw cipher bytes
            with connection.cursor() as cursor:
                cursor.execute(
                    f"SELECT {pk_col}, {col_name} FROM {table_name} WHERE {col_name} IS NOT NULL"
                )
                rows = cursor.fetchall()

            scanned = len(rows)
            already_current = 0
            to_rotate = []
            unrecoverable = 0

            for pk, raw_val in rows:
                if raw_val is None:
                    continue

                if isinstance(raw_val, memoryview):
                    raw_bytes = raw_val.tobytes()
                elif isinstance(raw_val, str):
                    raw_bytes = raw_val.encode('utf-8')
                elif isinstance(raw_val, bytes):
                    raw_bytes = raw_val
                else:
                    raw_bytes = str(raw_val).encode('utf-8')

                # Check if already encrypted with primary key
                try:
                    primary_cipher.decrypt(raw_bytes)
                    already_current += 1
                    continue
                except Exception:
                    pass

                # Check if decryptable with fallback key(s) in multi_cipher
                try:
                    multi_cipher.decrypt(raw_bytes)
                    to_rotate.append((pk, raw_bytes))
                except Exception:
                    unrecoverable += 1

            self.stdout.write(f"  - Total records with data : {scanned}")
            self.stdout.write(f"  - Already on primary key  : {already_current}")
            self.stdout.write(f"  - Needing re-encryption   : {len(to_rotate)}")
            if unrecoverable:
                self.stdout.write(self.style.WARNING(f"  - Unrecoverable / corrupt : {unrecoverable}"))

            # Execute rotation in batches if not dry-run
            rotated_count = 0
            if not dry_run and to_rotate:
                total_batches = (len(to_rotate) + batch_size - 1) // batch_size
                for b_idx in range(total_batches):
                    batch = to_rotate[b_idx * batch_size : (b_idx + 1) * batch_size]
                    with transaction.atomic():
                        with connection.cursor() as update_cursor:
                            for pk, old_raw in batch:
                                new_raw = multi_cipher.rotate(old_raw)
                                if isinstance(field, EncryptedCharField):
                                    # EncryptedCharField expects decoded string
                                    update_val = new_raw.decode('utf-8')
                                else:
                                    # EncryptedBinaryField expects bytes
                                    update_val = new_raw

                                update_cursor.execute(
                                    f"UPDATE {table_name} SET {col_name} = %s WHERE {pk_col} = %s",
                                    [update_val, pk]
                                )
                                rotated_count += 1

                self.stdout.write(self.style.SUCCESS(f"  - Successfully re-encrypted : {rotated_count} records"))
            elif dry_run and to_rotate:
                self.stdout.write(f"  - Would re-encrypt        : {len(to_rotate)} records (dry-run)")

            grand_total_scanned += scanned
            grand_total_current += already_current
            grand_total_rotated += (rotated_count if not dry_run else len(to_rotate))
            grand_total_unrecoverable += unrecoverable

        self.stdout.write("\n" + "=" * 70)
        self.stdout.write("                     RE-ENCRYPTION SUMMARY                  ")
        self.stdout.write("=" * 70)
        self.stdout.write(f"Total Fields Inspected      : {len(target_fields)}")
        self.stdout.write(f"Total Records Scanned       : {grand_total_scanned}")
        self.stdout.write(f"Already on Current Key      : {grand_total_current}")
        action_label = "Re-encrypted" if not dry_run else "Pending Re-encryption (dry-run)"
        self.stdout.write(f"{action_label:<28}: {grand_total_rotated}")
        self.stdout.write(f"Corrupt / Unrecoverable     : {grand_total_unrecoverable}")
        self.stdout.write("=" * 70)

        if dry_run and grand_total_rotated > 0:
            self.stdout.write(
                self.style.NOTICE("\nRun with '--confirm' to perform in-place database re-encryption.")
            )
        elif not dry_run:
            self.stdout.write(self.style.SUCCESS("\nAll legacy records successfully re-encrypted!"))
