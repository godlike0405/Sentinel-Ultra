#!/usr/bin/env bash
set -euo pipefail

GOLDEN_PATCH="/solution/golden.patch"
WORKSPACE=""

# Prefer platform-mounted workspaces over the image's baked /app compatibility
# symlink so the solution is applied to the same tree the platform publishes.
for candidate in /testbed /workspace /app /go/src/github.com/alibaba/pouch; do
  if [ -f "$candidate/Makefile" ] \
    && [ -f "$candidate/ctrd/utils.go" ] \
    && [ -f "$candidate/daemon/mgr/spec.go" ] \
    && [ -f "$candidate/vendor/vendor.json" ]; then
    WORKSPACE="$candidate"
    break
  fi
done

[ -n "$WORKSPACE" ] || {
  echo "could not resolve the Pouch source workspace" >&2
  exit 1
}
cd "$WORKSPACE"

# The evaluation platform may materialize the source tree without .git.
# GNU patch applies the same unified diff without relying on Git metadata.
if patch -p1 --batch --forward --dry-run < "$GOLDEN_PATCH" >/dev/null 2>&1; then
  patch -p1 --batch --forward < "$GOLDEN_PATCH"
elif patch -p1 --batch --reverse --dry-run < "$GOLDEN_PATCH" >/dev/null 2>&1; then
  echo "golden patch already applied"
else
  echo "golden patch cannot be applied cleanly" >&2
  exit 1
fi

if ! patch -p1 --batch --reverse --dry-run < "$GOLDEN_PATCH" >/dev/null 2>&1; then
  echo "golden patch did not produce the expected solved tree" >&2
  exit 1
fi
