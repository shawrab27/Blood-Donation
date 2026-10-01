# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
PostgreSQL test settings module for BloodPulse.
Used to run concurrency, PostGIS, and transaction-isolation tests
against a test Postgres instance (e.g. Neon branch).
"""

import os
import dj_database_url
from blood_pulse_backend.settings import *

test_db_url = os.environ.get('DATABASE_URL_TEST')
if not test_db_url:
    raise RuntimeError(
        "DATABASE_URL_TEST environment variable is not set. "
        "Provide a dedicated test/branch PostgreSQL URL to run the Postgres test suite."
    )

DATABASES = {
    'default': dj_database_url.parse(test_db_url, conn_max_age=0)
}
