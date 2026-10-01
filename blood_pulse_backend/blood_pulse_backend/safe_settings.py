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

# Commands strictly forbidden on production host without ALLOW_PROD=1
BLOCKED_PROD_COMMANDS = {'migrate', 'runserver', 'test', 'flush', 'loaddata'}


def _check_production_guard():
    command = None
    for arg in sys.argv[1:]:
        if not arg.startswith('-'):
            command = arg
            break

    is_blocked = False
    if command:
        if command in BLOCKED_PROD_COMMANDS or command.startswith('import_'):
            is_blocked = True

    if _prod_host and _current_host and _current_host == _prod_host:
        if is_blocked and os.environ.get('ALLOW_PROD') != '1':
            error_msg = (
                f"\n{'='*70}\n"
                f"[PRODUCTION SAFETY GUARD TRIGGERED]\n"
                f"REFUSING to execute '{command}'!\n"
                f"Target database host '{_current_host}' matches production host in .env.\n"
                f"Blocked commands: {', '.join(sorted(BLOCKED_PROD_COMMANDS))}, import_*\n"
                f"To override this guard for production maintenance, explicitly set:\n"
                f"    ALLOW_PROD=1\n"
                f"{'='*70}\n\n"
            )
            sys.stderr.write(error_msg)
            sys.exit(1)


_check_production_guard()
