# Cluster-wide RDMA status and Thunderbolt diagnostics

The cluster can discover Thunderbolt hardware and RDMA topology edges, but it does not propagate whether `rdma_ctl` is enabled on each node. This leaves the dashboard and macOS app with incomplete or misleading diagnostics. Implement the full cluster-state, dashboard, and macOS-app support described below while preserving existing behavior.

## Backend behavior

- Add a gathered-info event that carries `enabled: bool` for `rdma_ctl status`, and include it in the public gathered-info union.
- Its asynchronous gather operation returns `None` unless the host is macOS and `rdma_ctl` is resolvable on `PATH`. It must execute exactly `rdma_ctl status` without shell interpolation, use a five-second deadline, and return `None` for spawn errors, timeouts, nonzero exit status, or unrecognized output. After lowercasing and trimming stdout, text containing `enabled` maps to `True` and text containing `disabled` maps to `False`.
- On macOS, the info gatherer polls this status every 10 seconds and sends each non-`None` result through its existing channel. The poll interval follows the existing platform-dependent interval convention: `10` on macOS and `None` elsewhere. Non-macOS polling returns immediately. A polling failure is logged and swallowed so later polls still run, and the monitor participates in the gatherer's normal `run()` lifecycle and shutdown.
- Add the corresponding profiling model and a per-node mapping in cluster `State`. The mapping defaults to empty and serializes through the existing camel-case wire format as `nodeRdmaCtl`.
- Applying a gathered status sets or overwrites that node's value. Timing out a node removes only that node's value.
- Extend each Thunderbolt interface identifier with its current link speed. Preserve it through model validation and serialize it as `linkSpeed` while retaining the existing domain UUID and RDMA-interface data.

## Dashboard behavior

- Consume `nodeRdmaCtl` and the Thunderbolt identifiers returned by the state endpoint without regressing the existing topology, identity, memory, network, instance, runner, or download data.
- Preserve the source and sink RDMA interface names from topology connection data. Debug connection labels must display the actual directional interfaces (for example, `RDMA rdma_en2 → rdma_en3`) rather than unknown placeholders.
- In topology debug details, display each node's cluster-reported `RDMA:ON` or `RDMA:OFF` state when available.
- Show the RDMA-availability guidance only when the cluster has at least two Thunderbolt-connected nodes and at least one of those nodes is not reported as RDMA-enabled. Do not show it for a single qualifying node or after all qualifying nodes are enabled. The guidance remains dismissible and provides the existing RDMA setup action/instructions.

## macOS app behavior

- Decode the cluster-wide `nodeRdmaCtl` mapping and its boolean status model. Older state payloads that omit the field must continue to decode, treating it as an empty mapping.
- The debug view reports RDMA enabled/disabled status for cluster nodes using their friendly names where possible, and identifies the local node.
- Keep the local RDMA device and active-port diagnostics. Remove the redundant local `rdma_ctl status` process and local-only status field; enablement is sourced from cluster state.

## Compatibility requirements

- New state fields must have backward-compatible defaults, and state JSON must round-trip without losing per-node values.
- Missing binaries, unsupported platforms, process failures, and temporary polling errors must never terminate the info-gatherer service.
- Do not break existing event handling, timeout cleanup, topology data, dashboard consumers, or macOS decoding of older payloads.

The public compatibility identifiers for this feature are `RdmaCtlStatus` for the gathered event, `NodeRdmaCtlStatus` for the profiling model, `State.node_rdma_ctl` / `nodeRdmaCtl` for the Python and wire fields, `InfoGatherer.rdma_ctl_poll_interval` for interval configuration, and `link_speed` / `linkSpeed` for the Thunderbolt model and wire fields. Their names are fixed because they cross existing model, event-union, configuration, or serialization boundaries; internal helper and file layout choices remain open.
