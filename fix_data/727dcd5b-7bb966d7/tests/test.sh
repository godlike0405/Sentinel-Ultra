#!/usr/bin/env bash
set -uo pipefail

workspace="${WORKSPACE:-/app}"
tests_dir="${TESTS_DIR:-/tests}"
log_dir="${LOG_DIR:-/logs/verifier}"
cmake_command="${CMAKE_COMMAND:-cmake}"
ctest_command="${CTEST_COMMAND:-ctest}"
cc_command="${CC_COMMAND:-cc}"

config="$tests_dir/config.json"
stdout_log="$log_dir/test-stdout.txt"
stderr_log="$log_dir/test-stderr.txt"
results="$log_dir/results.json"
output="$log_dir/output.json"
report="$log_dir/report.json"
reward="$log_dir/reward.txt"

mkdir -p "$log_dir"
rm -f "$stdout_log" "$stderr_log" "$results" "$output" "$report" "$reward"

verifier_tmp=""
compat_tmp=""
cleanup() {
  if [ -n "$verifier_tmp" ] && [ -d "$verifier_tmp" ]; then
    rm -rf "$verifier_tmp"
  fi
  if [ -n "$compat_tmp" ] && [ -d "$compat_tmp" ]; then
    rm -rf "$compat_tmp"
  fi
  if [ ! -f "$reward" ]; then
    echo "0" > "$reward"
  fi
}
trap cleanup EXIT

infrastructure_failure() {
  local message="$1"
  printf '%s\n' "$message" >> "$stderr_log"
  printf '{"success":false,"infrastructure_error":%s,"reward":0.0}\n' \
    "$(python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$message")" > "$report"
  printf '{"tests":[]}\n' > "$output"
  echo "0" > "$reward"
  exit 2
}

if [ ! -f "$config" ] || [ ! -f "$tests_dir/tests.patch" ] || [ ! -f "$tests_dir/grade.py" ]; then
  infrastructure_failure "required verifier artifact is missing"
fi
if [ ! -d "$workspace/.git" ]; then
  infrastructure_failure "workspace is not the shipped Git checkout"
fi

cd "$workspace" || infrastructure_failure "could not enter workspace"
build_dir="$workspace/build"
rm -rf "$build_dir" "$workspace/.sentinel-tests"

real_cc="$(command -v "$cc_command")" || infrastructure_failure "C compiler is unavailable"
compat_tmp="$(mktemp -d)"
mkdir -p "$compat_tmp/include"
printf '%s\n' \
  '#ifndef SENTINEL_MPFR_COMPAT_WRAPPER_H' \
  '#define SENTINEL_MPFR_COMPAT_WRAPPER_H' \
  '#define mpfr_sinpi sentinel_system_mpfr_sinpi' \
  '#define mpfr_cospi sentinel_system_mpfr_cospi' \
  '#include_next <mpfr.h>' \
  '#undef mpfr_sinpi' \
  '#undef mpfr_cospi' \
  '#endif' > "$compat_tmp/include/mpfr.h"
printf '#!/bin/sh\nexec "%s" -fcommon "$@"\n' "$real_cc" > "$compat_tmp/cc"
chmod 700 "$compat_tmp/cc"

pre_stdout="$(mktemp)"
pre_stderr="$(mktemp)"

set +e
"$cmake_command" -S "$workspace" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_C_COMPILER="$compat_tmp/cc" \
  -DMPFR_INCLUDE_DIR="$compat_tmp/include" \
  >"$pre_stdout" 2>"$pre_stderr"
configure_exit=$?
if [ "$configure_exit" -eq 0 ]; then
  "$cmake_command" --build "$build_dir" --parallel 4 \
    --target gnuabi_compatibility_SSE2 gnuabi_compatibility_AVX2 \
    >>"$pre_stdout" 2>>"$pre_stderr"
fi
set -e

rm -f "$results"
if ! git apply --check "$tests_dir/tests.patch" >>"$pre_stdout" 2>>"$pre_stderr"; then
  cp "$pre_stdout" "$stdout_log"
  cp "$pre_stderr" "$stderr_log"
  infrastructure_failure "tests.patch does not apply cleanly after collision cleanup"
fi
git apply "$tests_dir/tests.patch" >>"$pre_stdout" 2>>"$pre_stderr"

verifier_tmp="$(mktemp -d)"
cp "$workspace/.sentinel-tests/test_tester3_contract.py" "$verifier_tmp/test_tester3_contract.py"
rm -rf "$workspace/.sentinel-tests"
rm -f "$results"

timeout_sec="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["execution"]["timeout_sec"])' "$config")"
harness_stdout="$verifier_tmp/harness-stdout.txt"
harness_stderr="$verifier_tmp/harness-stderr.txt"

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "$timeout_sec" python3 -I "$verifier_tmp/test_tester3_contract.py" \
    --workspace "$workspace" \
    --build-dir "$build_dir" \
    --results "$results" \
    --cmake "$cmake_command" \
    --ctest "$ctest_command" \
    --cc "$cc_command" \
    >"$harness_stdout" 2>"$harness_stderr"
else
  python3 -I "$verifier_tmp/test_tester3_contract.py" \
    --workspace "$workspace" \
    --build-dir "$build_dir" \
    --results "$results" \
    --cmake "$cmake_command" \
    --ctest "$ctest_command" \
    --cc "$cc_command" \
    >"$harness_stdout" 2>"$harness_stderr"
fi
test_exit=$?
set -e

{
  cat "$pre_stdout"
  cat "$harness_stdout"
} > "$stdout_log"
{
  cat "$pre_stderr"
  cat "$harness_stderr"
} > "$stderr_log"
rm -f "$pre_stdout" "$pre_stderr"

set +e
python3 -I "$tests_dir/grade.py" \
  --config "$config" \
  --results "$results" \
  --raw-exit-code "$test_exit" \
  --output "$output" \
  --report "$report" \
  --reward "$reward"
grade_exit=$?
set -e

exit "$grade_exit"
