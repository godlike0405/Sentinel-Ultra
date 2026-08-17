#!/usr/bin/env bash
set -euo pipefail
cd /app
if git apply -p1 --check /solution/golden.patch >/dev/null 2>&1; then
  git apply -p1 --whitespace=nowarn /solution/golden.patch
elif git apply -p1 --reverse --check /solution/golden.patch >/dev/null 2>&1; then
  echo "golden patch already applied"
else
  echo "golden patch cannot be applied cleanly" >&2
  exit 1
fi

if ! git apply -p1 --reverse --check /solution/golden.patch >/dev/null 2>&1; then
  echo "golden patch did not produce the expected solved tree" >&2
  exit 1
fi
