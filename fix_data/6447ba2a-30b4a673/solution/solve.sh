#!/usr/bin/env bash
set -e
cd /app
if git apply -p1 --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  git apply -p1 --whitespace=nowarn /solution/golden.patch
elif git apply -p1 --reverse --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  echo "Oracle solution is already applied."
else
  echo "ERROR: golden.patch does not apply cleanly to this checkout." >&2
  exit 1
fi
