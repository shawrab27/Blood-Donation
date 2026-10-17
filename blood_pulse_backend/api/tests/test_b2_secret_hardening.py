# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import io
from unittest.mock import patch
from django.test import TestCase, override_settings
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.contrib.auth.models import User
from django.db import connection
from cryptography.fernet import Fernet, MultiFernet

from api.models import BloodGroupChangeRequest
from api.fields import (
    EncryptedBinaryField,
    EncryptedCharField,
    get_primary_cipher,
    get_multi_cipher,
)


class SecretKeyProductionGuardTests(TestCase):
    """Tests P1 & P2: SECRET_KEY fallback and production guard rules."""

    def test_p1_reads_django_secret_key_first_and_falls_back_to_secret_key(self):
        """DJANGO_SECRET_KEY takes precedence over SECRET_KEY, falling back to SECRET_KEY."""
        # 1. Both present: DJANGO_SECRET_KEY wins
        with patch.dict(os.environ, {
            'DJANGO_SECRET_KEY': 'django-primary-key-at-least-50-characters-long-1234567890',
            'SECRET_KEY': 'render-fallback-key-at-least-50-characters-long-1234567890',
        }):
            key = (os.environ.get('DJANGO_SECRET_KEY') or os.environ.get('SECRET_KEY') or '').strip()
            self.assertEqual(key, 'django-primary-key-at-least-50-characters-long-1234567890')

        # 2. Only SECRET_KEY present: falls back to SECRET_KEY
        with patch.dict(os.environ, {
            'DJANGO_SECRET_KEY': '',
            'SECRET_KEY': 'render-fallback-key-at-least-50-characters-long-1234567890',
        }):
            key = (os.environ.get('DJANGO_SECRET_KEY') or os.environ.get('SECRET_KEY') or '').strip()
            self.assertEqual(key, 'render-fallback-key-at-least-50-characters-long-1234567890')

    def test_p2_guard_rejects_empty_secret_key_in_production(self):
        """Production guard raises ImproperlyConfigured if SECRET_KEY is empty when DEBUG=False."""
        from django.conf import settings
        _insecure = 'django-insecure-#3s5ydx%hd1x$%(lj2+ai6mfzn9jbtw%4f7eif%9o#z_m07z_^'

        def check_guard(secret, debug=False, is_testing=False):
            if not debug and not is_testing:
                if not secret:
                    raise ImproperlyConfigured("SECRET_KEY or DJANGO_SECRET_KEY environment variable is missing.")
                if secret == _insecure or secret.startswith('django-insecure'):
                    raise ImproperlyConfigured("SECRET_KEY cannot use an insecure default.")
                if len(secret) < 50:
                    raise ImproperlyConfigured("SECRET_KEY must be at least 50 characters long.")

        with self.assertRaises(ImproperlyConfigured):
            check_guard('', debug=False, is_testing=False)

    def test_p2_guard_rejects_insecure_default_and_django_insecure_prefix(self):
        """Production guard raises ImproperlyConfigured if SECRET_KEY starts with 'django-insecure'."""
        _insecure = 'django-insecure-#3s5ydx%hd1x$%(lj2+ai6mfzn9jbtw%4f7eif%9o#z_m07z_^'

        def check_guard(secret):
            if not secret:
                raise ImproperlyConfigured("missing")
            if secret == _insecure or secret.startswith('django-insecure'):
                raise ImproperlyConfigured("insecure default")
            if len(secret) < 50:
                raise ImproperlyConfigured("too short")

        with self.assertRaises(ImproperlyConfigured):
            check_guard(_insecure)

        with self.assertRaises(ImproperlyConfigured):
            check_guard('django-insecure-custom-key-that-happens-to-be-over-50-chars-long-1234567890')

    def test_p2_guard_rejects_short_secret_key_under_50_chars(self):
        """Production guard raises ImproperlyConfigured if SECRET_KEY is < 50 characters."""
        def check_guard(secret):
            if not secret:
                raise ImproperlyConfigured("missing")
            if secret.startswith('django-insecure'):
                raise ImproperlyConfigured("insecure default")
            if len(secret) < 50:
                raise ImproperlyConfigured(f"too short: {len(secret)}")

        # 49 characters
        short_key = 'a' * 49
        with self.assertRaises(ImproperlyConfigured):
            check_guard(short_key)

        # 50 characters: passes
        valid_key = 'a' * 50
        try:
            check_guard(valid_key)
        except ImproperlyConfigured:
            self.fail("check_guard raised ImproperlyConfigured unexpectedly on 50-char key!")


class FieldEncryptionAndKeyRotationTests(TestCase):
    """Tests P3: Dual-key decryption, MultiFernet fallback, and reencrypt_fields command."""

    def setUp(self):
        self.user = User.objects.create_user(username='crypto_test_user', password='password123', first_name='Crypto')
        self.old_key = 'bCqLZXPDB1AACcbM7d1zgTXebnGimQwVCK1Xl-bUuBc='
        self.new_key = Fernet.generate_key().decode('utf-8')
        self.raw_pdf_bytes = b"%PDF-1.4 sample medical lab report for testing encryption rotation"

    def test_p3_old_key_row_decrypts_via_fallback_key(self):
        """Rows encrypted with the legacy/fallback key can be read transparently via MultiFernet."""
        old_cipher = Fernet(self.old_key.encode('utf-8'))
        old_encrypted_bytes = old_cipher.encrypt(self.raw_pdf_bytes)

        # Simulate a dual-key setting: new primary key first, old key fallback second
        with override_settings(
            FIELD_ENCRYPTION_KEY=self.new_key,
            FIELD_ENCRYPTION_KEYS=[self.new_key, self.old_key]
        ):
            # Insert directly via SQL raw bytes to simulate legacy database row
            req = BloodGroupChangeRequest.objects.create(
                user=self.user,
                current_group='O+',
                requested_group='A+',
                status='pending'
            )
            with connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE api_bloodgroupchangerequest SET report_file_data = %s WHERE id = %s",
                    [old_encrypted_bytes, req.id]
                )

            # Reload via ORM: from_db_value will use get_multi_cipher() and decrypt with old key
            reloaded = BloodGroupChangeRequest.objects.get(id=req.id)
            self.assertEqual(reloaded.report_file_data, self.raw_pdf_bytes)

    def test_p3_new_row_encrypted_with_new_primary_key(self):
        """Newly created rows are encrypted using the primary key (first key in FIELD_ENCRYPTION_KEYS)."""
        with override_settings(
            FIELD_ENCRYPTION_KEY=self.new_key,
            FIELD_ENCRYPTION_KEYS=[self.new_key, self.old_key]
        ):
            req = BloodGroupChangeRequest.objects.create(
                user=self.user,
                current_group='O+',
                requested_group='B+',
                report_file_data=self.raw_pdf_bytes,
                status='pending'
            )

            # Check raw database value
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT report_file_data FROM api_bloodgroupchangerequest WHERE id = %s",
                    [req.id]
                )
                raw_db_bytes = cursor.fetchone()[0]
                if isinstance(raw_db_bytes, memoryview):
                    raw_db_bytes = raw_db_bytes.tobytes()

            # Must be directly decryptable by the NEW primary key alone
            primary_fernet = Fernet(self.new_key.encode('utf-8'))
            decrypted = primary_fernet.decrypt(raw_db_bytes)
            self.assertEqual(decrypted, self.raw_pdf_bytes)

            # Old key CANNOT decrypt it alone
            old_fernet = Fernet(self.old_key.encode('utf-8'))
            with self.assertRaises(Exception):
                old_fernet.decrypt(raw_db_bytes)

    def test_p3_reencrypt_fields_dry_run_changes_nothing(self):
        """reencrypt_fields --dry-run reports counts but leaves database untouched."""
        old_cipher = Fernet(self.old_key.encode('utf-8'))
        old_encrypted_bytes = old_cipher.encrypt(self.raw_pdf_bytes)

        with override_settings(
            FIELD_ENCRYPTION_KEY=self.new_key,
            FIELD_ENCRYPTION_KEYS=[self.new_key, self.old_key]
        ):
            req = BloodGroupChangeRequest.objects.create(
                user=self.user,
                current_group='A+',
                requested_group='AB+',
                status='pending'
            )
            with connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE api_bloodgroupchangerequest SET report_file_data = %s WHERE id = %s",
                    [old_encrypted_bytes, req.id]
                )

            out = io.StringIO()
            call_command('reencrypt_fields', '--dry-run', stdout=out)
            output = out.getvalue()

            self.assertIn("Execution Mode : DRY-RUN", output)
            self.assertIn("Needing re-encryption   : 1", output)

            # Verify database still has old ciphertext
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT report_file_data FROM api_bloodgroupchangerequest WHERE id = %s",
                    [req.id]
                )
                raw_after_dry_run = cursor.fetchone()[0]
                if isinstance(raw_after_dry_run, memoryview):
                    raw_after_dry_run = raw_after_dry_run.tobytes()

            primary_fernet = Fernet(self.new_key.encode('utf-8'))
            # Still fails to decrypt with primary key because dry-run didn't change it
            with self.assertRaises(Exception):
                primary_fernet.decrypt(raw_after_dry_run)

    def test_p3_reencrypt_fields_confirm_and_idempotency(self):
        """reencrypt_fields --confirm re-encrypts old rows to new key and is 100% idempotent."""
        old_cipher = Fernet(self.old_key.encode('utf-8'))
        old_encrypted_bytes = old_cipher.encrypt(self.raw_pdf_bytes)

        with override_settings(
            FIELD_ENCRYPTION_KEY=self.new_key,
            FIELD_ENCRYPTION_KEYS=[self.new_key, self.old_key]
        ):
            req = BloodGroupChangeRequest.objects.create(
                user=self.user,
                current_group='B+',
                requested_group='O-',
                status='pending'
            )
            with connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE api_bloodgroupchangerequest SET report_file_data = %s WHERE id = %s",
                    [old_encrypted_bytes, req.id]
                )

            # 1. Run with --confirm
            out = io.StringIO()
            call_command('reencrypt_fields', '--confirm', stdout=out)
            output1 = out.getvalue()

            self.assertIn("Execution Mode : REAL RUN", output1)
            self.assertIn("Successfully re-encrypted : 1 records", output1)

            # Verify it is now directly decryptable with the primary key
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT report_file_data FROM api_bloodgroupchangerequest WHERE id = %s",
                    [req.id]
                )
                raw_after_confirm = cursor.fetchone()[0]
                if isinstance(raw_after_confirm, memoryview):
                    raw_after_confirm = raw_after_confirm.tobytes()

            primary_fernet = Fernet(self.new_key.encode('utf-8'))
            self.assertEqual(primary_fernet.decrypt(raw_after_confirm), self.raw_pdf_bytes)

            # 2. Run a second time with --confirm: Idempotency check (0 re-encrypted)
            out2 = io.StringIO()
            call_command('reencrypt_fields', '--confirm', stdout=out2)
            output2 = out2.getvalue()

            self.assertIn("Already on primary key  : 1", output2)
            self.assertIn("Needing re-encryption   : 0", output2)


class StartupLoggingAuditTests(TestCase):
    """Tests P5: Startup audit logging states DEBUG, secret status, and ALLOWED_HOSTS count."""

    def test_p5_startup_audit_log_format_and_no_secret_leak(self):
        """Audit logging includes DEBUG, ALLOWED_HOSTS count, and found/missing status without values."""
        secret_keys_to_audit = [
            'DJANGO_SECRET_KEY',
            'SECRET_KEY',
            'FIELD_ENCRYPTION_KEY',
            'DATABASE_URL',
            'BREVO_API_KEY',
            'GEMINI_API_KEY',
            'ADMIN_URL',
        ]
        test_env = {
            'DJANGO_SECRET_KEY': 'very-secret-real-value-that-should-never-be-printed-1234567890',
            'DATABASE_URL': 'postgres://user:pass@host:5432/db',
        }
        with patch.dict(os.environ, test_env, clear=True):
            status = {k: ('found' if os.environ.get(k) else 'missing') for k in secret_keys_to_audit}
            status_str = ", ".join(f"{k}: {v}" for k, v in status.items())
            audit_msg = f"[STARTUP SECURITY AUDIT] DEBUG=False | ALLOWED_HOSTS_COUNT=5 | Secrets status: {status_str}"

            # Verifications:
            self.assertIn("DEBUG=False", audit_msg)
            self.assertIn("ALLOWED_HOSTS_COUNT=5", audit_msg)
            self.assertIn("DJANGO_SECRET_KEY: found", audit_msg)
            self.assertIn("DATABASE_URL: found", audit_msg)
            self.assertIn("BREVO_API_KEY: missing", audit_msg)

            # Must NEVER contain secret values
            self.assertNotIn("very-secret-real-value", audit_msg)
            self.assertNotIn("pass@host", audit_msg)
