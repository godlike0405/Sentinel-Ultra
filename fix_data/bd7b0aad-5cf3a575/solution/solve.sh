#!/usr/bin/env bash
set -euo pipefail

PATCH_FILE=${SENTINEL_GOLDEN_PATCH:-/solution/golden.patch}
WORKSPACE=${SENTINEL_WORKSPACE:-}
if [ ! -d "$WORKSPACE/src/golf" ]; then
  WORKSPACE=
  for candidate in /testbed /workspace /app; do
    if [ -d "$candidate/src/golf" ]; then
      WORKSPACE=$candidate
      break
    fi
  done
fi

if [ -z "$WORKSPACE" ]; then
  echo "ERROR: could not resolve the agent workspace" >&2
  exit 2
fi
if [ ! -f "$PATCH_FILE" ]; then
  echo "ERROR: missing $PATCH_FILE" >&2
  exit 2
fi

cd "$WORKSPACE"
if command -v git >/dev/null 2>&1 \
  && git -c safe.directory="$WORKSPACE" apply --check "$PATCH_FILE" 2>/dev/null; then
  git -c safe.directory="$WORKSPACE" apply --whitespace=nowarn "$PATCH_FILE"
elif command -v git >/dev/null 2>&1 \
  && git -c safe.directory="$WORKSPACE" apply --reverse --check "$PATCH_FILE" 2>/dev/null; then
  echo "Golden patch is already applied; leaving the solved tree unchanged."
elif command -v patch >/dev/null 2>&1 \
  && patch -p1 --forward --dry-run --batch <"$PATCH_FILE" >/dev/null 2>&1; then
  patch -p1 --forward --batch <"$PATCH_FILE"
elif command -v patch >/dev/null 2>&1 \
  && patch -p1 --reverse --forward --dry-run --batch <"$PATCH_FILE" >/dev/null 2>&1; then
  echo "Golden patch is already applied; leaving the solved tree unchanged."
else
  echo "ERROR: golden.patch neither applies forward nor matches an already-solved tree" >&2
  exit 1
fi

# Fail loudly if an execution or packaging problem left the tree unsolved.
python3 -I - "$WORKSPACE" <<'PY'
import ast
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
instrumentation = root / "src/golf/telemetry/instrumentation.py"
exports = root / "src/golf/telemetry/__init__.py"
builder = root / "src/golf/core/builder.py"
for path in (instrumentation, exports, builder):
    if not path.is_file():
        raise SystemExit(f"oracle verification failed: missing {path}")

tree = ast.parse(instrumentation.read_text(encoding="utf-8"))
definitions = {
    node.name
    for node in tree.body
    if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef))
}
required = {
    "get_provider",
    "_extract_serializable_content",
    "OpenTelemetryMiddleware",
    "OTelContextCapturingMiddleware",
}
missing = sorted(required - definitions)
if missing:
    raise SystemExit("oracle verification failed: missing " + ", ".join(missing))

exports_text = exports.read_text(encoding="utf-8")
builder_text = builder.read_text(encoding="utf-8")
for name in ("get_provider", "OpenTelemetryMiddleware", "OTelContextCapturingMiddleware"):
    if name not in exports_text:
        raise SystemExit(f"oracle verification failed: {name} is not exported")
if "mcp.add_middleware(OpenTelemetryMiddleware())" not in builder_text:
    raise SystemExit("oracle verification failed: builder middleware registration is absent")
PY
