#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE=${SENTINEL_GOLDEN_PATCH:-/solution/golden.patch}
WORKSPACE=${SENTINEL_WORKSPACE:-}
if [ -z "$WORKSPACE" ]; then
  for candidate in /testbed /workspace /app; do
    if [ -f "$candidate/package.json" ] && [ -f "$candidate/web/app.js" ]; then
      WORKSPACE=$candidate
      break
    fi
  done
fi
[ -n "$WORKSPACE" ] || { echo "solve.sh: could not locate the mounted crit workspace" >&2; exit 2; }
[ -r "$PATCH_FILE" ] || { echo "solve.sh: missing $PATCH_FILE" >&2; exit 2; }

cd "$WORKSPACE"
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  if git -c safe.directory="$WORKSPACE" apply -p1 --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    echo "solve.sh: golden patch is already applied" >&2
  elif git -c safe.directory="$WORKSPACE" apply -p1 --check "$PATCH_FILE" >/dev/null 2>&1; then
    git -c safe.directory="$WORKSPACE" apply -p1 --whitespace=nowarn "$PATCH_FILE"
  else
    echo "solve.sh: golden patch is neither cleanly applicable nor already applied" >&2
    exit 2
  fi
elif command -v patch >/dev/null 2>&1; then
  if patch -p1 --dry-run --forward < "$PATCH_FILE" >/dev/null 2>&1; then
    patch -p1 --forward < "$PATCH_FILE"
  elif patch -p1 --dry-run --reverse --forward < "$PATCH_FILE" >/dev/null 2>&1; then
    echo "solve.sh: golden patch is already applied" >&2
  else
    echo "solve.sh: golden patch cannot be applied without Git metadata" >&2
    exit 2
  fi
else
  echo "solve.sh: neither git nor patch is available" >&2
  exit 2
fi

printf '%s  %s\n' \
  '70fe17bd06c7fa819f03a1ed10957904318103624198845dc893b309bf495e28' 'web/markdown-it.min.js' \
  '74d7c46dabca328c2294733910a8aa1ed0c37451776e8d5295da38a2b758fb9b' 'web/mermaid.min.js' \
  | sha256sum -c - >/dev/null
