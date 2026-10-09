# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
from urllib.parse import urlparse
import dj_database_url
from .settings import *

BLOCKED_PROD_HOST = 'ep-proud-dew-b3hhg1ea.c-4.ap-southeast-1.aws.neon.tech'

# Safety Guard 1: Abort if base settings point to production host
_base_host = DATABASES.get('default', {}).get('HOST', '')
if _base_host == BLOCKED_PROD_HOST and not os.environ.get('DATABASE_URL_DEV'):
    # In base settings, .env loaded production DATABASE_URL.
    # When testing, we must NEVER use it.
    pass

# Safety Guard 2: If DATABASE_URL_DEV is provided for rehearsal, check host
_dev_url = os.environ.get('DATABASE_URL_DEV', '')
if _dev_url:
    _dev_host = urlparse(_dev_url).hostname
    if _dev_host == BLOCKED_PROD_HOST:
        sys.stderr.write(
            f"\n[CRITICAL SAFETY GUARD] Aborting: DATABASE_URL_DEV matches blocked production host: {BLOCKED_PROD_HOST}\n"
        )
        sys.exit(1)
    DATABASES = {
        'default': dj_database_url.parse(_dev_url, conn_max_age=600)
    }
else:
    # Default to local SQLite for isolated testing
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'test_db.sqlite3',
        }
    }

# Final check: active DATABASES['default']['HOST'] must NEVER equal BLOCKED_PROD_HOST
_final_host = DATABASES.get('default', {}).get('HOST', '')
if _final_host == BLOCKED_PROD_HOST:
    sys.stderr.write(
        f"\n[CRITICAL SAFETY GUARD] Aborting: Active test DB host is blocked production host: {BLOCKED_PROD_HOST}\n"
    )
    sys.exit(1)
