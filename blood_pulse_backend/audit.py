# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys

def check_security():
    print("--- SECURITY ---")
    
    # Check settings.py
    with open('blood_pulse_backend/settings.py', 'r', encoding='utf-8') as f:
        settings_code = f.read()
    
    if "SECURE_SSL_REDIRECT" in settings_code:
        print("SECURE_SSL_REDIRECT found in settings.py")
    else:
        print("SECURE_SSL_REDIRECT NOT found in settings.py")
        
    if "REST_FRAMEWORK" in settings_code and "DEFAULT_THROTTLE_CLASSES" in settings_code:
        print("DEFAULT_THROTTLE_CLASSES found in settings.py")
    else:
        print("DEFAULT_THROTTLE_CLASSES NOT found in settings.py")
        
    if "ACCESS_TOKEN_LIFETIME" in settings_code:
        print("ACCESS_TOKEN_LIFETIME found in settings.py")
    else:
        print("ACCESS_TOKEN_LIFETIME NOT found in settings.py")
        
    if "PASSWORD_HASHERS" in settings_code and "Argon2" in settings_code:
        print("Argon2 PASSWORD_HASHERS found in settings.py")
    else:
        print("Argon2 PASSWORD_HASHERS NOT found in settings.py")

    # Check NID in models
    with open('api/models.py', 'r', encoding='utf-8') as f:
        models_code = f.read()
    
    if "encrypted_nid" in models_code.lower() or "encrypt" in models_code.lower():
        print("NID Encryption logic found in models.py")
    else:
        print("NID Encryption logic NOT found in models.py")
        
    # Check AuditLog
    print("AuditLog exists in api/models.py:", "AuditLog" in models_code)
    
check_security()
