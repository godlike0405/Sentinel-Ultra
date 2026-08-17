#!/usr/bin/env bash
set -euo pipefail
cd /app
if git apply -p1 --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  git apply -p1 --whitespace=nowarn /solution/golden.patch
elif git apply -p1 --reverse --check --whitespace=nowarn /solution/golden.patch 2>/dev/null; then
  # The oracle is already present. Idempotent reruns are successful no-ops.
  :
else
  echo "golden.patch is neither applicable nor already applied" >&2
  exit 1
fi

# Fail loudly if an execution or packaging problem left the oracle absent.
# Parse the source directly so unrelated import/dependency failures cannot be
# misreported as a patch-application failure.
python3 - <<'PY'
import ast
from pathlib import Path

tree = ast.parse(Path("src/cowrie/shell/fs.py").read_text(encoding="utf-8"))
filesystem = next(
    (
        node
        for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "HoneyPotFilesystem"
    ),
    None,
)
methods = {
    node.name
    for node in filesystem.body
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
} if filesystem else set()
required = {"_operator_snapshot", "_clear_operator_overlay", "_claim"}
if not required <= methods:
    raise SystemExit("golden.patch verification failed: snapshot reconciliation is absent")
PY
