# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from urllib.parse import urlparse
import pytest
from django.conf import settings

BLOCKED_PROD_HOST = 'ep-proud-dew-b3hhg1ea.c-4.ap-southeast-1.aws.neon.tech'


def pytest_configure(config):
    """
    Critical safety hook: abort test execution immediately if any active
    database host points to the blocked production Neon database.
    """
    # 1. Check DATABASE_URL_DEV (rehearsal DB)
    dev_url = os.environ.get('DATABASE_URL_DEV', '')
    if dev_url and urlparse(dev_url).hostname == BLOCKED_PROD_HOST:
        pytest.exit(
            f"\n[CRITICAL SAFETY GUARD] Aborting: DATABASE_URL_DEV matches blocked production host: {BLOCKED_PROD_HOST}\n",
            returncode=1
        )

    # 2. Check active Django settings DATABASES
    if settings.configured and hasattr(settings, 'DATABASES'):
        for db_name, db_cfg in settings.DATABASES.items():
            db_host = db_cfg.get('HOST', '')
            if db_host == BLOCKED_PROD_HOST:
                pytest.exit(
                    f"\n[CRITICAL SAFETY GUARD] Aborting: DATABASES['{db_name}']['HOST'] points to blocked production host '{db_host}'!\n",
                    returncode=1
                )
