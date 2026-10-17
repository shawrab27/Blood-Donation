# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.db import models
from django.conf import settings
from cryptography.fernet import Fernet, MultiFernet
import os

def get_multi_cipher() -> MultiFernet:
    """
    Returns a MultiFernet instance containing:
    1. Primary key (index 0) - used for all new encryptions and decryptions.
    2. Fallback key(s) (index 1+) - used as DECRYPT-ONLY fallback for old rows.
    """
    keys = getattr(settings, 'FIELD_ENCRYPTION_KEYS', None)
    if not keys:
        single = getattr(settings, 'FIELD_ENCRYPTION_KEY', None)
        keys = [single] if single else []

    if not keys:
        raise ValueError('FIELD_ENCRYPTION_KEY or FIELD_ENCRYPTION_KEYS must be set in settings to use encrypted fields.')

    fernets = []
    for k in keys:
        if isinstance(k, str):
            k = k.encode('utf-8')
        fernets.append(Fernet(k))
    return MultiFernet(fernets)


def get_primary_cipher() -> Fernet:
    """Returns the primary Fernet cipher (first key in FIELD_ENCRYPTION_KEYS)."""
    keys = getattr(settings, 'FIELD_ENCRYPTION_KEYS', None)
    key = keys[0] if keys else getattr(settings, 'FIELD_ENCRYPTION_KEY', None)
    if not key:
        raise ValueError('FIELD_ENCRYPTION_KEY must be set in settings.')
    if isinstance(key, str):
        key = key.encode('utf-8')
    return Fernet(key)


def get_cipher():
    """Backwards compatibility alias for get_multi_cipher."""
    return get_multi_cipher()


class EncryptedCharField(models.CharField):
    description = 'Encrypted string using Fernet symmetric encryption with MultiFernet fallback'

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        if isinstance(value, memoryview):
            value = value.tobytes()
        if isinstance(value, str):
            value = value.encode('utf-8')
        try:
            return get_multi_cipher().decrypt(value).decode('utf-8')
        except Exception:
            if isinstance(value, bytes):
                try:
                    return value.decode('utf-8')
                except Exception:
                    return '[Unrecoverable Old Encrypted Data]'
            return str(value)

    def to_python(self, value):
        if isinstance(value, str) or value is None:
            return value
        return str(value)

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None or value == '':
            return value
        val_bytes = value.encode('utf-8') if isinstance(value, str) else value
        try:
            # Check if value is already a valid Fernet token under our multi-cipher
            get_multi_cipher().decrypt(val_bytes)
            try:
                # If already encrypted with the primary key, return unchanged
                get_primary_cipher().decrypt(val_bytes)
                return value
            except Exception:
                # If encrypted with an old fallback key, rotate to primary key
                return get_multi_cipher().rotate(val_bytes).decode('utf-8')
        except Exception:
            # Plaintext data: encrypt with primary key
            return get_multi_cipher().encrypt(val_bytes).decode('utf-8')


class EncryptedBinaryField(models.BinaryField):
    """
    Encrypts raw bytes using Fernet symmetric encryption before storing in the database.
    Decrypts automatically when loaded from the database.
    Supports MultiFernet key rotation: decrypts with fallback keys, encrypts with primary key.
    """
    description = 'Encrypted binary data using Fernet symmetric encryption with MultiFernet fallback'

    def from_db_value(self, value, expression, connection):
        if value is None:
            return None
        if isinstance(value, memoryview):
            value = value.tobytes()
        try:
            return get_multi_cipher().decrypt(value)
        except Exception:
            return value

    def to_python(self, value):
        if value is None:
            return None
        if isinstance(value, memoryview):
            return value.tobytes()
        return value

    def get_prep_value(self, value):
        if value is None:
            return None
        if isinstance(value, memoryview):
            value = value.tobytes()
        if isinstance(value, bytes):
            try:
                # Check if already a valid Fernet token under multi-cipher
                get_multi_cipher().decrypt(value)
                try:
                    # If already encrypted with primary key, preserve as-is
                    get_primary_cipher().decrypt(value)
                    return value
                except Exception:
                    # If encrypted with old fallback key, rotate to primary key
                    return get_multi_cipher().rotate(value)
            except Exception:
                # Plaintext binary data: encrypt with primary key
                return get_multi_cipher().encrypt(value)
        return value
