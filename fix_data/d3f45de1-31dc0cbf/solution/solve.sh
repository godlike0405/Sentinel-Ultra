#!/usr/bin/env bash
set -e
cd /app
if git apply -p1 --check /solution/golden.patch 2>/dev/null; then
  git apply -p1 --whitespace=nowarn /solution/golden.patch
elif git apply -p1 --reverse --check /solution/golden.patch 2>/dev/null; then
  echo "golden.patch is already applied; leaving the solved tree unchanged"
else
  echo "ERROR: golden.patch neither applies cleanly nor is already present" >&2
  exit 1
fi
