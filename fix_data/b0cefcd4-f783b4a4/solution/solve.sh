#!/usr/bin/env bash
set -e
cd /app
if git apply -p1 --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  :
elif git apply -p1 --3way --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  :
else
  exit 1
fi
