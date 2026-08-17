#!/usr/bin/env bash
set -euo pipefail
cd /app

PATCH=/solution/golden.patch

if [ ! -f "$PATCH" ]; then
  echo "solve.sh: FATAL: $PATCH not found" >&2
  exit 2
fi

# Idempotence guard: an exact reverse-check that succeeds means golden.patch is
# already fully applied. Re-applying it (or reverse-applying it as a "fallback")
# would corrupt an already-solved tree, so bail out of the apply step instead.
if git apply -p1 --reverse --check --whitespace=nowarn "$PATCH" >/dev/null 2>&1; then
  echo "solve.sh: golden.patch is already applied; skipping apply."
elif git apply -p1 --whitespace=nowarn "$PATCH"; then
  # Forward apply only. Never reverse-apply: on a tree the agent has partially
  # edited that would silently remove the fix and still exit 0.
  echo "solve.sh: applied golden.patch"
elif git apply -p1 --3way --whitespace=nowarn "$PATCH"; then
  # Agent edits to neighbouring lines can defeat a strict apply; the 3-way
  # merge still fails loudly if the fix cannot be reconstructed.
  echo "solve.sh: applied golden.patch (3-way)"
else
  echo "solve.sh: FATAL: could not apply $PATCH" >&2
  exit 1
fi

# Self-verification. Without this, any failure to actually modify the tree
# (a patch that no-ops, a wrong working directory, a solve step that never
# ran) surfaces only much later as every graded test failing to import, which
# is indistinguishable from an unsolved run. Fail here instead, loudly.
python3 - <<'PY'
import ast
import pathlib
import sys

# Source inspection, not import: importing the package would pull in its
# third-party dependencies, so an unrelated dependency problem would be
# misreported here as "the patch did not apply".
pkg = pathlib.Path("/app/src/claude_agent_sdk")
init = pkg / "__init__.py"
if not init.is_file():
    sys.stderr.write(f"solve.sh: FATAL: {init} not found\n")
    raise SystemExit(1)

exported: set[str] = set()
for node in ast.walk(ast.parse(init.read_text(encoding="utf-8"))):
    if isinstance(node, ast.Assign) and any(
        getattr(t, "id", "") == "__all__" for t in node.targets
    ):
        exported |= {
            e.value for e in getattr(node.value, "elts", []) if isinstance(e, ast.Constant)
        }
    elif isinstance(node, ast.ImportFrom):
        exported |= {a.asname or a.name for a in node.names}

required = {
    "SessionStore",
    "InMemorySessionStore",
    "SessionKey",
    "SessionStoreEntry",
    "MirrorErrorMessage",
    "project_key_for_directory",
}
missing_exports = sorted(required - exported)
missing_modules = [
    m
    for m in (
        "_internal/session_store.py",
        "_internal/session_resume.py",
        "_internal/transcript_mirror_batcher.py",
        "_internal/session_store_validation.py",
        "testing/__init__.py",
    )
    if not (pkg / m).is_file()
]
if missing_exports or missing_modules:
    sys.stderr.write(
        "solve.sh: FATAL: golden.patch did not take effect - "
        f"missing exports {missing_exports}, missing modules {missing_modules}\n"
    )
    raise SystemExit(1)
print("solve.sh: verified the session-store API is present")
PY
