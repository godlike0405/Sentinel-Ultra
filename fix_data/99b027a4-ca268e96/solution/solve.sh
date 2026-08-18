#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE="${SENTINEL_SOLUTION_DIR:-/solution}/golden.patch"
WORKSPACE=${SENTINEL_WORKSPACE:-}
for candidate in /testbed /workspace /app; do
  if [ -n "$WORKSPACE" ]; then
    break
  fi
  if [ -f "$candidate/go.mod" ]; then
    WORKSPACE=$candidate
    break
  fi
done

if [ -z "$WORKSPACE" ]; then
  echo "solve.sh: could not locate the Whale workspace" >&2
  exit 2
fi
if [ ! -f "$PATCH_FILE" ]; then
  echo "solve.sh: missing $PATCH_FILE" >&2
  exit 2
fi

cd "$WORKSPACE"
if patch -p1 --forward --batch --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
  patch -p1 --forward --batch < "$PATCH_FILE"
elif patch -p1 --reverse --forward --batch --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
  : # Already solved; never reverse-apply the golden patch.
else
  echo "solve.sh: golden.patch does not apply cleanly in either known state" >&2
  exit 1
fi

# Fail loudly if the solve step was skipped or targeted the wrong workspace.
grep -Fq 'func (b *Toolset) CancelAllBackgroundShellTasks' internal/tools/background_tasks.go
grep -Fq 'Stop all background shell tasks' internal/runtime/commands/catalog.go
grep -Fq 'No background shell tasks running.' internal/app/background_tasks.go
