// Package core defines protocol-level types shared across Whale subsystems.
//
// Keep this package limited to stable data structures and pure helpers with no
// filesystem, network, UI, or agent runtime side effects. Business flow belongs
// in agent/app/tools/tui packages instead of here.
package core
