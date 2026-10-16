# scripts/scan_secrets.py
# Safe secret scanner for git history and working tree
# Emits ONLY: commit_id | file_path | secret_type (never prints the secret value)

import os
import re
import subprocess
import sys

PATTERNS = [
    (r'-----BEGIN [A-Z ]*PRIVATE KEY-----', 'Private Key'),
    (r'(?i)postgres(?:ql)?:\/\/[^:]+:[^@]+@[^\s\'\"]+', 'PostgreSQL Connection URL with credentials'),
    (r'AIza[0-9A-Za-z\\-_]{35}', 'Google API Key / Firebase Token'),
    (r'xkeysib-[0-9a-f]{64}', 'Brevo API Key'),
    (r'AKIA[0-9A-Z]{16}', 'AWS Access Key'),
    (r'(?i)"type":\s*"service_account"', 'Google Service Account JSON'),
    (r'(?i)(?:api_key|secret_key|auth_token|access_token|password)\s*[:=]\s*[\'\"][^\'\"]{8,}[\'\"]', 'Hardcoded Secret / Token / Password'),
]

SECRET_FILES = [
    re.compile(r'(^|\/)\.env(\.[a-zA-Z0-9_-]+)?$'),
    re.compile(r'(^|\/)[^\/]+\.(jks|keystore|p12|pem)$'),
    re.compile(r'(^|\/)google-services\.json$'),
    re.compile(r'(^|\/)GoogleService-Info\.plist$'),
    re.compile(r'(^|\/)service-account.*\.json$'),
]

findings = []

def check_content(content, path, commit='WORKING_TREE'):
    for pattern, sec_type in PATTERNS:
        # Ignore dummy test values and comments
        matches = re.finditer(pattern, content)
        for m in matches:
            val = m.group(0)
            if any(dummy in val.lower() for dummy in ['dummy', 'mock', 'example', 'fake', 'test_key', 'test_password', 'changeme', 'your-']):
                continue
            findings.append((commit, path, sec_type))
            break # one per pattern per file/commit is enough

def scan_working_tree():
    for root, dirs, files in os.walk('.'):
        # Skip .git, venv, node_modules, build, .dart_tool
        dirs[:] = [d for d in dirs if d not in ['.git', 'venv', '.venv', 'node_modules', 'build', '.dart_tool', '.idea', '.vscode']]
        for f in files:
            p = os.path.normpath(os.path.join(root, f)).replace('\\', '/')
            for sf in SECRET_FILES:
                if sf.search(p):
                    findings.append(('WORKING_TREE', p, 'Sensitive File (' + f + ')'))
            # Check content of text files < 2MB
            full_p = os.path.join(root, f)
            try:
                if os.path.getsize(full_p) < 2 * 1024 * 1024:
                    with open(full_p, 'r', encoding='utf-8', errors='ignore') as fp:
                        check_content(fp.read(), p, 'WORKING_TREE')
            except Exception:
                pass

def scan_git_history():
    # 1. Check all committed file paths across all commits
    try:
        raw_paths = subprocess.check_output(
            ['git', 'log', '--all', '--pretty=format:COMMIT:%H', '--name-only'],
            text=True, encoding='utf-8', errors='ignore'
        )
        current_commit = 'UNKNOWN'
        for line in raw_paths.splitlines():
            line = line.strip()
            if not line:
                continue
            if line.startswith('COMMIT:'):
                current_commit = line.split(':', 1)[1]
            else:
                p = line.replace('\\', '/')
                for sf in SECRET_FILES:
                    if sf.search(p):
                        findings.append((current_commit[:10], p, 'Sensitive File (' + os.path.basename(p) + ')'))
    except Exception as e:
        print(f"Error checking git paths: {e}", file=sys.stderr)

    # 2. Check diff contents for secrets across commits
    try:
        # Run git log -p searching for high-risk tokens
        for pattern, sec_type in PATTERNS:
            out = subprocess.check_output(
                ['git', 'log', '--all', '-G', pattern, '--pretty=format:COMMIT:%H', '--name-only'],
                text=True, encoding='utf-8', errors='ignore'
            )
            current_commit = 'UNKNOWN'
            for line in out.splitlines():
                line = line.strip()
                if not line:
                    continue
                if line.startswith('COMMIT:'):
                    current_commit = line.split(':', 1)[1]
                else:
                    findings.append((current_commit[:10], line.replace('\\', '/'), sec_type))
    except Exception as e:
        # Some git regex might need simpler search
        pass

if __name__ == '__main__':
    scan_working_tree()
    scan_git_history()

    # Deduplicate findings
    unique = list(set(findings))
    unique.sort()

    print(f"Total findings: {len(unique)}")
    print(f"{'COMMIT':<12} | {'SECRET TYPE':<40} | {'FILE PATH'}")
    print("-" * 100)
    for commit, path, sec_type in unique:
        print(f"{commit:<12} | {sec_type:<40} | {path}")
