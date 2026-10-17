# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


def get_or_initialize_firebase_admin():
    """
    Initializes Firebase Admin SDK using credentials from:
    1. Environment variables with JSON content (FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_CREDENTIALS_JSON)
    2. Environment variables pointing to certificate file path (FIREBASE_SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS)
    3. Default file at settings.BASE_DIR / firebase-service-account.json
    Never logs or prints secrets.
    """
    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.warning("firebase-admin not installed.")
        return None

    if not firebase_admin._apps:
        project_id = os.environ.get('FIREBASE_PROJECT_ID', 'bloodpulse-283dc')
        options = {'projectId': project_id}

        # 1. Raw JSON string in environment variables
        for env_var in [
            'FIREBASE_SERVICE_ACCOUNT_JSON',
            'FIREBASE_CREDENTIALS_JSON',
            'GOOGLE_APPLICATION_CREDENTIALS_JSON'
        ]:
            cred_json = os.environ.get(env_var)
            if cred_json:
                try:
                    cred_dict = json.loads(cred_json)
                    cred = credentials.Certificate(cred_dict)
                    logger.info("[FirebaseAdmin] Initialized from %s environment variable.", env_var)
                    return firebase_admin.initialize_app(cred, options=options)
                except Exception as parse_err:
                    logger.error("[FirebaseAdmin] Failed to parse %s: %s", env_var, parse_err)

        # 2. File paths in environment variables
        for path_var in [
            'FIREBASE_SERVICE_ACCOUNT_PATH',
            'FIREBASE_CREDENTIALS_PATH',
            'GOOGLE_APPLICATION_CREDENTIALS'
        ]:
            cred_path = os.environ.get(path_var)
            if cred_path and os.path.exists(cred_path):
                try:
                    cred = credentials.Certificate(cred_path)
                    logger.info("[FirebaseAdmin] Initialized from %s (%s).", path_var, cred_path)
                    return firebase_admin.initialize_app(cred, options=options)
                except Exception as path_err:
                    logger.error("[FirebaseAdmin] Failed to load certificate from %s: %s", path_var, path_err)

        # 3. Default file in backend root
        default_file = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
        if os.path.exists(default_file):
            try:
                cred = credentials.Certificate(default_file)
                logger.info("[FirebaseAdmin] Initialized from default file: %s.", default_file)
                return firebase_admin.initialize_app(cred, options=options)
            except Exception as def_err:
                logger.error("[FirebaseAdmin] Failed to load default certificate: %s", def_err)

        # 4. Fallback default initialization (ADC or testing)
        try:
            return firebase_admin.initialize_app(options=options)
        except Exception:
            pass

    if firebase_admin._apps:
        return firebase_admin.get_app()
    return None
