#!/usr/bin/env bash
set -euo pipefail
cd /app

# Idempotence guard: an exact reverse-check that succeeds means golden.patch is
# already fully applied. Re-applying it (or reverse-applying it as a "fallback")
# would corrupt an already-solved tree, so bail out cleanly instead.
if git apply -p1 --reverse --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  echo "solve.sh: golden.patch is already applied; nothing to do."
  exit 0
fi

# Forward apply only. Never reverse-apply: on a tree the agent has partially
# edited that would silently remove the fix and still exit 0.
if git apply -p1 --whitespace=nowarn /solution/golden.patch; then
  exit 0
fi

# Agent edits to neighbouring lines can defeat a strict apply; retry with 3-way
# merge, which still fails loudly if the fix cannot be reconstructed.
git apply -p1 --3way --whitespace=nowarn /solution/golden.patch
