# scripts/scan_backend_secrets.py
# Scans settings.py, urls.py, and all backend modules for hard-coded secrets,
# fallback keys, default passwords, or insecure defaults.
# Prints only file path, line number, and secret TYPE. Never prints secret values.

import os
import re

PATTERNS = [
    (re.compile(r'django-insecure-[^\s\'\"]+'), 'Django Insecure Secret Key Fallback'),
    (re.compile(r'bCqLZXPDB1AACcbM7d1zgTXebnGimQwVCK1Xl-bUuBc='), 'Hardcoded Fernet Fallback Key'),
    (re.compile(r'(?i)secret_key\s*=\s*[\'\"][^\'\"]+[\'\"]'), 'Hardcoded Secret Key'),
    (re.compile(r'(?i)signing_key\s*=\s*[\'\"][^\'\"]+[\'\"]'), 'Hardcoded JWT Signing Key'),
    (re.compile(r'(?i)password\s*=\s*[\'\"][^\'\"]{6,}[\'\"]'), 'Hardcoded Password'),
    (re.compile(r'AIza[0-9A-Za-z\\-_]{35}'), 'Google / Firebase API Key'),
    (re.compile(r'xkeysib-[0-9a-f]{64}'), 'Brevo API Key'),
]

IGNORE_DIRS = {'venv', '.venv', '__pycache__', '.git', 'staticfiles', 'node_modules'}
IGNORE_PATTERNS = {'dummy', 'mock', 'example', 'fake', 'test_key', 'test_password', 'changeme', 'your-', 'pass', 'test'}

def scan():
    findings = []
    for root, dirs, files in os.walk('blood_pulse_backend'):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for f in files:
            if not f.endswith('.py'):
                continue
            p = os.path.normpath(os.path.join(root, f)).replace('\\', '/')
            with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                for idx, line in enumerate(fp, 1):
                    # Skip comments or test files if they are just defining test assertions/fixtures
                    clean_line = line.strip()
                    if clean_line.startswith('#'):
                        continue
                    for pat, stype in PATTERNS:
                        m = pat.search(line)
                        if m:
                            matched = m.group(0).lower()
                            # If it's a test file using dummy password like 'pass' or 'test', skip
                            if '/tests/' in p or f.startswith('test_') or f.endswith('_test.py'):
                                if any(ign in matched for ign in ['pass', 'test', 'password', 'dummy']):
                                    continue
                            findings.append((p, idx, stype))
    return findings

if __name__ == '__main__':
    results = scan()
    print(f"Total findings: {len(results)}")
    print(f"{'FILE PATH':<65} | {'LINE':<6} | {'SECRET TYPE'}")
    print("-" * 105)
    for path, line, stype in sorted(results):
        print(f"{path:<65} | {line:<6} | {stype}")
