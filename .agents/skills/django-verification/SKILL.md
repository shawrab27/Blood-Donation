---
name: django-verification
description: Full Django verification loop — environment check, linting (ruff/black/mypy), migration safety, pytest test suites with coverage, pip-audit and bandit security scans, settings and diff review. Sourced from ECC. Use when preparing a Django pull request, validating migrations, or running pre-deploy readiness checks.
metadata:
  origin: ECC
  version: "1.0.0"
---

# Django Verification Loop

Run before opening PRs, after model modifications, and pre-deployment to ensure BloodPulse Django backend stability, migration integrity, and security compliance.

## When to Activate

- Before opening or merging a PR touching `blood_pulse_backend/`.
- After modifying any Django model or database schema.
- Verifying migration safety (`showmigrations`, `makemigrations --check`).
- Running test suites with pytest and checking test coverage.
- Running dependency vulnerability scans (`pip-audit`) and security checks (`bandit`).

---

## 1. Phase 1: Environment & Settings Check

```bash
# Verify Python version and environment
python --version

# Check virtual environment
which python

# Check Django configuration
python manage.py check

# Run deployment check
python manage.py check --deploy
```

---

## 2. Phase 2: Migration Safety Check

Never deploy with uncreated or conflicting migrations:

```bash
# 1. Verify no model changes were left unmigrated
python manage.py makemigrations --check --dry-run

# 2. View all migration statuses
python manage.py showmigrations

# 3. Plan migration execution
python manage.py migrate --plan

# 4. Check for migration merge conflicts
python manage.py makemigrations --merge --dry-run
```

---

## 3. Phase 3: Code Quality & Linting

```bash
# Format check with black or ruff
ruff check .
black --check .

# Type checking (if mypy configured)
mypy api/
```

---

## 4. Phase 4: Test Suite & Coverage

```bash
# Run pytest with coverage
pytest --cov=api --cov-report=term-missing

# Run specific app tests
pytest api/tests/
```

### Coverage Targets:
- **Models**: 90%+
- **Serializers**: 85%+
- **Views / ViewSets**: 80%+
- **Overall**: 80%+

---

## 5. Phase 5: Security Scanning

```bash
# Check dependencies for known CVEs
pip-audit

# Run Bandit security linter
bandit -r api/ blood_pulse_backend/

# Ensure DEBUG is not hardcoded True
python -c "from blood_pulse_backend import settings; print('DEBUG is', settings.DEBUG)"
```

---

## 6. Pre-Deployment Verification Report Checklist

| Check | Command | Pass Criteria |
| :--- | :--- | :--- |
| **Model State** | `makemigrations --check` | "No changes detected" |
| **Deploy Settings** | `manage.py check --deploy` | 0 Critical errors |
| **Test Suite** | `pytest` | All tests pass, 0 failures |
| **Security Audit** | `pip-audit` | 0 vulnerable packages |
| **Secrets Scan** | `git diff` review | No hardcoded API keys or secrets |
