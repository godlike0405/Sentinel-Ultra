#!/usr/bin/env bash
set -e
WORKSPACE="${SENTINEL_WORKSPACE:-/app}"
GOLDEN_PATCH="${SENTINEL_GOLDEN_PATCH:-/solution/golden.patch}"

cd "$WORKSPACE"
if git apply -p1 --check --whitespace=nowarn "$GOLDEN_PATCH" 2>/dev/null; then
  git apply -p1 --whitespace=nowarn "$GOLDEN_PATCH"
elif git apply -p1 --reverse --check --whitespace=nowarn "$GOLDEN_PATCH" 2>/dev/null; then
  echo "Oracle solution is already applied."
else
  echo "ERROR: golden.patch does not apply cleanly to this checkout." >&2
  exit 1
fi

if ! git apply -p1 --reverse --check --whitespace=nowarn "$GOLDEN_PATCH" 2>/dev/null; then
  echo "ERROR: golden.patch verification failed after solve." >&2
  exit 1
fi
