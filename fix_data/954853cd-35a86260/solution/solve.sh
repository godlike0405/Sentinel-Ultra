#!/usr/bin/env bash
set -euo pipefail

cd /app

if git apply --check /solution/golden.patch; then
    git apply /solution/golden.patch
elif git apply --reverse --check /solution/golden.patch; then
    # The oracle is already present. Keep repeated solve invocations idempotent.
    exit 0
else
    echo "golden.patch neither applies cleanly nor matches the current tree" >&2
    exit 1
fi
