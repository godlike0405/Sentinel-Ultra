#!/usr/bin/env bash
set -euo pipefail

workspace=
for candidate in /testbed /workspace /app; do
  if [[ -d "$candidate" && -f "$candidate/pyproject.toml" && -d "$candidate/src/exo" ]]; then
    workspace=$candidate
    break
  fi
done
[[ -n "$workspace" ]] || {
  echo "could not resolve the exo workspace" >&2
  exit 2
}

cd "$workspace"
patch_file=/solution/golden.patch
applied=0

if command -v git >/dev/null 2>&1 && git apply --check --whitespace=nowarn "$patch_file" 2>/dev/null; then
  git apply --whitespace=nowarn "$patch_file"
  applied=1
elif command -v patch >/dev/null 2>&1 && patch --dry-run -p1 --forward < "$patch_file" >/dev/null 2>&1; then
  patch -p1 --forward < "$patch_file"
  applied=1
fi

# A second invocation may find the exact solution already present. Verify the
# complete postcondition instead of applying any patch in reverse.
python3 - "$workspace" "$applied" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
checks = {
    "src/exo/shared/types/profiling.py": ["NodeRdmaCtlStatus", "enabled: bool"],
    "src/exo/shared/types/state.py": ["node_rdma_ctl", "NodeRdmaCtlStatus"],
    "src/exo/shared/apply.py": ["RdmaCtlStatus", "node_rdma_ctl", "if key != event.node_id"],
    "src/exo/utils/info_gatherer/info_gatherer.py": [
        "class RdmaCtlStatus",
        '["rdma_ctl", "status"]',
        "fail_after(5)",
        "rdma_ctl_poll_interval",
        "monitor_rdma_ctl",
    ],
    "src/exo/shared/types/thunderbolt.py": ["link_speed", "current_speed_key"],
    "dashboard/src/lib/stores/app.svelte.ts": ["nodeRdmaCtl", "nodeThunderbolt", "sourceRdmaIface", "sinkRdmaIface"],
    "dashboard/src/lib/components/ModelCard.svelte": ["sourceRdmaIface", "sinkRdmaIface", "RDMA"],
    "dashboard/src/lib/components/TopologyGraph.svelte": ["nodeRdmaCtl", "RDMA:ON", "RDMA:OFF"],
    "dashboard/src/routes/+page.svelte": ["nodeRdmaCtl", "nodeThunderbolt", "RDMA AVAILABLE"],
    "app/EXO/EXO/Models/ClusterState.swift": ["NodeRdmaCtlStatus", "nodeRdmaCtl", "decodeIfPresent"],
    "app/EXO/EXO/ContentView.swift": ["nodeRdmaCtl", "localNodeId", "Local Devices", "Local Active Ports"],
    "app/EXO/EXO/Services/NetworkStatusService.swift": ["localRdmaDevices", "localRdmaActivePorts"],
}
missing = []
for relative, needles in checks.items():
    path = root / relative
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        missing.append(f"{relative}: {exc}")
        continue
    for needle in needles:
        if needle not in text:
            missing.append(f"{relative}: missing {needle!r}")

service = (root / "app/EXO/EXO/Services/NetworkStatusService.swift").read_text(encoding="utf-8")
if '["rdma_ctl", "status"]' in service:
    missing.append("NetworkStatusService.swift: redundant local rdma_ctl status call remains")

if missing:
    print("solution patch was not applied completely:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in missing), file=sys.stderr)
    raise SystemExit(1)
PY
