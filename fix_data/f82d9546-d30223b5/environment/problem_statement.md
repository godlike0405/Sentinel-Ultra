# Cluster-wide RDMA status and Thunderbolt diagnostics

The cluster can discover Thunderbolt hardware and RDMA topology edges, but it does not propagate whether `rdma_ctl` is enabled on each node. This leaves the dashboard and macOS app with incomplete or misleading diagnostics. Implement the full cluster-state, dashboard, and macOS-app support described below while preserving existing behavior.

## Backend behavior

- Expose a standard gathered-info event that carries the `rdma_ctl` enablement state as `enabled: bool`.
- Report status only on macOS and only when a definitive enabled or disabled state can be determined. Other outcomes produce no observation and must neither escape as errors nor leave the check running without a bound.
- On macOS, keep this status current through periodic checks and deliver successful observations to the rest of the gatherer pipeline. Checks are disabled elsewhere. The interval remains platform-conditioned and configurable. An unsuccessful check must not prevent later checks or interfere with clean service shutdown.
- Cluster state must expose each node's latest reported status through the `nodeRdmaCtl` wire field. A newer observation replaces the node's prior reported value, and a timed-out node is no longer reported. States with no RDMA observations remain valid.
- Extend each Thunderbolt interface identifier with its current link speed. Preserve it through model validation and serialize it as `linkSpeed` while retaining the existing domain UUID and RDMA-interface data.

## Dashboard behavior

- Consume `nodeRdmaCtl` and the Thunderbolt identifiers returned by the state endpoint without regressing the existing topology, identity, memory, network, instance, runner, or download data.
- Preserve the source and sink RDMA interface names from topology connection data. Debug connection labels must display the actual directional interfaces (for example, `RDMA rdma_en2 → rdma_en3`) rather than unknown placeholders.
- In topology debug details, display each node's cluster-reported `RDMA:ON` or `RDMA:OFF` state when available.
- Show the RDMA-availability guidance only when the cluster has at least two Thunderbolt-connected nodes and at least one of those nodes is not reported as RDMA-enabled. Do not show it for a single qualifying node or after all qualifying nodes are enabled. The guidance remains dismissible and provides the existing RDMA setup action/instructions.

## macOS app behavior

- Decode the cluster-wide `nodeRdmaCtl` statuses. Older state payloads that omit the field must continue to decode with no known RDMA statuses.
- The debug view reports RDMA enabled/disabled status for cluster nodes using their friendly names where possible, and identifies the local node.
- Keep the local RDMA device and active-port diagnostics. Enablement must come from cluster state rather than an independent local-only observation.

## Compatibility requirements

- New state fields must have backward-compatible defaults, and state JSON must round-trip without losing per-node values.
- Inability to obtain RDMA status must never terminate the info-gatherer service.
- Do not break existing event handling, timeout cleanup, topology data, dashboard consumers, or macOS decoding of older payloads.

The compatibility names for the gathered and stored status models are `RdmaCtlStatus` and `NodeRdmaCtlStatus`. The state and Thunderbolt wire fields are `nodeRdmaCtl` and `linkSpeed`. Python storage, configuration, helper, component, and file-layout choices remain open.
