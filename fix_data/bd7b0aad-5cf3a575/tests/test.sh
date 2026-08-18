#!/usr/bin/env bash
set -uo pipefail

CONFIG=${SENTINEL_TEST_CONFIG:-/tests/config.json}
PATCH_FILE=${SENTINEL_TEST_PATCH:-/tests/tests.patch}
LOG_DIR=${SENTINEL_LOG_DIR:-/logs/verifier}
VERIFIER_PYTHONPATH=${SENTINEL_VERIFIER_PYTHONPATH:-}
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
RUN_ROOT="/var/tmp/golf-otel-verifier-$$"

mkdir -p "$LOG_DIR" "$RUN_ROOT/home"
: >"$STDOUT_LOG"
: >"$STDERR_LOG"

finish_cleanup() {
  if [ ! -f "$REWARD" ]; then
    echo 0 >"$REWARD"
  fi
  rm -rf "$RUN_ROOT"
}
trap finish_cleanup EXIT

fail_infrastructure() {
  local message=$1
  printf 'ERROR: %s\n' "$message" | tee -a "$STDERR_LOG"
  MESSAGE="$message" python3 -I - "$REPORT" "$OUTPUT" <<'PY'
import json
import os
import sys

report_path, output_path = sys.argv[1:]
with open(report_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "success": False,
            "infrastructure_error": os.environ["MESSAGE"],
            "reward": 0.0,
        },
        handle,
        indent=2,
    )
with open(output_path, "w", encoding="utf-8") as handle:
    json.dump({"tests": []}, handle, indent=2)
PY
  echo 0 >"$REWARD"
  exit 2
}

[ -f "$CONFIG" ] || fail_infrastructure "missing config.json"
[ -f "$PATCH_FILE" ] || fail_infrastructure "missing tests.patch"

WORKSPACE=${SENTINEL_WORKSPACE:-}
if [ ! -d "$WORKSPACE/src/golf" ]; then
  WORKSPACE=
  for candidate in /testbed /workspace /app; do
    if [ -d "$candidate/src/golf" ]; then
      WORKSPACE=$candidate
      break
    fi
  done
fi
[ -n "$WORKSPACE" ] || fail_infrastructure "could not resolve the agent workspace"

# The verifier owns this destination. Removing it prevents an agent-created
# collision from aborting patch application or substituting different tests.
rm -f "$WORKSPACE/tests/core/test_otel_instrumentation.py"
if command -v git >/dev/null 2>&1; then
  git -c safe.directory="$WORKSPACE" -C "$WORKSPACE" apply --check "$PATCH_FILE" \
    >>"$STDOUT_LOG" 2>>"$STDERR_LOG" || fail_infrastructure "tests.patch does not apply"
  git -c safe.directory="$WORKSPACE" -C "$WORKSPACE" apply "$PATCH_FILE" \
    >>"$STDOUT_LOG" 2>>"$STDERR_LOG" || fail_infrastructure "tests.patch failed to apply"
elif command -v patch >/dev/null 2>&1; then
  (cd "$WORKSPACE" && patch -p1 --forward <"$PATCH_FILE") \
    >>"$STDOUT_LOG" 2>>"$STDERR_LOG" || fail_infrastructure "tests.patch failed to apply"
else
  fail_infrastructure "neither git nor patch is available"
fi

cp "$WORKSPACE/tests/core/test_otel_instrumentation.py" "$RUN_ROOT/test_otel_instrumentation.py"

# This is a gzip-compressed, verifier-owned snapshot of the declared base
# regression file. Its digest is checked before any pass-to-pass node runs.
printf '%s' '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' | base64 -d | gzip -d >"$RUN_ROOT/test_telemetry.py" \
  || fail_infrastructure "could not materialize the base regression snapshot"
printf '%s  %s\n' \
  '9ed7855cb7cae72b94e24074b783fc1c77fba0beb37795437eb87b3ac949e32c' \
  "$RUN_ROOT/test_telemetry.py" | sha256sum -c - \
  >>"$STDOUT_LOG" 2>>"$STDERR_LOG" || fail_infrastructure "base regression snapshot digest mismatch"

cat >"$RUN_ROOT/run_one.py" <<'PY'
import os
import sys

os.environ["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
import pytest
import pytest_asyncio.plugin as asyncio_plugin

workspace_src, node_id, completion_path = sys.argv[1:]
sys.path.insert(0, workspace_src)
status = int(
    pytest.main(
        ["-c", "/dev/null", "-p", "no:cacheprovider", "--tb=short", "-q", node_id],
        plugins=[asyncio_plugin],
    )
)
if status == 0:
    with open(completion_path, "w", encoding="utf-8") as handle:
        handle.write("completed\n")
raise SystemExit(status)
PY

mapfile -t F2P < <(
  python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["grading"]["fail_to_pass"]))' "$CONFIG"
)
mapfile -t P2P < <(
  python3 -I -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["grading"]["pass_to_pass"]))' "$CONFIG"
)
REQUIRED=("${F2P[@]}" "${P2P[@]}")
[ "${#F2P[@]}" -ge 11 ] || fail_infrastructure "fewer than 11 fail-to-pass tests declared"
[ "${#P2P[@]}" -ge 1 ] || fail_infrastructure "no pass-to-pass regression tests declared"

RESULTS="$RUN_ROOT/results.tsv"
: >"$RESULTS"
worst_exit=0
for declared in "${REQUIRED[@]}"; do
  suffix=${declared#*::}
  case "$declared" in
    tests/core/test_otel_instrumentation.py::*)
      actual="$RUN_ROOT/test_otel_instrumentation.py::$suffix"
      ;;
    tests/core/test_telemetry.py::*)
      actual="$RUN_ROOT/test_telemetry.py::$suffix"
      ;;
    *)
      printf '%s\tFAILED\n' "$declared" >>"$RESULTS"
      printf 'Unknown declared test path: %s\n' "$declared" >>"$STDERR_LOG"
      worst_exit=1
      continue
      ;;
  esac

  completion="$RUN_ROOT/completion"
  out="$RUN_ROOT/stdout"
  err="$RUN_ROOT/stderr"
  rm -f "$completion" "$out" "$err"
  printf '\n===== %s =====\n' "$declared" >>"$STDOUT_LOG"

  set +e
  PYTHONPATH="$VERIFIER_PYTHONPATH" GOLF_TELEMETRY=0 GOLF_TEST_MODE=1 HOME="$RUN_ROOT/home" \
    timeout 45 python3 "$RUN_ROOT/run_one.py" "$WORKSPACE/src" "$actual" "$completion" \
    >"$out" 2>"$err"
  test_exit=$?
  set -e
  sed "s|$RUN_ROOT/test_otel_instrumentation.py|tests/core/test_otel_instrumentation.py|g; s|$RUN_ROOT/test_telemetry.py|tests/core/test_telemetry.py|g" \
    "$out" >>"$STDOUT_LOG"
  sed "s|$RUN_ROOT/test_otel_instrumentation.py|tests/core/test_otel_instrumentation.py|g; s|$RUN_ROOT/test_telemetry.py|tests/core/test_telemetry.py|g" \
    "$err" >>"$STDERR_LOG"

  if [ "$test_exit" -eq 0 ] && [ "$(cat "$completion" 2>/dev/null || true)" = completed ]; then
    status=PASSED
  else
    status=FAILED
    worst_exit=1
  fi
  printf '%s\t%s\n' "$declared" "$status" >>"$RESULTS"
done

python3 -I - "$CONFIG" "$RESULTS" "$OUTPUT" "$REPORT" "$REWARD" "$worst_exit" <<'PY'
import json
import sys

config_path, results_path, output_path, report_path, reward_path, raw_exit = sys.argv[1:]
with open(config_path, encoding="utf-8") as handle:
    config = json.load(handle)
grading = config["grading"]
required = [*grading["fail_to_pass"], *grading["pass_to_pass"]]
rows = []
with open(results_path, encoding="utf-8") as handle:
    for line in handle:
        name, status = line.rstrip("\n").split("\t", 1)
        rows.append({"name": name, "status": status, "source": "verifier-owned-exit-status"})

observed = [row["name"] for row in rows]
inventory_ok = observed == required and len(observed) == len(set(observed))
passed = [row["name"] for row in rows if row["status"] == "PASSED"]
missing = [name for name in required if name not in passed]
success = inventory_ok and not missing and int(raw_exit) == 0
reward = 1.0 if success else 0.0

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump({"tests": rows}, handle, indent=2)
with open(report_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "success": success,
            "reward": reward,
            "raw_exit_code": int(raw_exit),
            "infrastructure_error": None,
            "required_tests_count": len(required),
            "passed_tests_count": len(passed),
            "required_tests": required,
            "passed_required_tests": passed,
            "missing_required_tests": missing,
            "inventory_exact": inventory_ok,
            "unexpected_failures": [],
        },
        handle,
        indent=2,
    )
with open(reward_path, "w", encoding="utf-8") as handle:
    handle.write("1\n" if success else "0\n")
raise SystemExit(0 if success else 1)
PY
