#!/usr/bin/env bash
set -euo pipefail

workspace="${WORKSPACE:-/app}"
solution_dir="${SOLUTION_DIR:-/solution}"
patch_file="$solution_dir/golden.patch"

cd "$workspace"

if git apply --check "$patch_file"; then
  git apply --whitespace=nowarn "$patch_file"
elif git apply --reverse --check "$patch_file"; then
  echo "Golden patch is already applied."
else
  echo "Golden patch does not apply cleanly to this checkout." >&2
  exit 1
fi

if [ ! -f src/libm-tester/tester3.c ] || [ ! -f src/libm-tester/tester3main.c ]; then
  echo "Golden patch verification failed: tester3 sources are absent." >&2
  exit 1
fi
if ! grep -q 'test_d_d(ATR, acos' src/libm-tester/tester3.c \
    || ! grep -q 'test_f_f(ATR, acos' src/libm-tester/tester3.c; then
  echo "Golden patch verification failed: deterministic acos coverage is absent." >&2
  exit 1
fi
if ! grep -q 'asin_u10_dp' src/libm-tester/tester3.c \
    || ! grep -q 'acos_u10_sp' src/libm-tester/tester3.c; then
  echo "Golden patch verification failed: both accuracy tiers are not covered." >&2
  exit 1
fi
if ! grep -q 'Unexpected trailing expectation data' src/libm-tester/tester3.c; then
  echo "Golden patch verification failed: snapshot validation is not fail-closed." >&2
  exit 1
fi
if [ ! -f src/libm-tester/hash_finz_simd.txt ] \
    || ! grep -q 'hash_finz_simd.txt' src/libm-tester/CMakeLists.txt; then
  echo "Golden patch verification failed: distinct SIMD expectations are absent." >&2
  exit 1
fi
