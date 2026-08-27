#!/usr/bin/env bash
set -euo pipefail
cd /app
patch_file=/solution/golden.patch

if git apply -p1 --check "$patch_file" 2>/dev/null; then
  git apply -p1 --whitespace=nowarn "$patch_file"
elif git apply -p1 --3way --whitespace=nowarn "$patch_file"; then
  echo "Golden patch applied with a three-way merge."
else
  echo "Golden patch could not be applied cleanly." >&2
  exit 1
fi
