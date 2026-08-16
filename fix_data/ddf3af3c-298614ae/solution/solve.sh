#!/usr/bin/env bash
set -euo pipefail

cd /app

if git apply -p1 --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  git apply -p1 --whitespace=nowarn /solution/golden.patch
  exit 0
fi

if git apply -p1 --reverse --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  echo "golden patch is already applied"
  exit 0
fi

echo "ERROR: golden patch cannot be applied cleanly" >&2
exit 1
