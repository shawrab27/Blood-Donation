# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Safe settings module for BloodPulse.
Guards against accidental execution of destructive or stateful commands
against the production database (Neon).
"""

import os
import sys
from urllib.parse import urlparse
from dotenv import dotenv_values

# For automated tests or local management commands where no secret key is in .env:
if any(cmd in sys.argv for cmd in ('test', 'check', 'makemigrations', 'showmigrations', 'sqlmigrate', 'reencrypt_fields')):
    os.environ.setdefault('BLOODPULSE_ALLOW_TEST_KEYS', '1')
    if not os.environ.get('DJANGO_SECRET_KEY') and not os.environ.get('SECRET_KEY'):
        os.environ['DJANGO_SECRET_KEY'] = 'bloodpulse-automated-test-suite-secure-key-50-chars-0001abcdefghij'
    if not os.environ.get('FIELD_ENCRYPTION_KEY') and not os.environ.get('DJANGO_FIELD_ENCRYPTION_KEY'):
        os.environ['FIELD_ENCRYPTION_KEY'] = 'bCqLZXPDB1AACcbM7d1zgTXebnGimQwVCK1Xl-bUuBc='

# First, import all base settings
from blood_pulse_backend.settings import *

# Identify production database host from .env
_prod_env_path = BASE_DIR / '.env'
_prod_env_vals = dotenv_values(_prod_env_path) if _prod_env_path.exists() else {}
_prod_db_url = _prod_env_vals.get('PROD_DATABASE_URL', '') or _prod_env_vals.get('DATABASE_URL', '') or os.environ.get('PROD_DATABASE_URL', '')
_prod_host = urlparse(_prod_db_url).hostname if _prod_db_url else None


def verify_postgres_test_db_guard(test_db_url: str | None, prod_db_url: str | None) -> bool:
    """
    Safety guard for Postgres test runs (Part 0):
    Refuses to start and prints a clear message if:
    1) DATABASE_URL_TEST is missing,
    2) DATABASE_URL_TEST equals DATABASE_URL, or
    3) DATABASE_URL_TEST host matches the production host.
    Never prints the raw connection URLs or credentials.
    """
    clean_test = (test_db_url or '').strip()
    clean_prod = (prod_db_url or '').strip()

    if not clean_test:
        msg = (
            "REFUSING TO START POSTGRES TEST RUN: DATABASE_URL_TEST is missing. "
            "Set a dedicated non-production DATABASE_URL_TEST in your local .env."
        )
        sys.stderr.write(
            f"\n======================================================================\n"
            f"[POSTGRES TEST SAFETY GUARD TRIGGERED]\n{msg}\n"
            f"======================================================================\n\n"
        )
        raise RuntimeError(msg)

    if clean_prod and clean_test == clean_prod:
        msg = (
            "REFUSING TO START POSTGRES TEST RUN: DATABASE_URL_TEST is identical to DATABASE_URL. "
            "Never point DATABASE_URL_TEST at the production database."
        )
        sys.stderr.write(
            f"\n======================================================================\n"
            f"[POSTGRES TEST SAFETY GUARD TRIGGERED]\n{msg}\n"
            f"======================================================================\n\n"
        )
        raise RuntimeError(msg)

    parsed_test = urlparse(clean_test)
    if parsed_test.scheme not in ('postgres', 'postgresql', 'pgsql'):
        msg = "REFUSING TO START POSTGRES TEST RUN: DATABASE_URL_TEST must be a PostgreSQL URL."
        sys.stderr.write(
            f"\n======================================================================\n"
            f"[POSTGRES TEST SAFETY GUARD TRIGGERED]\n{msg}\n"
            f"======================================================================\n\n"
        )
        raise RuntimeError(msg)

    test_host = parsed_test.hostname
    prod_host = urlparse(clean_prod).hostname if clean_prod else None
    if prod_host and test_host and test_host.lower() == prod_host.lower():
        msg = (
            "REFUSING TO START POSTGRES TEST RUN: DATABASE_URL_TEST host matches the production host. "
            "Use an isolated test Postgres instance with a different host."
        )
        sys.stderr.write(
            f"\n======================================================================\n"
            f"[POSTGRES TEST SAFETY GUARD TRIGGERED]\n{msg}\n"
            f"======================================================================\n\n"
        )
        raise RuntimeError(msg)

    return True


if os.environ.get('USE_TEST_POSTGRES') == '1' or 'test' in sys.argv:
    _test_db_url = os.environ.get('DATABASE_URL_TEST') or _prod_env_vals.get('DATABASE_URL_TEST', '')
    if _test_db_url:
        try:
            verify_postgres_test_db_guard(_test_db_url, _prod_db_url)
            DATABASES['default'] = dj_database_url.parse(_test_db_url, conn_max_age=0)
        except RuntimeError:
            sys.exit(1)


# Identify current configured default database host
_current_db = DATABASES.get('default', {})
_current_host = _current_db.get('HOST', '')

# Strictly ALLOWED commands when target DB host is production
ALLOWED_PROD_COMMANDS = {'check', 'showmigrations', 'sqlmigrate', 'help', 'version', 'reencrypt_fields'}


def _check_production_guard():
    command = None
    for arg in sys.argv[1:]:
        if not arg.startswith('-'):
            command = arg
            break

    # If no command passed (e.g. `python manage.py`), allow
    if not command:
        return

    # Evaluate allowlist
    is_allowed = False
    if command in ALLOWED_PROD_COMMANDS:
        is_allowed = True
    elif command == 'makemigrations':
        # Only allowed on production host when --dry-run is explicitly specified
        if '--dry-run' in sys.argv:
            is_allowed = True
        else:
            is_allowed = False
    else:
        is_allowed = False

    if _prod_host and _current_host and _current_host == _prod_host:
        if not is_allowed and os.environ.get('ALLOW_PROD') != '1':
            error_msg = (
                f"\n{'='*70}\n"
                f"[PRODUCTION SAFETY GUARD TRIGGERED]\n"
                f"REFUSING to execute '{command}'!\n"
                f"Target database host '{_current_host}' matches production host in .env.\n"
                f"ALLOWLIST ONLY on production: check, showmigrations, sqlmigrate, makemigrations (--dry-run), help, version.\n"
                f"Command '{command}' is NOT in allowlist.\n"
                f"To override this guard for production maintenance, explicitly set:\n"
                f"    ALLOW_PROD=1\n"
                f"{'='*70}\n\n"
            )
            sys.stderr.write(error_msg)
            sys.exit(1)


if os.environ.get('DJANGO_SETTINGS_MODULE') == 'blood_pulse_backend.safe_settings':
    _check_production_guard()

