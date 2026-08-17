#!/usr/bin/env bash
set -uo pipefail

CONFIG=/tests/config.json
LOG_DIR=/logs/verifier
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
BASE_COMMIT=0a2bfdfbb15d2f82e26e79b569db0b5dbbefcc8e

mkdir -p "$LOG_DIR"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"
: > "$OUTPUT"
echo '0.0' > "$REWARD"
echo '{"success":false,"infrastructure_error":"verifier did not complete","reward":0.0}' > "$REPORT"

fail_infrastructure() {
  local message=$1
  printf 'ERROR: %s\n' "$message" | tee -a "$STDERR_LOG" >&2
  python3 - "$REPORT" "$message" <<'PY'
import json, sys
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(
        {
            "success": False,
            "infrastructure_error": sys.argv[2],
            "reward": 0.0,
        },
        handle,
        indent=2,
    )
PY
  echo '0.0' > "$REWARD"
  exit 2
}

[[ -f "$CONFIG" ]] || fail_infrastructure "missing config.json"

WORKSPACE=
for candidate in /app /testbed /workspace; do
  if [[ -d "$candidate/.git" ]]; then
    WORKSPACE=$candidate
    break
  fi
done
[[ -n "$WORKSPACE" ]] || fail_infrastructure "could not resolve Git workspace"

git -C "$WORKSPACE" -c safe.directory="$WORKSPACE" \
  cat-file -e "$BASE_COMMIT^{commit}" 2>>"$STDERR_LOG" \
  || fail_infrastructure "declared base commit is unavailable"

SUITE_DIR=$(mktemp -d /tmp/sentinel-verifier-suite.XXXXXX) \
  || fail_infrastructure "could not create verifier-owned test directory"
cleanup() {
  rm -rf -- "$SUITE_DIR"
}
trap cleanup EXIT
mkdir -p "$SUITE_DIR/src/cowrie/test"

# Materialize every test from verifier-owned inputs. The solver's copy of a
# test, conftest.py, pytest configuration, and result report are never trusted.
if ! (cd "$SUITE_DIR" && git apply --whitespace=nowarn /tests/tests.patch) \
    2>>"$STDERR_LOG"; then
  fail_infrastructure "tests.patch did not apply in the verifier-owned directory"
fi
for path in \
  src/cowrie/test/test_fs.py \
  src/cowrie/test/test_filetransfer.py; do
  if ! git -C "$WORKSPACE" -c safe.directory="$WORKSPACE" \
      show "$BASE_COMMIT:$path" > "$SUITE_DIR/$path" 2>>"$STDERR_LOG"; then
    fail_infrastructure "could not restore regression test $path"
  fi
done

cat > /tmp/verifier-pytest.ini <<'PYTEST_INI'
[pytest]
addopts =
PYTEST_INI

cat > /tmp/sentinel-verifier-runner.py <<'PYTHON_RUNNER'
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

CONFIG = Path("/tests/config.json")
LOG_DIR = Path("/logs/verifier")
STDOUT_LOG = LOG_DIR / "test-stdout.txt"
STDERR_LOG = LOG_DIR / "test-stderr.txt"
OUTPUT = LOG_DIR / "output.json"
REPORT = LOG_DIR / "report.json"
REWARD = LOG_DIR / "reward.txt"
SUITE = Path(os.environ["SENTINEL_VERIFIER_SUITE"])
WORKSPACE = Path(os.environ["SENTINEL_WORKSPACE"])
ALLOWED_FILES = {
    "src/cowrie/test/test_honeyfs_session_behavior.py",
    "src/cowrie/test/test_fs.py",
    "src/cowrie/test/test_filetransfer.py",
}


def finish(
    success: bool,
    results: list[dict[str, str]],
    message: str | None = None,
    infrastructure: bool = False,
) -> int:
    passed = [item["name"] for item in results if item["status"] == "PASSED"]
    required = [*fail_to_pass, *pass_to_pass]
    missing = [name for name in required if name not in passed]
    OUTPUT.write_text(json.dumps({"tests": results}, indent=2), encoding="utf-8")
    REPORT.write_text(
        json.dumps(
            {
                "success": success,
                "infrastructure_error": message if infrastructure else None,
                "required_tests_count": len(required),
                "passed_tests_count": len(passed),
                "required_tests": required,
                "passed_required_tests": passed,
                "missing_required_tests": missing,
                "reward": 1.0 if success else 0.0,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    REWARD.write_text("1.0\n" if success else "0.0\n", encoding="utf-8")
    return 0 if success else (2 if infrastructure else 1)


try:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    grading = config["grading"]
    fail_to_pass = list(grading["fail_to_pass"])
    pass_to_pass = list(grading["pass_to_pass"])
    timeout = int(config["execution"]["timeout_sec"])
except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
    fail_to_pass = []
    pass_to_pass = []
    sys.exit(finish(False, [], f"invalid config.json: {exc}", infrastructure=True))

required = [*fail_to_pass, *pass_to_pass]
if not 10 <= len(fail_to_pass) <= 20:
    sys.exit(finish(False, [], "fail_to_pass count is outside 10..20", True))
if not pass_to_pass:
    sys.exit(finish(False, [], "pass_to_pass is empty", True))
if len(required) != len(set(required)):
    sys.exit(finish(False, [], "declared test IDs contain duplicates", True))
if grading.get("allow_extra_failures") is not False:
    sys.exit(finish(False, [], "allow_extra_failures must be false", True))

for test_id in required:
    file_part = test_id.split("::", 1)[0]
    if file_part not in ALLOWED_FILES or not (SUITE / file_part).is_file():
        sys.exit(
            finish(False, [], f"undeclared or missing test file: {file_part}", True)
        )

env = os.environ.copy()
env.pop("PYTEST_ADDOPTS", None)
env.pop("PYTEST_PLUGINS", None)
env["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
env["PYTHONSAFEPATH"] = "1"
deadline = time.monotonic() + timeout
results: list[dict[str, str]] = []

with STDOUT_LOG.open("a", encoding="utf-8") as stdout_handle, STDERR_LOG.open(
    "a", encoding="utf-8"
) as stderr_handle:
    for index, test_id in enumerate(required, start=1):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            results.extend(
                {"name": pending, "status": "ERROR", "source": "verifier-timeout"}
                for pending in required[index - 1 :]
            )
            break
        file_part, *node_parts = test_id.split("::")
        verifier_node = str(SUITE / file_part)
        if node_parts:
            verifier_node += "::" + "::".join(node_parts)
        command = [
            sys.executable,
            "-P",
            "-m",
            "pytest",
            "-c",
            "/tmp/verifier-pytest.ini",
            f"--rootdir={SUITE}",
            "--import-mode=importlib",
            "-q",
            verifier_node,
        ]
        stdout_handle.write(f"\n===== {test_id} =====\n")
        stderr_handle.write(f"\n===== {test_id} =====\n")
        stdout_handle.flush()
        stderr_handle.flush()
        try:
            completed = subprocess.run(
                command,
                cwd=WORKSPACE,
                env=env,
                stdout=stdout_handle,
                stderr=stderr_handle,
                timeout=max(1.0, remaining),
                check=False,
            )
            status = "PASSED" if completed.returncode == 0 else "FAILED"
        except subprocess.TimeoutExpired:
            status = "ERROR"
        results.append({"name": test_id, "status": status, "source": "pytest-exit"})

success = len(results) == len(required) and all(
    item["status"] == "PASSED" for item in results
)
sys.exit(finish(success, results))
PYTHON_RUNNER

export SENTINEL_VERIFIER_SUITE="$SUITE_DIR"
export SENTINEL_WORKSPACE="$WORKSPACE"
python3 -P /tmp/sentinel-verifier-runner.py
exit $?
