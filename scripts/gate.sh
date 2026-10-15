#!/usr/bin/env bash
# scripts/gate.sh - Cross-platform Safety Gate Script for BloodPulse
# Runs: flutter analyze, flutter test, manage.py check, makemigrations --check, manage.py test.
# Enforces zero regressions; validates expected failures against docs/known_failures.txt.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
KNOWN_FAILURES_FILE="$DOCS_DIR/known_failures.txt"
FLUTTER_DIR="$REPO_ROOT/blood_pulse"
BACKEND_DIR="$REPO_ROOT/blood_pulse_backend"

if [ -f "$REPO_ROOT/venv/bin/python" ]; then
    PYTHON_BIN="$REPO_ROOT/venv/bin/python"
elif [ -f "$REPO_ROOT/venv/Scripts/python.exe" ]; then
    PYTHON_BIN="$REPO_ROOT/venv/Scripts/python.exe"
else
    PYTHON_BIN="python3"
fi

echo "=========================================================="
echo "          BLOODPULSE QUALITY & SAFETY GATE SCRIPT          "
echo "=========================================================="
echo "Repository Root : $REPO_ROOT"
echo "Python Binary   : $PYTHON_BIN"
echo "Known Failures  : $KNOWN_FAILURES_FILE"
echo ""

OVERALL_SUCCESS=true

# 1. flutter analyze
echo "[1/5] Running: flutter analyze..."
cd "$FLUTTER_DIR"
if flutter analyze; then
    echo "STEP 1: flutter analyze -> PASS"
else
    echo "STEP 1: flutter analyze -> FAIL"
    OVERALL_SUCCESS=false
fi
echo ""

# 2. flutter test
echo "[2/5] Running: flutter test..."
cd "$FLUTTER_DIR"
TEST_OUTPUT=$(flutter test 2>&1 || true)
echo "$TEST_OUTPUT" | tail -n 25

if echo "$TEST_OUTPUT" | grep -q "All tests passed!"; then
    echo "STEP 2: flutter test -> PASS"
else
    # Check if failing tests are in known_failures.txt
    FAILURES=$(echo "$TEST_OUTPUT" | awk '/Failing tests:/{flag=1;next}/^$/{flag=0}flag')
    UNEXPECTED=false
    while IFS= read -r line; do
        TRIMMED=$(echo "$line" | sed 's/^[ \t]*//')
        if [ -n "$TRIMMED" ]; then
            MATCHED=false
            while IFS= read -r k; do
                k_clean=$(echo "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                [ -z "$k_clean" ] && continue
                [[ "$k_clean" =~ ^# ]] && continue
                if [[ "$TRIMMED" == *"$k_clean"* ]]; then
                    MATCHED=true
                    break
                fi
            done < "$KNOWN_FAILURES_FILE"

            if [ "$MATCHED" = true ]; then
                echo "  [KNOWN] $TRIMMED"
            else
                echo "  [UNEXPECTED] $TRIMMED"
                UNEXPECTED=true
            fi
        fi
    done <<< "$FAILURES"

    if [ "$UNEXPECTED" = false ] && [ -n "$FAILURES" ]; then
        echo "STEP 2: flutter test -> PASS (Known Baseline Failures Allowed)"
    else
        echo "STEP 2: flutter test -> FAIL"
        OVERALL_SUCCESS=false
    fi
fi
echo ""

# 3. manage.py check
echo "[3/5] Running: python manage.py check..."
cd "$BACKEND_DIR"
if "$PYTHON_BIN" manage.py check; then
    echo "STEP 3: manage.py check -> PASS"
else
    echo "STEP 3: manage.py check -> FAIL"
    OVERALL_SUCCESS=false
fi
echo ""

# 4. makemigrations --check --dry-run
echo "[4/5] Running: python manage.py makemigrations --check --dry-run..."
cd "$BACKEND_DIR"
if "$PYTHON_BIN" manage.py makemigrations --check --dry-run; then
    echo "STEP 4: makemigrations --check -> PASS"
else
    echo "STEP 4: makemigrations --check -> FAIL"
    OVERALL_SUCCESS=false
fi
echo ""

KEEP_DB=false
for arg in "$@"; do
    if [ "$arg" = "--keepdb" ]; then
        KEEP_DB=true
    fi
done

# 5. manage.py test
EXTRA_ARGS=""
if [ "$KEEP_DB" = true ]; then
    EXTRA_ARGS="--keepdb"
fi
echo "[5/5] Running: python manage.py test --noinput $EXTRA_ARGS..."
cd "$BACKEND_DIR"
if [ "$KEEP_DB" = true ]; then
    DJANGO_TEST_OUTPUT=$("$PYTHON_BIN" manage.py test --noinput --keepdb 2>&1 || true)
else
    DJANGO_TEST_OUTPUT=$("$PYTHON_BIN" manage.py test --noinput 2>&1 || true)
fi
echo "$DJANGO_TEST_OUTPUT" | tail -n 30

if echo "$DJANGO_TEST_OUTPUT" | grep -q "^OK$"; then
    echo "STEP 5: manage.py test -> PASS"
else
    DJANGO_FAILURES=$(echo "$DJANGO_TEST_OUTPUT" | grep -E '^(FAIL|ERROR):' || true)
    UNEXPECTED_DJANGO=false
    while IFS= read -r line; do
        TRIMMED=$(echo "$line" | sed -E 's/^(FAIL|ERROR): //')
        if [ -n "$TRIMMED" ]; then
            MATCHED=false
            while IFS= read -r k; do
                k_clean=$(echo "$k" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                [ -z "$k_clean" ] && continue
                [[ "$k_clean" =~ ^# ]] && continue
                if [[ "$TRIMMED" == *"$k_clean"* ]]; then
                    MATCHED=true
                    break
                fi
            done < "$KNOWN_FAILURES_FILE"

            if [ "$MATCHED" = true ]; then
                echo "  [KNOWN] $TRIMMED"
            else
                echo "  [UNEXPECTED] $TRIMMED"
                UNEXPECTED_DJANGO=true
            fi
        fi
    done <<< "$DJANGO_FAILURES"

    if [ "$UNEXPECTED_DJANGO" = false ] && [ -n "$DJANGO_FAILURES" ]; then
        echo "STEP 5: manage.py test -> PASS (Known Baseline Failures Allowed)"
    else
        echo "STEP 5: manage.py test -> FAIL"
        OVERALL_SUCCESS=false
    fi
fi
echo ""

if [ "$OVERALL_SUCCESS" = true ]; then
    echo "GATE STATUS: ALL CRITERIA SATISFIED (PASSED)"
    exit 0
else
    echo "GATE STATUS: CRITERIA FAILED - REGRESSION DETECTED"
    exit 1
fi
