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
EXPECTED_PATCH_SHA256="58e5ac15c52cf1255b25960b4753236052bb9e2259d58e40f0c56554d432f09b"
EXPECTED_GRADER_SHA256="11a80825bd3d54bc3d5041d6f354ae6797922c4a9da1d92ef145599f41c02e18"

mkdir -p "$LOG_DIR"
rm -f "$STDOUT_LOG" "$STDERR_LOG" "$REPORT" "$OUTPUT" "$REWARD"
VERIFIER_TMP="$(mktemp -d /tmp/sentinel-verifier.XXXXXX)"
SELECTIONS="$VERIFIER_TMP/selections.tsv"
STATUSES="$VERIFIER_TMP/statuses.tsv"
RESULTS="$VERIFIER_TMP/results.json"
SOURCE_WORKSPACE=""
WORKSPACE=""
EXPECTED_BASE_COMMIT="b19cbf62901fc176b6b6036e7e97131d5e339327"

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

# Prefer platform-mounted workspaces over the image's baked /app compatibility
# symlink. Otherwise an oracle applied at /testbed or /workspace can be ignored
# in favor of the untouched source tree embedded in the image.
for candidate in /testbed /workspace /app /go/src/github.com/alibaba/pouch; do
  if [ -f "$candidate/Makefile" ] \
    && [ -f "$candidate/ctrd/utils.go" ] \
    && [ -f "$candidate/daemon/mgr/spec.go" ] \
    && [ -f "$candidate/vendor/vendor.json" ]; then
    SOURCE_WORKSPACE="$candidate"
    break
  fi
done
[ -n "$SOURCE_WORKSPACE" ] || infrastructure_failure "could not resolve the Pouch source workspace"

BASE_COMMIT="$(python3 -c "import json; print(json.load(open('$CONFIG'))['execution']['base_commit_sha'])")" ||
  infrastructure_failure "could not read the declared base commit"
[ "$BASE_COMMIT" = "$EXPECTED_BASE_COMMIT" ] ||
  infrastructure_failure "config base commit differs from the verifier contract"

# Prefer the full Git identity check when metadata is available. Harbor may
# legitimately materialize only the working tree, so stable files outside the
# solution scope provide a fail-closed base-tree identity fallback.
if ACTUAL_HEAD="$(git -C "$SOURCE_WORKSPACE" -c safe.directory="$SOURCE_WORKSPACE" rev-parse HEAD 2>/dev/null)"; then
  [ "$ACTUAL_HEAD" = "$BASE_COMMIT" ] ||
    infrastructure_failure "workspace HEAD does not match the declared base commit"
  git -C "$SOURCE_WORKSPACE" -c safe.directory="$SOURCE_WORKSPACE" \
    cat-file -e "$BASE_COMMIT^{commit}" 2>>"$STDERR_LOG" ||
    infrastructure_failure "declared base commit is unavailable"
else
  verify_sha256 "$SOURCE_WORKSPACE/LICENSE" \
    "c5accbbd8546e94c34aed24afe689a617627d18eed5a6c48277e48db57c23851" ||
    infrastructure_failure "workspace license anchor differs from the declared base"
  verify_sha256 "$SOURCE_WORKSPACE/CHANGELOG.md" \
    "d9179975f1193b282ced485110dfcd6854db9124b4e911b4f21c006a812aaae5" ||
    infrastructure_failure "workspace changelog anchor differs from the declared base"
  verify_sha256 "$SOURCE_WORKSPACE/vendor/vendor.json" \
    "d0892fdf46bfb923a5a67f477fdb8ffeaa87ab811cf18a3ff9a58a530d5f82fc" ||
    infrastructure_failure "workspace vendor anchor differs from the declared base"
fi

# Always test a verifier-owned copy at the canonical GOPATH import location.
# This keeps Go 1.13 vendor resolution correct even when the platform mounts
# the agent workspace over /app or supplies it outside GOPATH.
STAGED_GOPATH="$VERIFIER_TMP/gopath"
WORKSPACE="$STAGED_GOPATH/src/github.com/alibaba/pouch"
mkdir -p "$WORKSPACE" || infrastructure_failure "could not create verifier-owned workspace"
rsync -a --delete --exclude='.git/' "$SOURCE_WORKSPACE/" "$WORKSPACE/" \
  2>>"$STDERR_LOG" || infrastructure_failure "could not stage the source workspace"
cd "$WORKSPACE" || infrastructure_failure "could not enter the verifier-owned workspace"

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
export GOPATH="$STAGED_GOPATH"
export GOCACHE="$VERIFIER_TMP/go-cache"

# Remove every solver-controlled Go test in graded packages. Restore the
# selected upstream regression files byte-for-byte from integrity-checked
# snapshots embedded in this verifier entrypoint, so runtime Git metadata and
# nonstandard files under /tests are not required.
find "$WORKSPACE/ctrd" "$WORKSPACE/daemon/mgr" -maxdepth 1 -type f -name '*_test.go' -delete ||
  infrastructure_failure "could not clear solver-controlled tests"
python3 - "$CONFIG" "$WORKSPACE" <<'PY'
import base64
import hashlib
import json
import os
import sys
from pathlib import Path

config_path, workspace_path = sys.argv[1:]
workspace = Path(workspace_path)
snapshots = {
    "ctrd/utils_test.go": (
        "894935fe35605e832120181ac58ec54a006bc92fa173957d5f9a28b9a7b3a004",
        "cGFja2FnZSBjdHJkCgppbXBvcnQgKAoJImZtdCIKCSJ0ZXN0aW5nIgoKCSJnaXRodWIuY29tL2FsaWJhYmEvcG91Y2gvcGtnL2VycnR5cGVzIgoKCSJnaXRodWIuY29tL2NvbnRhaW5lcmQvY29udGFpbmVyZC9lcnJkZWZzIgoJImdpdGh1Yi5jb20vcGtnL2Vycm9ycyIKKQoKZnVuYyBUZXN0X2NvbnZlcnRDdHJkRXJyKHQgKnRlc3RpbmcuVCkgewoJdHlwZSBhcmdzIHN0cnVjdCB7CgkJZXJyIGVycm9yCgl9Cgl0ZXN0cyA6PSBbXXN0cnVjdCB7CgkJbmFtZSAgICAgICAgc3RyaW5nCgkJYXJncyAgICAgICAgYXJncwoJCXdhbnRFcnIgICAgIGJvb2wKCQlyZXR1cm5lZEVyciBlcnJvcgoJfXsKCQl7CgkJCW5hbWU6ICJuaWwiLAoJCQlhcmdzOiBhcmdzewoJCQkJZXJyOiBuaWwsCgkJCX0sCgkJCXdhbnRFcnI6ICAgICBmYWxzZSwKCQkJcmV0dXJuZWRFcnI6IG5pbCwKCQl9LAoJCXsKCQkJbmFtZTogIm5vdCBmb3VuZCIsCgkJCWFyZ3M6IGFyZ3N7CgkJCQllcnI6IGVycm9ycy5XcmFwKGVycmRlZnMuRXJyTm90Rm91bmQsICJjb250YWluZXIgYXNkZmdoamsiKSwKCQkJfSwKCQkJd2FudEVycjogICAgIHRydWUsCgkJCXJldHVybmVkRXJyOiBlcnJvcnMuV3JhcChlcnJ0eXBlcy5FcnJOb3Rmb3VuZCwgZXJyb3JzLldyYXAoZXJyZGVmcy5FcnJOb3RGb3VuZCwgImNvbnRhaW5lciBhc2RmZ2hqayIpLkVycm9yKCkpLAoJCX0sCgkJewoJCQluYW1lOiAiaW52YWxpZCBwYXJhbXMiLAoJCQlhcmdzOiBhcmdzewoJCQkJZXJyOiBlcnJvcnMuV3JhcChlcnJkZWZzLkVyckludmFsaWRBcmd1bWVudCwgImNvbnRhaW5lciBhc2RmZ2hqayIpLAoJCQl9LAoJCQl3YW50RXJyOiAgICAgdHJ1ZSwKCQkJcmV0dXJuZWRFcnI6IGVycm9ycy5XcmFwKGVycnR5cGVzLkVyckludmFsaWRQYXJhbSwgZXJyb3JzLldyYXAoZXJyZGVmcy5FcnJJbnZhbGlkQXJndW1lbnQsICJjb250YWluZXIgYXNkZmdoamsiKS5FcnJvcigpKSwKCQl9LAoJCXsKCQkJbmFtZTogImFscmVhZHkgZXhpc3RzIiwKCQkJYXJnczogYXJnc3sKCQkJCWVycjogZXJyb3JzLldyYXAoZXJyZGVmcy5FcnJBbHJlYWR5RXhpc3RzLCAiY29udGFpbmVyIGFzZGZnaGprIiksCgkJCX0sCgkJCXdhbnRFcnI6ICAgICB0cnVlLAoJCQlyZXR1cm5lZEVycjogZXJyb3JzLldyYXAoZXJydHlwZXMuRXJyQWxyZWFkeUV4aXN0ZWQsIGVycm9ycy5XcmFwKGVycmRlZnMuRXJyQWxyZWFkeUV4aXN0cywgImNvbnRhaW5lciBhc2RmZ2hqayIpLkVycm9yKCkpLAoJCX0sCgkJewoJCQluYW1lOiAibm90IGltcGxlbWVudGVkIiwKCQkJYXJnczogYXJnc3sKCQkJCWVycjogZXJyb3JzLldyYXAoZXJyZGVmcy5FcnJOb3RJbXBsZW1lbnRlZCwgImNvbnRhaW5lciBhc2RmZ2hqayIpLAoJCQl9LAoJCQl3YW50RXJyOiAgICAgdHJ1ZSwKCQkJcmV0dXJuZWRFcnI6IGVycm9ycy5XcmFwKGVycnR5cGVzLkVyck5vdEltcGxlbWVudGVkLCBlcnJvcnMuV3JhcChlcnJkZWZzLkVyck5vdEltcGxlbWVudGVkLCAiY29udGFpbmVyIGFzZGZnaGprIikuRXJyb3IoKSksCgkJfSwKCQl7CgkJCW5hbWU6ICJub3JtYWwgZXJyb3IiLAoJCQlhcmdzOiBhcmdzewoJCQkJZXJyOiBmbXQuRXJyb3JmKCJ0aGlzIGlzIGEgbm9ybWFsIGVycm9yIiksCgkJCX0sCgkJCXdhbnRFcnI6ICAgICB0cnVlLAoJCQlyZXR1cm5lZEVycjogZm10LkVycm9yZigidGhpcyBpcyBhIG5vcm1hbCBlcnJvciIpLAoJCX0sCgl9Cglmb3IgXywgdHQgOj0gcmFuZ2UgdGVzdHMgewoJCXQuUnVuKHR0Lm5hbWUsIGZ1bmModCAqdGVzdGluZy5UKSB7CgkJCWVyciA6PSBjb252ZXJ0Q3RyZEVycih0dC5hcmdzLmVycikKCQkJaWYgKGVyciAhPSBuaWwpICE9IHR0LndhbnRFcnIgewoJCQkJdC5FcnJvcmYoImNvbnZlcnRDdHJkRXJyKCkgZXJyb3IgPSAldiwgd2FudEVyciAldiIsIGVyciwgdHQud2FudEVycikKCQkJfQoJCQlpZiB0dC53YW50RXJyICYmIChlcnIuRXJyb3IoKSAhPSB0dC5yZXR1cm5lZEVyci5FcnJvcigpKSB7CgkJCQl0LkVycm9yZigiY29udmVydEN0cmRFcnIoKSBlcnJvciA9ICV2LCB3YW50RXJyICV2LCByZXR1cm5lZEVycjogJXYiLCBlcnIsIHR0LndhbnRFcnIsIHR0LnJldHVybmVkRXJyKQoJCQl9CgkJfSkKCX0KfQo=",
    ),
    "daemon/mgr/spec_mount_test.go": (
        "d1fd799a5a0117873e66bfb308499560babc08e6df289ad9cf3a6eb170ef4da0",
        "cGFja2FnZSBtZ3IKCmltcG9ydCAoCgkicmVmbGVjdCIKCSJ0ZXN0aW5nIgoKCXNwZWNzICJnaXRodWIuY29tL29wZW5jb250YWluZXJzL3J1bnRpbWUtc3BlYy9zcGVjcy1nbyIKKQoKZnVuYyBUZXN0X3NvcnRNb3VudHModCAqdGVzdGluZy5UKSB7Cgl0ZXN0cyA6PSBbXXN0cnVjdCB7CgkJbmFtZSBzdHJpbmcKCQlhcmdzIFtdc3BlY3MuTW91bnQKCQl3YW50IFtdc3BlY3MuTW91bnQKCX17CgkJewoJCQkiTW91bnRzIGlzIG5pbCBjYXNlIiwKCQkJbmlsLAoJCQluaWwsCgkJfSwKCQl7CgkJCSJOb3JtYWwgTW91bnRzIiwKCQkJW11zcGVjcy5Nb3VudHsKCQkJCXtEZXN0aW5hdGlvbjogIi9ldGMvcmVzb2x2LmNvbmYifSwKCQkJCXtEZXN0aW5hdGlvbjogIi9ldGMifSwKCQkJfSwKCQkJW11zcGVjcy5Nb3VudHsKCQkJCXtEZXN0aW5hdGlvbjogIi9ldGMifSwKCQkJCXtEZXN0aW5hdGlvbjogIi9ldGMvcmVzb2x2LmNvbmYifSwKCQkJfSwKCQl9LAoJfQoJZm9yIF8sIHR0IDo9IHJhbmdlIHRlc3RzIHsKCQl0LlJ1bih0dC5uYW1lLCBmdW5jKHQgKnRlc3RpbmcuVCkgewoJCQlnb3QgOj0gc29ydE1vdW50cyh0dC5hcmdzKQoJCQlpZiAhcmVmbGVjdC5EZWVwRXF1YWwoZ290LCB0dC53YW50KSB7CgkJCQl0LkVycm9yZigic29ydE1vdW50cygpID0gJXYsIHdhbnQgJXYiLCBnb3QsIHR0LndhbnQpCgkJCX0KCQl9KQoJfQp9Cg==",
    ),
    "daemon/mgr/container_rich_mode_test.go": (
        "1c15e6edc13807e575c2d50771e249b499e319a308f4f727d815682f21d50a55",
        "cGFja2FnZSBtZ3IKCmltcG9ydCAoCgkic3RyaW5ncyIKCSJ0ZXN0aW5nIgoKCSJnaXRodWIuY29tL2FsaWJhYmEvcG91Y2gvYXBpcy90eXBlcyIKCgkiZ2l0aHViLmNvbS9zdHJldGNoci90ZXN0aWZ5L2Fzc2VydCIKKQoKZnVuYyBjb252ZXJ0RW52QXJyYXlUb01hcChlbnZzIFtdc3RyaW5nKSBtYXBbc3RyaW5nXXN0cmluZyB7CgltIDo9IG1hcFtzdHJpbmddc3RyaW5ne30KCWZvciBfLCBlIDo9IHJhbmdlIGVudnMgewoJCWt2cyA6PSBzdHJpbmdzLlNwbGl0KGUsICI9IikKCQlpZiBsZW4oa3ZzKSA9PSAyIHsKCQkJbVtrdnNbMF1dID0ga3ZzWzFdCgkJfQoJfQoKCXJldHVybiBtCn0KCmZ1bmMgVGVzdFJpY2hNb2RlU2V0KHQgKnRlc3RpbmcuVCkgewoJYyA6PSAmQ29udGFpbmVyewoJCUNvbmZpZzogJnR5cGVzLkNvbnRhaW5lckNvbmZpZ3sKCQkJUmljaDogdHJ1ZSwKCQl9LAoJfQoKCWVudnMxIDo9IHJpY2hDb250YWluZXJNb2RlRW52KGMpCgltRW52czEgOj0gY29udmVydEVudkFycmF5VG9NYXAoZW52czEpCgoJYXNzZXJ0LkVxdWFsKHQsICJ0cnVlIiwgbUVudnMxWyJyaWNoX21vZGUiXSkKCWFzc2VydC5FcXVhbCh0LCB0eXBlcy5Db250YWluZXJDb25maWdSaWNoTW9kZUR1bWJJbml0LCBtRW52czFbcmljaE1vZGVMYXVuY2hFbnZdKQoKCS8vdGVzdCBub3Qgc2V0IHJpY2ggbW9kZQoJYyA9ICZDb250YWluZXJ7CgkJQ29uZmlnOiAmdHlwZXMuQ29udGFpbmVyQ29uZmlnewoJCQlSaWNoOiBmYWxzZSwKCQl9LAoJfQoJZW52czIgOj0gcmljaENvbnRhaW5lck1vZGVFbnYoYykKCWFzc2VydC5FcXVhbCh0LCAwLCBsZW4oZW52czIpKQoKCS8vdGVzdCBzZXQgcmljaCBtb2RlIG1hbm5lciwgbm90IHNldCByaWNoIG1vZGUKCWMgPSAmQ29udGFpbmVyewoJCUNvbmZpZzogJnR5cGVzLkNvbnRhaW5lckNvbmZpZ3sKCQkJUmljaDogICAgIGZhbHNlLAoJCQlSaWNoTW9kZTogdHlwZXMuQ29udGFpbmVyQ29uZmlnUmljaE1vZGVTeXN0ZW1kLAoJCX0sCgl9CgllbnZzMyA6PSByaWNoQ29udGFpbmVyTW9kZUVudihjKQoJYXNzZXJ0LkVxdWFsKHQsIDAsIGxlbihlbnZzMykpCgoJLy90ZXN0IHNldCByaWNoIG1vZGUgbWFubmVyCgljID0gJkNvbnRhaW5lcnsKCQlDb25maWc6ICZ0eXBlcy5Db250YWluZXJDb25maWd7CgkJCVJpY2g6ICAgICB0cnVlLAoJCQlSaWNoTW9kZTogdHlwZXMuQ29udGFpbmVyQ29uZmlnUmljaE1vZGVTeXN0ZW1kLAoJCX0sCgl9CgllbnZzNCA6PSByaWNoQ29udGFpbmVyTW9kZUVudihjKQoJbUVudnM0IDo9IGNvbnZlcnRFbnZBcnJheVRvTWFwKGVudnM0KQoJYXNzZXJ0LkVxdWFsKHQsICJ0cnVlIiwgbUVudnM0WyJyaWNoX21vZGUiXSkKCWFzc2VydC5FcXVhbCh0LCB0eXBlcy5Db250YWluZXJDb25maWdSaWNoTW9kZVN5c3RlbWQsIG1FbnZzNFtyaWNoTW9kZUxhdW5jaEVudl0pCgoJLy90ZXN0IHNldCByaWNoIG1vZGUgYnkgZW52CgljID0gJkNvbnRhaW5lcnsKCQlDb25maWc6ICZ0eXBlcy5Db250YWluZXJDb25maWd7CgkJCUVudjogW11zdHJpbmd7CgkJCQlpbnRlclJpY2hNb2RlRW52LAoJCQl9LAoJCX0sCgl9CgllbnZzNSA6PSByaWNoQ29udGFpbmVyTW9kZUVudihjKQoJbUVudnM1IDo9IGNvbnZlcnRFbnZBcnJheVRvTWFwKGVudnM1KQoJYXNzZXJ0LkVxdWFsKHQsICJ0cnVlIiwgbUVudnM1WyJyaWNoX21vZGUiXSkKCWFzc2VydC5FcXVhbCh0LCB0eXBlcy5Db250YWluZXJDb25maWdSaWNoTW9kZVN5c3RlbWQsIG1FbnZzNVtyaWNoTW9kZUxhdW5jaEVudl0pCn0K",
    ),
}

configured = json.load(open(config_path, encoding="utf-8"))["execution"]["protected_test_files"]
if configured != list(snapshots):
    raise SystemExit("protected test snapshot inventory differs from config")

for relative_path, (expected_sha256, encoded) in snapshots.items():
    data = base64.b64decode(encoded, validate=True)
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise SystemExit(f"invalid embedded snapshot for {relative_path}")
    destination = workspace / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".verifier-tmp")
    temporary.write_bytes(data)
    os.chmod(temporary, 0o644)
    os.replace(temporary, destination)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != expected_sha256:
        raise SystemExit(f"restored snapshot differs for {relative_path}")
PY
protected_status=$?
if [ "$protected_status" -ne 0 ]; then
  infrastructure_failure "could not restore protected test snapshots"
fi

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

patch -p1 --batch --forward --dry-run < "$PATCH" >>"$STDERR_LOG" 2>&1 ||
  infrastructure_failure "tests.patch did not pass its application check"
patch -p1 --batch --forward < "$PATCH" >>"$STDERR_LOG" 2>&1 ||
  infrastructure_failure "tests.patch did not apply"

# Install a verifier-owned dependency-boundary probe. Any implementation that
# still asks containerd to generate the starting OCI profile will panic during
# the ownership regression test; the Pouch-owned implementation never calls it.
CONTAINERD_OCI_SPEC="$WORKSPACE/vendor/github.com/containerd/containerd/oci/spec.go"
CONTAINERD_OCI_ORIGINAL="$VERIFIER_TMP/containerd-oci-spec-original.go"
CONTAINERD_OCI_PROBE="$VERIFIER_TMP/containerd-oci-spec-probe.go"
python3 - "$VERIFIER_TMP" <<'PY'
import base64
import hashlib
import sys
from pathlib import Path

verifier_tmp = Path(sys.argv[1])
encoded = "cGFja2FnZSBvY2kKCmltcG9ydCAoCgkiY29udGV4dCIKCgkiZ2l0aHViLmNvbS9jb250YWluZXJkL2NvbnRhaW5lcmQvY29udGFpbmVycyIKCXNwZWNzICJnaXRodWIuY29tL29wZW5jb250YWluZXJzL3J1bnRpbWUtc3BlYy9zcGVjcy1nbyIKKQoKLy8gR2VuZXJhdGVTcGVjIHdpbGwgZ2VuZXJhdGUgYSBkZWZhdWx0IHNwZWMgZnJvbSB0aGUgcHJvdmlkZWQgaW1hZ2UKLy8gZm9yIHVzZSBhcyBhIGNvbnRhaW5lcmQgY29udGFpbmVyCmZ1bmMgR2VuZXJhdGVTcGVjKGN0eCBjb250ZXh0LkNvbnRleHQsIGNsaWVudCBDbGllbnQsIGMgKmNvbnRhaW5lcnMuQ29udGFpbmVyLCBvcHRzIC4uLlNwZWNPcHRzKSAoKnNwZWNzLlNwZWMsIGVycm9yKSB7CglzLCBlcnIgOj0gY3JlYXRlRGVmYXVsdFNwZWMoY3R4LCBjLklEKQoJaWYgZXJyICE9IG5pbCB7CgkJcmV0dXJuIG5pbCwgZXJyCgl9Cglmb3IgXywgbyA6PSByYW5nZSBvcHRzIHsKCQlpZiBlcnIgOj0gbyhjdHgsIGNsaWVudCwgYywgcyk7IGVyciAhPSBuaWwgewoJCQlyZXR1cm4gbmlsLCBlcnIKCQl9Cgl9CglyZXR1cm4gcywgbmlsCn0K"
data = base64.b64decode(encoded, validate=True)
if hashlib.sha256(data).hexdigest() != "2388af74162ae5bf00f4ee56141f3a8e479a66413214ba86547f897171e26e38":
    raise SystemExit("containerd probe snapshot failed integrity validation")
text = data.decode("utf-8")
old = '''func GenerateSpec(ctx context.Context, client Client, c *containers.Container, opts ...SpecOpts) (*specs.Spec, error) {
	s, err := createDefaultSpec(ctx, c.ID)
	if err != nil {
		return nil, err
	}
	for _, o := range opts {
		if err := o(ctx, client, c, s); err != nil {
			return nil, err
		}
	}
	return s, nil
}'''
new = '''func GenerateSpec(ctx context.Context, client Client, c *containers.Container, opts ...SpecOpts) (*specs.Spec, error) {
	panic("verifier-owned containerd profile generator was called")
}'''
if text.count(old) != 1:
    raise SystemExit("containerd profile generator snapshot is unexpected")
(verifier_tmp / "containerd-oci-spec-original.go").write_bytes(data)
(verifier_tmp / "containerd-oci-spec-probe.go").write_text(
    text.replace(old, new), encoding="utf-8"
)
PY
probe_status=$?
if [ "$probe_status" -ne 0 ]; then
  infrastructure_failure "could not install the containerd dependency probe"
fi

: > "$STATUSES"
OVERALL_STATUS=0
TEST_INDEX=0
PER_TEST_TIMEOUT="$(python3 -c "import json; print(json.load(open('$CONFIG'))['execution']['per_test_timeout_sec'])")" ||
  infrastructure_failure "could not read the per-test timeout"

while IFS=$'\t' read -r test_id package_dir package_name test_name; do
  TEST_INDEX=$((TEST_INDEX + 1))
  if [ "$test_name" = "TestCreateSpecDoesNotUseContainerdProfileDefaults" ]; then
    install -m 0644 "$CONTAINERD_OCI_PROBE" "$CONTAINERD_OCI_SPEC" ||
      infrastructure_failure "could not activate the containerd dependency probe"
  else
    install -m 0644 "$CONTAINERD_OCI_ORIGINAL" "$CONTAINERD_OCI_SPEC" ||
      infrastructure_failure "could not restore the containerd dependency source"
  fi
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
