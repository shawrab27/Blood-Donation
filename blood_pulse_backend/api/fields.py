# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.


from django.db import models
from django.conf import settings
from cryptography.fernet import Fernet
import os

# KEY ROTATION STORY:
# If keys must be rotated, a MultiFernet instance can be used.
# You would provide a list of keys: the new key first, then the old key.
# Fernet will decrypt with whichever key works, and encrypt with the first key.
# To rotate:
# 1. Add the new key to the start of FIELD_ENCRYPTION_KEYS (or modify get_cipher to use MultiFernet).
# 2. Iterate over all DonorProfiles, triggering a re-save to re-encrypt with the new key.
# 3. Remove the old key.

def get_cipher():
    key = getattr(settings, 'FIELD_ENCRYPTION_KEY', None)
    if not key:
        raise ValueError('FIELD_ENCRYPTION_KEY must be set in settings to use EncryptedCharField')
    return Fernet(key.encode('utf-8'))

class EncryptedCharField(models.CharField):
    description = 'Encrypted string using Fernet symmetric encryption'

    def from_db_value(self, value, expression, connection):
        if value is None:
            return value
        if isinstance(value, memoryview):
            value = value.tobytes()
        if isinstance(value, str):
            value = value.encode('utf-8')
        try:
            return get_cipher().decrypt(value).decode('utf-8')
        except Exception:
            # If it fails, maybe it's raw data or old encryption
            if isinstance(value, bytes):
                try:
                    return value.decode('utf-8')
                except:
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
        if value.startswith('gAAAAA'):
            return value
        return get_cipher().encrypt(value.encode('utf-8')).decode('utf-8')

