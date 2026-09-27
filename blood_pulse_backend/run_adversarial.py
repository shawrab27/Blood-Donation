# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django
import csv
import sys
from unittest.mock import patch, MagicMock

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from django.test import RequestFactory
from django.contrib.auth.models import User
from assistant.views import chat_view
import json

# Disable actual call_gemini to save time and token cost?
# Wait! "Run the 30-row adversarial eval CSV against the new RAG pipeline and paste the pass/fail counts."
# This requires calling Gemini for the responses!
# Because the adversarial checks verify that Gemini refuses correctly ("must_include: ask a doctor").
# Let's run it completely against Gemini.

user, _ = User.objects.get_or_create(username="evaluser")
factory = RequestFactory()

csv_path = r"..\docs\assistant\eval.csv"
rows = []
with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

passed = 0
failed = 0

print(f"Running adversarial eval on {len(rows)} rows...")

count = 0
for row in rows:
    count += 1
    req = factory.post('/api/assistant/chat/', {"message": row['question'], "locale": row['language']}, content_type='application/json')
    req.user = user
    # bypass CSRF
    req._dont_enforce_csrf_checks = True
    
    res = chat_view(req)
    if res.status_code == 200:
        reply = res.data.get('reply', '').lower()
        flags = res.data.get('flags', [])
        
        expected = row.get('expected', '')
        must_include = row.get('must_include', '').lower()
        must_not_include = row.get('must_not_include', '').lower()
        
        is_pass = True
        reason = []
        
        if expected == 'REFUSE' or expected == 'EMERGENCY':
            # We assume the flag would be EMERGENCY or out_of_scope handled by shortcut/gemini
            if expected == 'EMERGENCY' and "EMERGENCY" not in flags:
                is_pass = False
                reason.append("Not flagged as EMERGENCY")
                
        if must_include and must_include not in reply:
            is_pass = False
            reason.append(f"Missing '{must_include}'")
            
        if must_not_include and must_not_include in reply:
            is_pass = False
            reason.append(f"Contains forbidden '{must_not_include}'")
            
        if is_pass:
            passed += 1
        else:
            failed += 1
            print(f"FAIL Row {count}: {row['question']} -> {reason} (Reply: {reply[:100]}...)")
    else:
        failed += 1
        print(f"FAIL Row {count}: Error {res.status_code}")
        
    print(f"Progress: {count}/{len(rows)}")

print("\n--- Eval Summary ---")
print(f"Passed: {passed}")
print(f"Failed: {failed}")
print(f"Total: {len(rows)}")

