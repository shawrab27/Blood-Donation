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

# First, import all base settings
from blood_pulse_backend.settings import *

# Identify production database host from .env
_prod_env_path = BASE_DIR / '.env'
_prod_host = None
if _prod_env_path.exists():
    _prod_env_vals = dotenv_values(_prod_env_path)
    _prod_db_url = _prod_env_vals.get('DATABASE_URL', '')
    if _prod_db_url:
        _prod_host = urlparse(_prod_db_url).hostname

# Identify current configured default database host
_current_db = DATABASES.get('default', {})
_current_host = _current_db.get('HOST', '')

# Strictly ALLOWED commands when target DB host is production
ALLOWED_PROD_COMMANDS = {'check', 'showmigrations', 'sqlmigrate', 'help', 'version'}


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


_check_production_guard()
