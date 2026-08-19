#!/usr/bin/env bash
set -uo pipefail

CONFIG=/tests/config.json
LOG_DIR=/logs/verifier
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
BASE_COMMIT=7bed91c9c277d568c9ffcb24dd6b07d23285b3d0
P2P_SHA256=4baaf6a62c80f8b84e7a1408392265fdcf453d9a73f4e2b6307b34e6a1612297

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
    json.dump({"success": False, "infrastructure_error": sys.argv[2], "reward": 0.0}, handle, indent=2)
PY
  echo '0.0' > "$REWARD"
  exit 2
}

[[ -f "$CONFIG" ]] || fail_infrastructure "missing config.json"

verify_workspace_identity() {
  local relative expected actual
  while read -r expected relative; do
    [[ -f "$WORKSPACE/$relative" ]] \
      || fail_infrastructure "workspace identity file is missing: $relative"
    actual=$(sha256sum "$WORKSPACE/$relative" | awk '{print $1}') \
      || fail_infrastructure "could not hash workspace identity file: $relative"
    [[ "$actual" == "$expected" ]] \
      || fail_infrastructure "workspace does not match the declared base: $relative"
  done <<'IDENTITY_FILES'
6c22818866dcd8b56a3ec274d7b792e42da63ec6ce2e9b7abbba5e842c8b3fb8 pyproject.toml
ef9690f7cc6b44336e19fe56eff69193a090cb5619d68876a0d4dc2f6ab3c795 uv.lock
253bc44025fe0731841cdb95e76c889ad129248e446305f8c65322c1b20da3d1 dashboard/package-lock.json
12a6ed8c837f40b1add1b9fdd7a142bde27e399310da8f60c2a8ed45dcf31517 LICENSE
IDENTITY_FILES
}

# Mounted solver workspaces take precedence over an image's build-time /app.
WORKSPACE=
for candidate in /testbed /workspace /app; do
  if [[ -d "$candidate" && -f "$candidate/pyproject.toml" && -d "$candidate/src/exo" ]]; then
    WORKSPACE=$candidate
    break
  fi
done
[[ -n "$WORKSPACE" ]] || fail_infrastructure "could not resolve the exo workspace"

if command -v git >/dev/null 2>&1 \
  && git -C "$WORKSPACE" -c safe.directory="$WORKSPACE" rev-parse --is-inside-work-tree \
    >/dev/null 2>&1 \
  && git -C "$WORKSPACE" -c safe.directory="$WORKSPACE" rev-parse --verify HEAD \
    >/dev/null 2>&1 \
  && git -C "$WORKSPACE" -c safe.directory="$WORKSPACE" cat-file -e "$BASE_COMMIT^{commit}" \
    >/dev/null 2>&1; then
  : # A usable object database contains the declared base.
else
  # Harbor mounts may omit Git or expose only a partial .git directory.
  verify_workspace_identity
fi

SUITE_DIR=$(mktemp -d /tmp/sentinel-verifier-suite.XXXXXX) \
  || fail_infrastructure "could not create verifier-owned test directory"
cleanup() {
  rm -rf -- "$SUITE_DIR"
}
trap cleanup EXIT
mkdir -p \
  "$SUITE_DIR/src/exo/utils/info_gatherer/tests" \
  "$SUITE_DIR/src/exo/shared/tests"

# Materialize F2P tests solely from the verifier-owned patch.
if ! (cd "$SUITE_DIR" && git apply --whitespace=nowarn /tests/tests.patch) \
    2>>"$STDERR_LOG"; then
  fail_infrastructure "tests.patch did not apply in the verifier-owned directory"
fi

# Embed the clean-base regression test so pass-to-pass protection does not
# depend on mutable workspace files or Git metadata.
cat > "$SUITE_DIR/src/exo/shared/tests/test_state_serialization.py" <<'PYTEST'
from exo.shared.types.common import NodeId
from exo.shared.types.multiaddr import Multiaddr
from exo.shared.types.state import State
from exo.shared.types.topology import Connection, SocketConnection


def test_state_serialization_roundtrip() -> None:
    """Verify that State → JSON → State round-trip preserves topology."""

    # --- build a simple state ------------------------------------------------
    node_a = NodeId("node-a")
    node_b = NodeId("node-b")

    connection = Connection(
        source=node_a,
        sink=node_b,
        edge=SocketConnection(
            sink_multiaddr=Multiaddr(address="/ip4/127.0.0.1/tcp/10001"),
        ),
    )

    state = State()
    state.topology.add_connection(connection)

    json_repr = state.model_dump_json()
    restored_state = State.model_validate_json(json_repr)

    assert (
        state.topology.to_snapshot().nodes
        == restored_state.topology.to_snapshot().nodes
    )
    assert set(state.topology.to_snapshot().connections) == set(
        restored_state.topology.to_snapshot().connections
    )
    assert restored_state.model_dump_json() == json_repr
PYTEST

actual_p2p_sha=$(sha256sum "$SUITE_DIR/src/exo/shared/tests/test_state_serialization.py" | awk '{print $1}')
[[ "$actual_p2p_sha" == "$P2P_SHA256" ]] \
  || fail_infrastructure "embedded pass-to-pass test digest mismatch"

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
    "src/exo/utils/info_gatherer/tests/test_rdma_full_stack_contract.py",
    "src/exo/shared/tests/test_state_serialization.py",
}
fail_to_pass: list[str] = []
pass_to_pass: list[str] = []


def finish(
    success: bool,
    results: list[dict[str, str]],
    message: str | None = None,
    infrastructure: bool = False,
) -> int:
    required = [*fail_to_pass, *pass_to_pass]
    passed = [item["name"] for item in results if item["status"] == "PASSED"]
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
if grading.get("parser", {}).get("result_source") != "verifier_exit_statuses":
    sys.exit(finish(False, [], "result_source must be verifier_exit_statuses", True))

for test_id in required:
    file_part = test_id.split("::", 1)[0]
    if file_part not in ALLOWED_FILES or not (SUITE / file_part).is_file():
        sys.exit(finish(False, [], f"undeclared or missing test file: {file_part}", True))

suite_files = {
    str(path.relative_to(SUITE))
    for path in SUITE.rglob("*")
    if path.is_file()
}
if suite_files != ALLOWED_FILES:
    sys.exit(finish(False, [], f"unexpected verifier suite files: {sorted(suite_files - ALLOWED_FILES)}", True))

env = os.environ.copy()
env.pop("PYTEST_ADDOPTS", None)
env.pop("PYTEST_PLUGINS", None)
env["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
env["PYTHONSAFEPATH"] = "1"
env["PYTHONPATH"] = str(WORKSPACE / "src")
env["EXO_DASHBOARD_DIR"] = str(WORKSPACE / "dashboard")
env["SENTINEL_WORKSPACE"] = str(WORKSPACE)
deadline = time.monotonic() + timeout
results: list[dict[str, str]] = []

with STDOUT_LOG.open("a", encoding="utf-8") as stdout_handle, STDERR_LOG.open(
    "a", encoding="utf-8"
) as stderr_handle:
    for index, test_id in enumerate(required):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            results.extend(
                {"name": pending, "status": "ERROR", "source": "verifier-timeout"}
                for pending in required[index:]
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
