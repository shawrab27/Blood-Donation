# scripts/gate.ps1 - Safety Gate Script for BloodPulse
# Runs: flutter analyze, flutter test, manage.py check, makemigrations --check, manage.py test.
# Enforces zero regressions; validates expected failures against docs/known_failures.txt.

[CmdletBinding()]
param(
    [switch]$SkipFlutter,
    [switch]$SkipBackend,
    [switch]$KeepDb
)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$DocsDir = Join-Path $RepoRoot "docs"
$KnownFailuresFile = Join-Path $DocsDir "known_failures.txt"
$FlutterDir = Join-Path $RepoRoot "blood_pulse"
$BackendDir = Join-Path $RepoRoot "blood_pulse_backend"
$VenvPython = Join-Path $RepoRoot "venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    $VenvPython = "python"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "          BLOODPULSE QUALITY & SAFETY GATE SCRIPT          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Repository Root : $RepoRoot"
Write-Host "Python Binary   : $VenvPython"
Write-Host "Known Failures  : $KnownFailuresFile"
Write-Host ""

# Load Known Failures
$KnownFailures = @()
if (Test-Path $KnownFailuresFile) {
    Get-Content $KnownFailuresFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $KnownFailures += $line
        }
    }
    Write-Host "Loaded $($KnownFailures.Count) known failure pattern(s) from docs/known_failures.txt" -ForegroundColor DarkCyan
} else {
    Write-Host "WARNING: docs/known_failures.txt not found. No failures will be excused." -ForegroundColor Yellow
}
Write-Host ""

$OverallSuccess = $true
$Results = [ordered]@{}

function Print-Tail($output, [int]$lines = 15) {
    if (-not $output) { return }
    $arr = $output -split "`r?`n"
    $count = [Math]::Min($lines, $arr.Length)
    $start = [Math]::Max(0, $arr.Length - $count)
    Write-Host "--- [Tail Output (Last $count lines)] ---" -ForegroundColor DarkGray
    for ($i = $start; $i -lt $arr.Length; $i++) {
        Write-Host $arr[$i]
    }
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
}

function Check-KnownFailures($failuresList, $knownList) {
    $unexpected = @()
    $matched = @()

    foreach ($f in $failuresList) {
        $fTrim = $f.Trim()
        if (-not $fTrim) { continue }
        if ($knownList -contains $fTrim) {
            $matched += $fTrim
        } else {
            $unexpected += $fTrim
        }
    }

    return @{
        Unexpected = $unexpected
        Matched = $matched
    }
}

# -------------------------------------------------------------
# STEP 1: flutter analyze
# -------------------------------------------------------------
if (-not $SkipFlutter) {
    Write-Host "[1/5] Running: flutter analyze..." -ForegroundColor Yellow
    $analyzeOut = & {
        Set-Location $FlutterDir
        flutter analyze 2>&1
    } | Out-String
    $analyzeExit = $LASTEXITCODE

    Print-Tail $analyzeOut 15

    if ($analyzeExit -eq 0 -and ($analyzeOut -match "No issues found!")) {
        Write-Host "STEP 1: flutter analyze -> PASS" -ForegroundColor Green
        $Results["flutter analyze"] = "PASS"
    } else {
        Write-Host "STEP 1: flutter analyze -> FAIL (exit $analyzeExit)" -ForegroundColor Red
        $Results["flutter analyze"] = "FAIL"
        $OverallSuccess = $false
    }
    Write-Host ""
}

# -------------------------------------------------------------
# STEP 2: flutter test
# -------------------------------------------------------------
if (-not $SkipFlutter) {
    Write-Host "[2/5] Running: flutter test..." -ForegroundColor Yellow
    $flutterTestOut = & {
        Set-Location $FlutterDir
        flutter test 2>&1
    } | Out-String
    $flutterTestExit = $LASTEXITCODE

    Print-Tail $flutterTestOut 25

    if ($flutterTestExit -eq 0) {
        Write-Host "STEP 2: flutter test -> PASS (All tests passed)" -ForegroundColor Green
        $Results["flutter test"] = "PASS"
    } else {
        # Extract failing tests from output
        $failingTests = @()
        $inFailingSection = $false
        foreach ($line in ($flutterTestOut -split "`r?`n")) {
            if ($line -match "^Failing tests:") {
                $inFailingSection = $true
                continue
            }
            if ($inFailingSection) {
                if ($line -match "^\s{2,}(.+)$") {
                    $raw = $matches[1].Trim()
                    $normalized = $raw -replace "^.*blood_pulse[/\\]", ""
                    $failingTests += $normalized
                } elseif ($line.Trim() -eq "") {
                    continue
                } else {
                    $inFailingSection = $false
                }
            }
        }

        Write-Host "Detected $($failingTests.Count) failure(s) in flutter test." -ForegroundColor DarkYellow
        $check = Check-KnownFailures $failingTests $KnownFailures

        if ($check.Unexpected.Count -eq 0 -and $failingTests.Count -gt 0) {
            Write-Host "All $($failingTests.Count) failures match docs/known_failures.txt:" -ForegroundColor Yellow
            foreach ($m in $check.Matched) {
                Write-Host "  [KNOWN] $m" -ForegroundColor DarkYellow
            }
            Write-Host "STEP 2: flutter test -> PASS (Known Baseline Failures Allowed)" -ForegroundColor Green
            $Results["flutter test"] = "PASS (Known Failures)"
        } else {
            Write-Host "STEP 2: flutter test -> FAIL (Unexpected test failures found)" -ForegroundColor Red
            foreach ($u in $check.Unexpected) {
                Write-Host "  [UNEXPECTED] $u" -ForegroundColor Red
            }
            $Results["flutter test"] = "FAIL"
            $OverallSuccess = $false
        }
    }
    Write-Host ""
}

# -------------------------------------------------------------
# STEP 3: python manage.py check
# -------------------------------------------------------------
if (-not $SkipBackend) {
    $env:DJANGO_ENV = "test"
    $env:USE_SQLITE = "1"
    Write-Host "[3/5] Running: python manage.py check..." -ForegroundColor Yellow
    $checkOut = & {
        Set-Location $BackendDir
        & $VenvPython manage.py check 2>&1
    } | Out-String
    $checkExit = $LASTEXITCODE

    Print-Tail $checkOut 15

    if ($checkExit -eq 0 -and ($checkOut -match "System check identified no issues")) {
        Write-Host "STEP 3: manage.py check -> PASS" -ForegroundColor Green
        $Results["manage.py check"] = "PASS"
    } else {
        Write-Host "STEP 3: manage.py check -> FAIL (exit $checkExit)" -ForegroundColor Red
        $Results["manage.py check"] = "FAIL"
        $OverallSuccess = $false
    }
    Write-Host ""
}

# -------------------------------------------------------------
# STEP 4: python manage.py makemigrations --check --dry-run
# -------------------------------------------------------------
if (-not $SkipBackend) {
    Write-Host "[4/5] Running: python manage.py makemigrations --check --dry-run..." -ForegroundColor Yellow
    $migrationsOut = & {
        Set-Location $BackendDir
        & $VenvPython manage.py makemigrations --check --dry-run 2>&1
    } | Out-String
    $migrationsExit = $LASTEXITCODE

    Print-Tail $migrationsOut 15

    if ($migrationsExit -eq 0 -and ($migrationsOut -match "No changes detected")) {
        Write-Host "STEP 4: makemigrations --check -> PASS" -ForegroundColor Green
        $Results["makemigrations --check"] = "PASS"
    } else {
        Write-Host "STEP 4: makemigrations --check -> FAIL (exit $migrationsExit)" -ForegroundColor Red
        $Results["makemigrations --check"] = "FAIL"
        $OverallSuccess = $false
    }
    Write-Host ""
}

# -------------------------------------------------------------
# STEP 5: python manage.py test
# -------------------------------------------------------------
if (-not $SkipBackend) {
    $extraArgs = if ($KeepDb) { "--keepdb" } else { "" }
    Write-Host "[5/5] Running: python manage.py test --noinput $extraArgs..." -ForegroundColor Yellow
    $djangoTestLines = & {
        Set-Location $BackendDir
        if ($KeepDb) {
            & $VenvPython manage.py test --noinput --keepdb 2>&1
        } else {
            & $VenvPython manage.py test --noinput 2>&1
        }
    }
    $djangoTestExit = $LASTEXITCODE
    $djangoTestOut = ($djangoTestLines -join "`n")

    Print-Tail $djangoTestOut 30

    if ($djangoTestExit -eq 0) {
        Write-Host "STEP 5: manage.py test -> PASS (All tests passed)" -ForegroundColor Green
        $Results["manage.py test"] = "PASS"
    } else {
        # Extract failures and errors as exact module.Class.test IDs
        $failingDjango = @()
        foreach ($item in $djangoTestLines) {
            $line = "$item".Trim()
            if ($line -match "^(FAIL|ERROR):\s*([^\s]+)\s*\((.+)\)$") {
                $testName = $matches[2].Trim()
                $insideParen = $matches[3].Trim()
                if ($insideParen.EndsWith(".$testName") -or $insideParen -eq $testName) {
                    $failingDjango += $insideParen
                } else {
                    $failingDjango += "$insideParen.$testName"
                }
            }
        }

        Write-Host "Detected $($failingDjango.Count) failure/error(s) in manage.py test." -ForegroundColor DarkYellow
        $checkDjango = Check-KnownFailures $failingDjango $KnownFailures

        if ($checkDjango.Unexpected.Count -eq 0 -and $failingDjango.Count -gt 0) {
            Write-Host "All $($failingDjango.Count) failures match docs/known_failures.txt:" -ForegroundColor Yellow
            foreach ($m in $checkDjango.Matched) {
                Write-Host "  [KNOWN] $m" -ForegroundColor DarkYellow
            }
            Write-Host "STEP 5: manage.py test -> PASS (Known Baseline Failures Allowed)" -ForegroundColor Green
            $Results["manage.py test"] = "PASS (Known Failures)"
        } else {
            Write-Host "STEP 5: manage.py test -> FAIL (Unexpected test failures found)" -ForegroundColor Red
            foreach ($u in $checkDjango.Unexpected) {
                Write-Host "  [UNEXPECTED] $u" -ForegroundColor Red
            }
            $Results["manage.py test"] = "FAIL"
            $OverallSuccess = $false
        }
    }
    Write-Host ""
}

# -------------------------------------------------------------
# SUMMARY REPORT
# -------------------------------------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                   GATE SUMMARY REPORT                    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
foreach ($step in $Results.Keys) {
    $status = $Results[$step]
    $color = if ($status.StartsWith("PASS")) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }
    Write-Host ("{0,-30} : {1}" -f $step, $status) -ForegroundColor $color
}
Write-Host "==========================================================" -ForegroundColor Cyan

if ($OverallSuccess) {
    Write-Host "GATE STATUS: ALL CRITERIA SATISFIED (PASSED)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "GATE STATUS: CRITERIA FAILED - REGRESSION DETECTED" -ForegroundColor Red
    exit 1
}
