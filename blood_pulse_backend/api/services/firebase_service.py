# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import json
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


def assemble_firebase_credentials_from_env() -> dict:
    """
    Assembles a Firebase service account credential dictionary from individual
    FIREBASE_SERVICE_ACCOUNT_* environment variables if present.
    Safely unescapes newline characters in private keys.
    Never exposes or logs secrets.
    """
    client_email = (
        os.environ.get('FIREBASE_SERVICE_ACCOUNT_CLIENT_EMAIL') or
        os.environ.get('FIREBASE_CLIENT_EMAIL')
    )
    private_key = (
        os.environ.get('FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY') or
        os.environ.get('FIREBASE_PRIVATE_KEY')
    )
    if not client_email or not private_key:
        return None

    clean_private_key = private_key.replace('\\n', '\n')
    project_id = (
        os.environ.get('FIREBASE_SERVICE_ACCOUNT_PROJECT_ID') or
        os.environ.get('FIREBASE_PROJECT_ID') or
        'bloodpulse-283dc'
    )
    private_key_id = os.environ.get('FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY_ID', '')
    client_id = os.environ.get('FIREBASE_SERVICE_ACCOUNT_CLIENT_ID', '')

    return {
        "type": "service_account",
        "project_id": project_id,
        "private_key_id": private_key_id,
        "private_key": clean_private_key,
        "client_email": client_email,
        "client_id": client_id,
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    }


def get_or_initialize_firebase_admin():
    """
    Initializes Firebase Admin SDK using credentials from:
    1. Assembled FIREBASE_SERVICE_ACCOUNT_* split environment variables
    2. Environment variables with JSON content (FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_CREDENTIALS_JSON)
    3. Environment variables pointing to certificate file path (FIREBASE_SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS)
    4. Default file at settings.BASE_DIR / firebase-service-account.json
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

        # 1. Assembled split variables
        assembled_dict = assemble_firebase_credentials_from_env()
        if assembled_dict:
            try:
                cred = credentials.Certificate(assembled_dict)
                logger.info("[FirebaseAdmin] Initialized from assembled FIREBASE_SERVICE_ACCOUNT_* environment variables.")
                return firebase_admin.initialize_app(cred, options=options)
            except Exception as asm_err:
                logger.error("[FirebaseAdmin] Failed to initialize from assembled env vars: %s", asm_err)

        # 2. Raw JSON string in environment variables
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
