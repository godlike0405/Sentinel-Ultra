#!/usr/bin/env bash
set -uo pipefail

CONFIG="/tests/config.json"
PATCH="/tests/tests.patch"
GRADER="/tests/grade.py"
LOG_DIR="/logs/verifier"
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
REPORT="$LOG_DIR/report.json"
OUTPUT="$LOG_DIR/output.json"
REWARD="$LOG_DIR/reward.txt"

EXPECTED_CONFIG_SHA256="7cf7e5468902d39d7df201718ec9986623eff465b26febfb9f92bc7ab5d97309"
EXPECTED_PATCH_SHA256="e727b63cae4bd2ccb0a4950f901fed8df8246b63f96b1cf2d213869daafaded5"
EXPECTED_GRADER_SHA256="11a80825bd3d54bc3d5041d6f354ae6797922c4a9da1d92ef145599f41c02e18"

mkdir -p "$LOG_DIR"
rm -f "$STDOUT_LOG" "$STDERR_LOG" "$REPORT" "$OUTPUT" "$REWARD"
VERIFIER_TMP="$(mktemp -d /tmp/sentinel-verifier.XXXXXX)"
SELECTIONS="$VERIFIER_TMP/selections.tsv"
STATUSES="$VERIFIER_TMP/statuses.tsv"
RESULTS="$VERIFIER_TMP/results.json"
WORKSPACE=""

write_zero_reward_if_missing() {
  if [ ! -f "$REWARD" ]; then
    echo "0.0" > "$REWARD"
  fi
}

cleanup() {
  if [ -n "$WORKSPACE" ]; then
    rm -f "$WORKSPACE/ctrd/zz_sentinel_selected_contract_test.go"
    rm -f "$WORKSPACE/daemon/mgr/zz_sentinel_selected_contract_test.go"
  fi
  write_zero_reward_if_missing
  rm -rf "$VERIFIER_TMP"
}
trap cleanup EXIT

infrastructure_failure() {
  local message="$1"
  echo "ERROR: $message" | tee -a "$STDERR_LOG"
  python3 - "$REPORT" "$OUTPUT" "$REWARD" "$message" <<'PY'
import json
import sys
from pathlib import Path

report, output, reward, message = sys.argv[1:]
Path(report).write_text(json.dumps({
    "success": False,
    "infrastructure_error": message,
    "reward": 0.0,
}, indent=2) + "\n", encoding="utf-8")
Path(output).write_text('{"tests": []}\n', encoding="utf-8")
Path(reward).write_text("0.0\n", encoding="utf-8")
PY
  exit 2
}

verify_sha256() {
  local path="$1"
  local expected="$2"
  [ -f "$path" ] && [ "$(sha256sum "$path" | awk '{print $1}')" = "$expected" ]
}

verify_sha256 "$CONFIG" "$EXPECTED_CONFIG_SHA256" || infrastructure_failure "config integrity failure"
verify_sha256 "$PATCH" "$EXPECTED_PATCH_SHA256" || infrastructure_failure "test patch integrity failure"
verify_sha256 "$GRADER" "$EXPECTED_GRADER_SHA256" || infrastructure_failure "grader integrity failure"

for candidate in /app /testbed /workspace; do
  if [ -d "$candidate/.git" ]; then
    WORKSPACE="$candidate"
    break
  fi
done
[ -n "$WORKSPACE" ] || infrastructure_failure "could not resolve a Git workspace"
cd "$WORKSPACE" || infrastructure_failure "could not enter the workspace"

BASE_COMMIT="$(python3 -c "import json; print(json.load(open('$CONFIG'))['execution']['base_commit_sha'])")" ||
  infrastructure_failure "could not read the declared base commit"
ACTUAL_HEAD="$(git -c safe.directory="$WORKSPACE" rev-parse HEAD 2>>"$STDERR_LOG")" ||
  infrastructure_failure "workspace HEAD does not resolve"
[ "$ACTUAL_HEAD" = "$BASE_COMMIT" ] ||
  infrastructure_failure "workspace HEAD does not match the declared base commit"
git -c safe.directory="$WORKSPACE" cat-file -e "$BASE_COMMIT^{commit}" 2>>"$STDERR_LOG" ||
  infrastructure_failure "declared base commit is unavailable"

python3 - "$CONFIG" "$PATCH" "$SELECTIONS" <<'PY'
import json
import re
import sys
from pathlib import Path

config_path, patch_path, selections_path = sys.argv[1:]
config = json.loads(Path(config_path).read_text(encoding="utf-8"))
execution = config["execution"]
grading = config["grading"]
f2p = grading["fail_to_pass"]
p2p = grading["pass_to_pass"]
expected = [*f2p, *p2p]
protected = execution["protected_test_ids"]

if not 10 <= len(f2p) <= 20:
    raise SystemExit("fail_to_pass count is outside 10..20")
if len(expected) != len(set(expected)):
    raise SystemExit("declared test IDs are duplicated")
if not protected or any(test_id not in p2p for test_id in protected):
    raise SystemExit("protected base tests are not declared pass_to_pass tests")
if grading.get("allow_extra_failures") is not False:
    raise SystemExit("allow_extra_failures must be false")
if grading.get("parser", {}).get("result_source") != "verifier_exit_status":
    raise SystemExit("verifier must grade owned exit statuses")

id_pattern = re.compile(
    r"^github\.com/alibaba/pouch/(?P<package>ctrd|daemon/mgr)::(?P<test>Test[A-Za-z0-9_]*)$"
)
rows = []
for test_id in expected:
    match = id_pattern.fullmatch(test_id)
    if match is None:
        raise SystemExit(f"invalid graded test ID: {test_id}")
    package = match.group("package")
    rows.append((test_id, package, package.rsplit("/", 1)[-1], match.group("test")))

patch_tests = {
    match.group(1)
    for line in Path(patch_path).read_text(encoding="utf-8").splitlines()
    if (match := re.match(r"^\+func (Test[A-Za-z0-9_]*)\(", line))
}
injected_expected = {row[3] for row in rows if row[0] not in protected}
if patch_tests != injected_expected:
    raise SystemExit(
        "tests.patch inventory differs from declared injected tests: "
        f"patch_only={sorted(patch_tests - injected_expected)} "
        f"config_only={sorted(injected_expected - patch_tests)}"
    )

with Path(selections_path).open("w", encoding="utf-8") as handle:
    for row in rows:
        handle.write("\t".join(row) + "\n")
PY
inventory_status=$?
if [ "$inventory_status" -ne 0 ]; then
  infrastructure_failure "invalid grading inventory"
fi

export GOENV=off
export GOFLAGS=""
export GO111MODULE=off
export GOCACHE="$VERIFIER_TMP/go-cache"

# Remove every solver-controlled Go test in graded packages. Restore the
# selected upstream regression files byte-for-byte from the declared base.
find "$WORKSPACE/ctrd" "$WORKSPACE/daemon/mgr" -maxdepth 1 -type f -name '*_test.go' -delete ||
  infrastructure_failure "could not clear solver-controlled tests"
python3 - "$CONFIG" <<'PY' > "$VERIFIER_TMP/protected-files.txt"
import json
import sys
for path in json.load(open(sys.argv[1]))["execution"]["protected_test_files"]:
    print(path)
PY
protected_status=$?
if [ "$protected_status" -ne 0 ]; then
  infrastructure_failure "could not read protected test files"
fi
while IFS= read -r relative_path; do
  case "$relative_path" in
    ctrd/*|daemon/mgr/*) ;;
    *) infrastructure_failure "unsafe protected test path" ;;
  esac
  mkdir -p "$(dirname "$WORKSPACE/$relative_path")" ||
    infrastructure_failure "could not create protected test directory"
  git -c safe.directory="$WORKSPACE" show "$BASE_COMMIT:$relative_path" > "$WORKSPACE/$relative_path" ||
    infrastructure_failure "could not restore protected test file $relative_path"
done < "$VERIFIER_TMP/protected-files.txt"

# Remove every verifier-owned new-file destination before applying the patch,
# so a solver-created collision cannot suppress or corrupt the graded suite.
python3 - "$PATCH" <<'PY' > "$VERIFIER_TMP/new-test-paths.txt"
import re
import sys
from pathlib import Path

current = None
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    match = re.match(r"^diff --git a/(.+) b/(.+)$", line)
    if match:
        current = match.group(2)
    elif line.startswith("new file mode ") and current is not None:
        if current.startswith("/") or ".." in current.split("/"):
            raise SystemExit("unsafe new-file path")
        if not (current.startswith("ctrd/") or current.startswith("daemon/mgr/")):
            raise SystemExit("new verifier test is outside graded packages")
        print(current)
PY
new_paths_status=$?
if [ "$new_paths_status" -ne 0 ]; then
  infrastructure_failure "could not enumerate verifier test destinations"
fi
while IFS= read -r relative_path; do
  rm -f "$WORKSPACE/$relative_path"
done < "$VERIFIER_TMP/new-test-paths.txt"

git -c safe.directory="$WORKSPACE" apply --whitespace=nowarn "$PATCH" 2>>"$STDERR_LOG" ||
  infrastructure_failure "tests.patch did not apply"

: > "$STATUSES"
OVERALL_STATUS=0
TEST_INDEX=0
PER_TEST_TIMEOUT="$(python3 -c "import json; print(json.load(open('$CONFIG'))['execution']['per_test_timeout_sec'])")" ||
  infrastructure_failure "could not read the per-test timeout"

while IFS=$'\t' read -r test_id package_dir package_name test_name; do
  TEST_INDEX=$((TEST_INDEX + 1))
  wrapper="$WORKSPACE/$package_dir/zz_sentinel_selected_contract_test.go"
  completion_file="$VERIFIER_TMP/completed-$TEST_INDEX"
  completion_token="$(head -c 32 /dev/urandom | sha256sum | awk '{print $1}')"
  completion_file_literal="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$completion_file")"
  completion_token_literal="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$completion_token")"
  rm -f "$completion_file"
  printf 'package %s\n\nimport (\n\t"io/ioutil"\n\t"testing"\n)\n\nfunc TestVerifierSelectedContract(t *testing.T) {\n\t%s(t)\n\tif err := ioutil.WriteFile(%s, []byte(%s), 0600); err != nil {\n\t\tt.Fatalf("could not record verifier-owned completion: %%v", err)\n\t}\n}\n' \
    "$package_name" "$test_name" "$completion_file_literal" "$completion_token_literal" > "$wrapper" ||
    infrastructure_failure "could not create verifier-owned test wrapper"

  {
    echo
    echo "===== $test_id ====="
  } >> "$STDOUT_LOG"
  timeout "$PER_TEST_TIMEOUT" go test -count=1 -run '^TestVerifierSelectedContract$' "./$package_dir" \
    >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
  test_status=$?
  rm -f "$wrapper"

  observed_token="$(cat "$completion_file" 2>/dev/null || true)"
  if [ "$test_status" -eq 0 ] && [ "$observed_token" = "$completion_token" ]; then
    result_status="PASSED"
  else
    result_status="FAILED"
    OVERALL_STATUS=1
  fi
  printf '%s\t%s\t%d\n' "$test_id" "$result_status" "$test_status" >> "$STATUSES"
done < "$SELECTIONS"

python3 - "$CONFIG" "$STATUSES" "$RESULTS" <<'PY'
import json
import sys
from pathlib import Path

config_path, statuses_path, results_path = sys.argv[1:]
config = json.loads(Path(config_path).read_text(encoding="utf-8"))
expected = [
    *config["grading"]["fail_to_pass"],
    *config["grading"]["pass_to_pass"],
]
tests = []
for line in Path(statuses_path).read_text(encoding="utf-8").splitlines():
    name, status, exit_code = line.split("\t")
    tests.append({"name": name, "status": status, "exit_code": int(exit_code)})
if [entry["name"] for entry in tests] != expected:
    raise SystemExit("status inventory differs from declared tests")
Path(results_path).write_text(json.dumps({"tests": tests}, indent=2) + "\n", encoding="utf-8")
PY
results_status=$?
if [ "$results_status" -ne 0 ]; then
  infrastructure_failure "could not synthesize structured test results"
fi

python3 "$GRADER" \
  --config "$CONFIG" \
  --results "$RESULTS" \
  --raw-exit-code "$OVERALL_STATUS" \
  --output "$OUTPUT" \
  --report "$REPORT" \
  --reward "$REWARD"
exit "$?"
