#!/usr/bin/env bash
# Task-specific, fail-closed verifier. Test outcomes are graded only from a
# verifier-owned JSON file populated from Pester's TestResult objects; build or
# module stdout/stderr is diagnostic only and cannot create passing records.
set -uo pipefail

CONFIG=/tests/config.json
TEST_PATCH=/tests/tests.patch
LOG_DIR=/logs/verifier
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
RESULTS_JSON="$LOG_DIR/pester-results.json"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
BASE_COMMIT=f8fcfb14dbcddbf9b9f11a555f8971bc1379fe93

mkdir -p "$LOG_DIR"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"
rm -f "$RESULTS_JSON" "$OUTPUT" "$REPORT" "$REWARD"

write_zero_reward_if_missing() {
    if [ ! -f "$REWARD" ]; then
        echo 0 > "$REWARD"
    fi
}
trap write_zero_reward_if_missing EXIT

infrastructure_error() {
    local message=$1
    python3 - "$message" "$REPORT" "$OUTPUT" <<'PY'
import json, sys
message, report_path, output_path = sys.argv[1:]
with open(report_path, "w", encoding="utf-8") as fh:
    json.dump({"success": False, "infrastructure_error": message, "reward": 0.0}, fh, indent=2)
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump({"tests": []}, fh, indent=2)
PY
    echo 0 > "$REWARD"
    echo "ERROR: $message" | tee -a "$STDERR_LOG" >&2
    exit 2
}

[ -f "$CONFIG" ] || infrastructure_error "missing config.json"
[ -f "$TEST_PATCH" ] || infrastructure_error "missing tests.patch"

WORKSPACE=
for candidate in /app /testbed /workspace; do
    if [ -d "$candidate" ]; then
        WORKSPACE=$candidate
        break
    fi
done
[ -n "$WORKSPACE" ] || infrastructure_error "could not resolve workspace"

PWSH_BIN=/root/.dotnet/tools/pwsh
if [ ! -x "$PWSH_BIN" ]; then
    PWSH_BIN=$(command -v pwsh 2>/dev/null || true)
fi
[ -n "$PWSH_BIN" ] && [ -x "$PWSH_BIN" ] || infrastructure_error "could not resolve pwsh"

# Build before materializing the verifier-owned test file. This prevents an
# agent-controlled build target from replacing the tests after they are added.
BUILD_COMMAND=$(python3 - <<'PY'
import json
with open("/tests/config.json", encoding="utf-8") as fh:
    commands = (json.load(fh).get("execution") or {}).get("commands") or []
if not isinstance(commands, list) or not commands or not isinstance(commands[0], str):
    raise SystemExit("missing build command")
print(commands[0])
PY
) || infrastructure_error "invalid build command configuration"

TIMEOUT_SEC=$(python3 - <<'PY'
import json
with open("/tests/config.json", encoding="utf-8") as fh:
    print((json.load(fh).get("execution") or {}).get("timeout_sec", 1800))
PY
) || infrastructure_error "invalid timeout configuration"

set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" bash -c "$BUILD_COMMAND" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
else
    bash -c "$BUILD_COMMAND" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
fi
BUILD_EXIT=$?
set -e
[ "$BUILD_EXIT" -eq 0 ] || infrastructure_error "project build failed with exit code $BUILD_EXIT"

cd "$WORKSPACE" || infrastructure_error "could not enter workspace"
rm -f "$WORKSPACE/test/Pester/SchemaMigration.Tests.ps1"
APPLIED=0
if command -v git >/dev/null 2>&1; then
    if git apply "$TEST_PATCH" 2>>"$STDERR_LOG" \
        || git apply --3way "$TEST_PATCH" 2>>"$STDERR_LOG"; then
        APPLIED=1
    fi
fi
if [ "$APPLIED" != 1 ] && command -v patch >/dev/null 2>&1; then
    if patch -p1 --forward < "$TEST_PATCH" >>"$STDERR_LOG" 2>&1; then
        APPLIED=1
    fi
fi
[ "$APPLIED" = 1 ] || infrastructure_error "tests.patch did not apply"

# Restore the selected upstream regression files from the declared base commit
# after the solver-controlled build. Agent edits to these files therefore
# cannot weaken or replace the pass-to-pass checks.
UPSTREAM_TESTS=(
    test/Pester/Model.Tests.ps1
    test/Pester/Equatable.Tests.ps1
    test/Pester/ImportMarkdownCommandHelp.Tests.ps1
)
for relative_path in "${UPSTREAM_TESTS[@]}"; do
    temporary_path=$(mktemp /tmp/platyps-base-test.XXXXXX)
    if ! git show "$BASE_COMMIT:$relative_path" > "$temporary_path" 2>>"$STDERR_LOG"; then
        rm -f "$temporary_path"
        infrastructure_error "could not restore $relative_path from the base commit"
    fi
    if ! install -m 0644 "$temporary_path" "$WORKSPACE/$relative_path"; then
        rm -f "$temporary_path"
        infrastructure_error "could not install the base copy of $relative_path"
    fi
    rm -f "$temporary_path"
done
git diff --quiet "$BASE_COMMIT" -- "${UPSTREAM_TESTS[@]}" \
    || infrastructure_error "restored regression tests differ from the base commit"

# This script is created only after the agent-controlled build completes. It
# emits no grading markers to stdout; it atomically writes structured records.
rm -f "$RESULTS_JSON" "$RESULTS_JSON.tmp"
RUNNER=/tmp/run-schema-migration-tests.ps1
cat > "$RUNNER" <<'PSEOF'
param(
    [Parameter(Mandatory)][string] $ResultsPath,
    [Parameter(Mandatory)][string] $ModulePath,
    [Parameter(Mandatory)][string] $Workspace
)

$ErrorActionPreference = 'Stop'
Import-Module -Max 4.99 Pester
$invokePester = Get-Command Invoke-Pester -Module Pester -ErrorAction Stop
Import-Module -Name $ModulePath -Force
$testPaths = @(
    (Join-Path $Workspace 'test/Pester/SchemaMigration.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/Model.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/Equatable.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/ImportMarkdownCommandHelp.Tests.ps1')
)
$result = & $invokePester -Path $testPaths -PassThru -Show None

$records = @($result.TestResult | ForEach-Object {
    $nameParts = @($_.Describe, $_.Context, $_.Name) | Where-Object { -not [string]::IsNullOrEmpty($_) }
    [pscustomobject][ordered]@{
        name = $nameParts -join '.'
        status = [string]$_.Result
    }
})
$json = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $records -Depth 4 -Compress
$temporaryPath = "$ResultsPath.tmp"
[System.IO.File]::WriteAllText(
    $temporaryPath,
    $json,
    [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::Move($temporaryPath, $ResultsPath, $true)

if ($result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or $records.Count -eq 0) {
    exit 1
}
exit 0
PSEOF

set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" "$PWSH_BIN" -NoProfile -File "$RUNNER" \
        -ResultsPath "$RESULTS_JSON" \
        -ModulePath "$WORKSPACE/out/platyPS" \
        -Workspace "$WORKSPACE" \
        >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
else
    "$PWSH_BIN" -NoProfile -File "$RUNNER" \
        -ResultsPath "$RESULTS_JSON" \
        -ModulePath "$WORKSPACE/out/platyPS" \
        -Workspace "$WORKSPACE" \
        >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
fi
PESTER_EXIT=$?
set -e

# Grade only the dedicated JSON artifact. Exact set equality makes missing,
# duplicate, renamed, extra, skipped, and stdout-only results fail.
set +e
python3 - "$CONFIG" "$RESULTS_JSON" "$OUTPUT" "$REPORT" "$REWARD" "$PESTER_EXIT" <<'PY'
import json
import sys

config_path, results_path, output_path, report_path, reward_path, raw_exit = sys.argv[1:]

def write(payload, report, reward):
    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
    with open(reward_path, "w", encoding="utf-8") as fh:
        fh.write("1\n" if reward else "0\n")

try:
    with open(config_path, encoding="utf-8") as fh:
        config = json.load(fh)
    with open(results_path, encoding="utf-8") as fh:
        records = json.load(fh)
    if not isinstance(records, list):
        raise ValueError("Pester results must be a JSON array")

    grading = config.get("grading") or {}
    required = list(grading.get("fail_to_pass") or []) + list(grading.get("pass_to_pass") or [])
    if not required or len(required) != len(set(required)):
        raise ValueError("required test IDs are empty or duplicated")

    names = []
    normalized = []
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("name"), str):
            raise ValueError("malformed Pester test record")
        names.append(record["name"])
        normalized.append({"name": record["name"], "status": str(record.get("status", "Unknown")).upper()})

    duplicates = sorted({name for name in names if names.count(name) > 1})
    missing = sorted(set(required) - set(names))
    unexpected = sorted(set(names) - set(required))
    nonpassing = sorted(record["name"] for record in normalized if record["status"] != "PASSED")
    success = (
        int(raw_exit) == 0
        and not duplicates
        and not missing
        and not unexpected
        and not nonpassing
        and len(normalized) == len(required)
    )
    report = {
        "success": success,
        "infrastructure_error": None,
        "raw_exit_code": int(raw_exit),
        "parser_framework": "pester-json",
        "required_tests_count": len(required),
        "passed_tests_count": sum(record["status"] == "PASSED" for record in normalized),
        "missing_required_tests": missing,
        "unexpected_tests": unexpected,
        "duplicate_tests": duplicates,
        "nonpassing_tests": nonpassing,
        "reward": 1.0 if success else 0.0,
    }
    write({"tests": normalized}, report, success)
    raise SystemExit(0 if success else 1)
except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
    report = {
        "success": False,
        "infrastructure_error": f"could not validate structured Pester results: {error}",
        "raw_exit_code": int(raw_exit),
        "reward": 0.0,
    }
    write({"tests": []}, report, False)
    raise SystemExit(2)
PY
GRADE_EXIT=$?
set -e

write_zero_reward_if_missing
exit "$GRADE_EXIT"
