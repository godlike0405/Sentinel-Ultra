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
