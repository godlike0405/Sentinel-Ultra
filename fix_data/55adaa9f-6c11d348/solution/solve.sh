#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE="${SENTINEL_GOLDEN_PATCH:-/solution/golden.patch}"
WORKSPACE=""
if [ -n "${SENTINEL_WORKSPACE:-}" ] && [ -f "$SENTINEL_WORKSPACE/Cargo.toml" ]; then
    WORKSPACE="$SENTINEL_WORKSPACE"
else
    for candidate in /testbed /workspace /app; do
        if [ -f "$candidate/Cargo.toml" ] && [ -d "$candidate/specta" ]; then
            WORKSPACE="$candidate"
            break
        fi
    done
fi

[ -n "$WORKSPACE" ] || { echo "could not resolve the agent workspace" >&2; exit 2; }
[ -f "$PATCH_FILE" ] || { echo "missing golden patch: $PATCH_FILE" >&2; exit 2; }
cd "$WORKSPACE"

if patch -p1 --forward --batch --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
    patch -p1 --forward --batch < "$PATCH_FILE"
elif patch -p1 -R --forward --batch --dry-run < "$PATCH_FILE" >/dev/null 2>&1; then
    echo "golden patch is already applied" >&2
else
    echo "golden patch is neither cleanly applicable nor already applied" >&2
    exit 1
fi

test -f specta-tags/src/lib.rs
test -f specta-tags/src/v1.rs
test -f specta-tags/src/v2.rs
grep -q 'pub struct Analyzer' specta-tags/src/v1.rs
grep -q 'pub struct TransformPlan' specta-tags/src/v2.rs
grep -q 'Untagged' specta-tags/src/v2.rs
