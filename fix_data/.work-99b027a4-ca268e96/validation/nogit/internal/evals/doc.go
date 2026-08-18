// Package evals provides offline evaluation scaffolding for whale.
//
// The package is intentionally small and deterministic:
//   - scenarios script tool calls through a fake provider
//   - runs execute against the real whale toolset in a temp workspace
//   - verification is done via workspace state and tool envelopes
//   - optional JSONL records can be written and read back for replay/diff workflows
package evals
