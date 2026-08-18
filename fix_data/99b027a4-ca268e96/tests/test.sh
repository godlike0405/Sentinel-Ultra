#!/usr/bin/env bash
set -uo pipefail

TESTS_DIR=${SENTINEL_TESTS_DIR:-/tests}
CONFIG=$TESTS_DIR/config.json
PATCH=$TESTS_DIR/tests.patch
LOG_DIR=${SENTINEL_LOG_DIR:-/logs/verifier}
STDOUT_LOG=$LOG_DIR/test-stdout.txt
STDERR_LOG=$LOG_DIR/test-stderr.txt
OUTPUT=$LOG_DIR/output.json
REPORT=$LOG_DIR/report.json
REWARD=$LOG_DIR/reward.txt
STAGE=$LOG_DIR/workspace
COMMAND_FILE=$LOG_DIR/commands
TMP_ROOT=$LOG_DIR/tmp

mkdir -p "$LOG_DIR"
rm -f "$STDOUT_LOG" "$STDERR_LOG" "$OUTPUT" "$REPORT" "$REWARD"

write_zero_reward_if_missing() {
  if [ ! -f "$REWARD" ]; then
    echo 0 > "$REWARD"
  fi
}
trap write_zero_reward_if_missing EXIT

infra_fail() {
  local message=$1
  printf 'ERROR: %s\n' "$message" | tee -a "$STDERR_LOG"
  python3 - "$message" "$REPORT" "$REWARD" <<'PY'
import json, pathlib, sys
message, report, reward = sys.argv[1:]
pathlib.Path(report).write_text(json.dumps({
    "success": False,
    "infrastructure_error": message,
    "reward": 0.0,
}, indent=2), encoding="utf-8")
pathlib.Path(reward).write_text("0\n", encoding="utf-8")
PY
  exit 2
}

[ -f "$CONFIG" ] || infra_fail "missing config.json"
[ -f "$PATCH" ] || infra_fail "missing tests.patch"
command -v python3 >/dev/null 2>&1 || infra_fail "python3 is unavailable"
command -v go >/dev/null 2>&1 || infra_fail "go is unavailable"
command -v patch >/dev/null 2>&1 || infra_fail "patch is unavailable"

WORKSPACE=${SENTINEL_WORKSPACE:-}
for candidate in /testbed /workspace /app; do
  if [ -n "$WORKSPACE" ]; then
    break
  fi
  if [ -f "$candidate/go.mod" ]; then
    WORKSPACE=$candidate
    break
  fi
done
[ -n "$WORKSPACE" ] || infra_fail "could not locate the agent workspace"

rm -rf "$STAGE"
mkdir -p "$STAGE"
(
  cd "$WORKSPACE" &&
  tar --exclude=.git --exclude=.gocache -cf - .
) | tar -xf - -C "$STAGE" || infra_fail "could not stage the agent workspace"

find "$STAGE" -type f -name '*_test.go' -delete

restore_snapshot() {
  local relative=$1
  local expected=$2
  local payload=$3
  local target=$STAGE/$relative
  mkdir -p "$(dirname "$target")"
  if ! printf '%s' "$payload" | base64 -d | gzip -d > "$target.tmp"; then
    infra_fail "could not restore verifier-owned regression test $relative"
  fi
  local observed
  observed=$(sha256sum "$target.tmp" | awk '{print $1}')
  if [ "$observed" != "$expected" ]; then
    infra_fail "regression snapshot digest mismatch for $relative"
  fi
  mv "$target.tmp" "$target"
}

restore_snapshot internal/app/commands_copy_test.go 03c7adf215f019ff71ffc0c21e28bcf13dc19420cae400d2462a5cd202ad975e 'H4sIAAAAAAAC/81Y32/bNhB+tv8KRkUKKVOVNsNePPghc9ulXeoMTvvUFgEj07YwmlREykmR+n/f3ZGSLFtpjALtlodW4Y/v7r777kgm5+k/fC4Yz/N+P1vmurAs7PeCVCsr7mwAnzm3i+NZJgV+4ICxRabmBj+tMBa+gz58zzO7KK+TVC+PSyNuF1yKY/dvBliF4vI4lVl+rXkxDfZcrwux51JjaW3U789KlbL34NhI51/eCWMgvtO5CC078u4m7yN23+/hb4YNhuzjZwipTC0O9mSmBIMfFyUM3HJlcQBM+d9eFUU9vcY997hpwAJwOP8SxAwXDdjzdbw9x158c/bXevakY/a5nwXzMPYB4xowN/Vx/Dno2KF0Llqb/tSATaNdvjHIeMEft7Lu92a6YFcxsxb5K7gCCTk6kQ6bTEoVWpsgfMwwIbvs93pzbWMmgEuASLdy5fZGuCybgZmk4v1gyILA7ccZ3D4cMpVJ9vUrO/DSTEYgX54pE8J8Att0EUbxBoz3AF19zS2XszAQd7lIrZgiJASXOgRAY4c3MQNf2eEq2MQg38lDJAR+CmHLQvWr3713B847Z68xV6q2wYGDryArBLQLCN7qDsoWbYc3ERuyw6nLIHw4h10aiG4PVNtYR5jOdatqpAS/JiIVyp4akxkLG96DNMxuEpdm7isISzXxrlBJTLQE4dAwftZIMUMskJaWU6/CR5cusulUKAjmjD4GDMpV7LmX2IWtryGZZjER3GjlN2wOkUg6IT8YUdRo0H6Kx73WWo64lGZQEVON3N+/eQkoKbaBMV9i7ZmFkPKqKFWwXu8ZkuSYhaoUUSJUQQ/nDdMUs5PnkGwSRtXzIJH3FVrsM9JH2VV19FZnKiThBF+DCJXYmrklr2jK1X2jywedQYE+WVUKfYKiJwNelm0xvroTaWkFdvKRXi65msJnJsw5+VwDe93t6hOONQxWiVuEQMTTPA/RTloI7oBxtAaI8SSMO8kPZlkBPO2/1wknuCnRJa2C77NqBLSi6SeFRQwQ/d6KY3cCFqb1IVQIOv4wVGPLa6KrOmoR/albDw5MxUwUzK8PEQ6+6y4MXiSe8nOdcuk5D/3BFvU7mlqT9I6dra7mpHUABpMzmJMQwAbARgd2p43V7FqwhVsZ1Pt96HgOtKjZUSAtA7HdBDGr43cY6AK5ORGmlHbjBNmaSf7KlLNFBGzZqB0mfyVuQwDY5w8MUvcWZLR5flbV6E7QpiZHznugoLkygRZOpdHstsisFQonj+0y9xchsJJrZUSyhBomP5HrnfMQncEy9PXmDpT2ecJ0afPSEnUxW2agRToEfSgbu/t0huxXsWO7+J+X627R/bflxk5+QMGBxDcKyFG0heorbni48kuHde49Squevp38icAnhXnnVPQTFLDbdH9+i6vKhDgea8arsNnSuU2F3dFQNi6FrggH7brbn/CL0l7MJthV3qipuPvBpaaV/EJMX32Ptve+vwcXYAeeKbt88hXPJL+WDbPRQ70aiH2mZ89cx6XL4cbtvspixfE2PS0Wj2CI3pHJmZC5ABeh4DOK3kK6lvnLjMZM88yhPpCMxe3by4vx+SV1hepp7a5UAED9B0KEdh5EjwiSALcl6B4i7Cn4d5/auwHzr/nkD3jtzwtdQh6ATm/E3Ughymf+Hgi3xUsHa2xDxQOy2GCEFEKsgGJBIY1W4N2B5eCyG21zBvG1dVM5kIzIZtjtfuvFcdnEggh1aDFzt+mCvHD3Z8RaR78/TKoLtRLXoFsaHZ2/xYVvs0dV0PQK3ok9L8Sqev/WSOgm1OH2EJzIBHJV53Pk/m/RG7Or5tKQXOTYBU3EwmZs4q8oJH5XJ0f1dcmS7UpC25voujBa8AKeNvAjBTzzsS/hu6V3DtcwN96Ucals6FwMPkEzZr+wF7T2NYj+bxA9/vGh+xJDy8bcZiuBmPjio6GLy9FvJ2SlGlrHmMNN5Vdcsy4OiXLM47+daulp/BIAAA=='
restore_snapshot internal/runtime/commands/classify_test.go 2f963b5ef95620671838aa6dfdfd3d59c8b88ab9364345b3ad99a316c958fae3 'H4sIAAAAAAAC/22NwQqCQBCGz+5TTAuBhtg98BBCpyBIX2AaV1taV2nHQsJ3b7UIhG7zw/d90yHdsFZAbdOgLZ0QuunaO4Nk5VjbWgpR9Zag8DMz6Jyuhry/NJr3RKpjlzOyy5CuKmTYfK2kiOAlgrpl2KWw9EK5dZMDNEkyBikjEegKPJ3MKKxS+LDHltCcFZYna4apGHByQEZTLStAs5fC+hHDEy37w5d/xfhfz38dxSjea8OFQwMBAAA='
restore_snapshot internal/tools/catalog_shell_test.go 441b0adce81a41770be7023bcb3c39fb80331bc3db2cacf98a0c47b42afc2b8f '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'
restore_snapshot internal/tui/tool_result_summary_test.go 03bc004383dc2de4af85116160ea7fa2d3b3f9963d9a66bbc18a53c506925399 'H4sIAAAAAAAC/81X3VIbNxS+9j6FohkSO1kMgbSdcUpnGkKm6TChBae9CC3I2mNbw660SFpjAn6K3vbp+iQ9+rG9wNpwGYYZr6Xz853zfTpal4xfsBEQW4kkEUWptCXtpEWN1UKODMVHC8biM02S1pRJIwgdCTuuBl2uii0+ZroYaMYhB7s13XIGNOkkybCSnPTR9aQqCqbFV+grlR+DqXL7Qen9MbO/aTCgJ2BOxpDnP386+di25GVM1+13yE3S0uyK9PbI+Q01FedgDO1ZXUFKM2YZ7eGyZbbCVaouaEoLQNzcuA2YCnvGVQa0t43mlWZWKHlW4ObO7iylJbvOFctCjExVFmOcVtvbrwdfdl8Xxwfv45ft4lTO198U7w4/H9Q2MCU6g9boTGez2TkiVjmkxMLUOuBmZfVtalzZZ7rCKATr7CQtMSTOnTzbI1R74zMsy/WhZbsfsOJ82KbeYo9sXKbkiklLloap98Y4s6Q1VJqcRQvEoZlElr/8FXi9oafTZZ1TXwx6x9VYZVye+fSI7FnURHdfScuENG1XZEjhuaqDhGkJ3EJGHK0Eu1tWFiGTMnKepWSkbA+XaIgQWobYHXj8L3NM4ZB7zXVPMHfZjiaNYLwD1oAV0Q65vV1j4sqjnXttXSCeCCMG2GJPzxx6I24fz7d71iR4L+sj799HljlDae+rXGnIDoWEd9d/hEx/isyOH0pfSJcYO7Agi5JXZF7UMZTgRDRFHGaZyAU+riSYVzvbHTSncxqTFuK+o8gavLbPFTq77LccBWTo2CE/NWa518N5666cn9NoFhX4o3uOXWtO0FyF73YQdCPpuJvW+rOSU+7aTgxcViA5NLO5PlNdhgEv7Xa7qzPawDiOHILtvgDdlOox2SwmZJTNL8CyPhP5GrHMgf+qhGwvzjtiXHRJSVgc+eX6TmGvVMP6bmHHGpo83hRDVemGje+KoZg0eXxfGDFtWP+hMDABWduZOVYl7TxNtY2zIvT4kTGIvXBzD0ungVCyS3LhhK0KYZFHt4yg/YfDuG4cxvGyfh7iDESsoZzrh0MwoI4zELOsnGGelTDoVto4fh4zQaZWi7gQWYbH+U5HGo/ME2+b2O6a4pZfvTiWX6Mm1vXbH/713ebh3OAd6VzwwZXir851jZ896fXl40hibOMuuCOZX9eF+W28xnzbLyhN4g4vFP7kr5KkVPMr2VPphOcY2FRIQdypkxvfGFZN9Zjwv3//WZ0xMtYwxhfB7wjGNW1fYVdl9tngyy0wzccHSOORBLdwyIyN+ygXIzL4vVIol4eq4QzNHUn+JFXceog8+Mbu4YJvMv4NkEFE42xuzkcaSrKpJaF/e2hDoY2/V08HFCeQBS1ZvkU2N4XkeZXB3ouX3ZF6QW5J8JwQylHeW/Q8dXcZzNJa2AM3W9TtgOlarKHIAUPctefZwoA8f070iNBCGON+T9wLLGzIvNhHbCSAaoAQjR5kd0mGLDeAPv7zKU5vG11KbK9FkYKtysawy7ln+XLqBdLi0JrfXus00ba8GzntvPUeeLpwzdN6b7CtD7Rx2XHnbhLP3cbEaXQR3Cs3nUeuDbv/AR4v+1YEDgAA'

cd "$STAGE" || infra_fail "could not enter staged workspace"
if ! patch -p1 --forward --batch < "$PATCH" >>"$STDERR_LOG" 2>&1; then
  infra_fail "tests.patch did not apply to the staged workspace"
fi

if ! python3 - "$CONFIG" "$COMMAND_FILE" <<'PY'
import json, pathlib, sys
try:
    cfg = json.load(open(sys.argv[1], encoding="utf-8"))
    commands = cfg["execution"]["commands"]
    if not isinstance(commands, list) or len(commands) != 4:
        raise ValueError("execution.commands must contain four package commands")
    for command in commands:
        if not isinstance(command, str) or not command.strip() or "\n" in command:
            raise ValueError("every execution command must be one non-empty line")
    pathlib.Path(sys.argv[2]).write_text("\n".join(commands) + "\n", encoding="utf-8")
except Exception as exc:
    print(f"invalid config: {exc}", file=sys.stderr)
    raise SystemExit(2)
PY
then
  infra_fail "invalid execution commands in config.json"
fi

export GOTOOLCHAIN=local
export GOPROXY=off
export GOSUMDB=off
export GOFLAGS=-buildvcs=false
export GOTMPDIR=$TMP_ROOT/go-build
export TMPDIR=$TMP_ROOT/runtime
mkdir -p "$GOTMPDIR" "$TMPDIR"

RAW_EXIT=0
while IFS= read -r command; do
  if command -v timeout >/dev/null 2>&1; then
    timeout 150 bash -c "$command" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
  else
    bash -c "$command" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
  fi
  rc=$?
  if [ "$rc" -ne 0 ]; then
    RAW_EXIT=1
  fi
done < "$COMMAND_FILE"

python3 - "$CONFIG" "$STDOUT_LOG" "$OUTPUT" "$REPORT" "$REWARD" "$RAW_EXIT" <<'PY'
import json
import pathlib
import sys

config_path, stdout_path, output_path, report_path, reward_path, raw_text = sys.argv[1:]
cfg = json.load(open(config_path, encoding="utf-8"))
grading = cfg.get("grading") or {}
f2p = list(grading.get("fail_to_pass") or [])
p2p = list(grading.get("pass_to_pass") or [])
required = f2p + p2p
raw_exit = int(raw_text)

terminal = {}
duplicates = []
malformed = []
for line_number, line in enumerate(pathlib.Path(stdout_path).read_text(encoding="utf-8", errors="replace").splitlines(), 1):
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        malformed.append(line_number)
        continue
    test = event.get("Test")
    action = event.get("Action")
    package = event.get("Package")
    if not test or action not in {"pass", "fail", "skip"}:
        continue
    name = f"{package}::{test}"
    if name in terminal:
        duplicates.append(name)
    terminal[name] = action.upper()

required_set = set(required)
observed_set = set(terminal)
missing = sorted(required_set - observed_set)
unexpected = sorted(observed_set - required_set)
nonpassing = sorted(name for name in required if terminal.get(name) != "PASS")
success = (
    raw_exit == 0
    and len(required) == len(required_set)
    and not duplicates
    and not missing
    and not unexpected
    and not nonpassing
)
tests = [
    {"name": name, "status": terminal[name], "source": "go-test-json"}
    for name in sorted(terminal)
]
pathlib.Path(output_path).write_text(json.dumps({"tests": tests}, indent=2), encoding="utf-8")
report = {
    "success": success,
    "raw_exit_code": raw_exit,
    "parser_framework": "go-test-json",
    "infrastructure_error": None,
    "required_tests_count": len(required),
    "fail_to_pass_count": len(f2p),
    "pass_to_pass_count": len(p2p),
    "observed_tests_count": len(terminal),
    "passed_tests_count": sum(status == "PASS" for status in terminal.values()),
    "missing_required_tests": missing,
    "unexpected_tests": unexpected,
    "duplicate_terminal_records": sorted(set(duplicates)),
    "nonpassing_required_tests": nonpassing,
    "malformed_output_lines": malformed,
    "reward": 1.0 if success else 0.0,
}
pathlib.Path(report_path).write_text(json.dumps(report, indent=2), encoding="utf-8")
pathlib.Path(reward_path).write_text("1\n" if success else "0\n", encoding="utf-8")
raise SystemExit(0 if success else 1)
PY
GRADE_EXIT=$?

rm -rf "$STAGE"
exit "$GRADE_EXIT"
