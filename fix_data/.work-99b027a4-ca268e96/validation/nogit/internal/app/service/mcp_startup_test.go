package service

import (
	"strings"
	"testing"

	whalemcp "github.com/usewhale/whale/internal/mcp"
)

func TestSummarizeMCPStatusShowsStartingProgress(t *testing.T) {
	states := []whalemcp.ServerState{
		{Name: "context7", Status: whalemcp.StatusConnected, Connected: true, Tools: 2},
		{Name: "fs", Status: whalemcp.StatusStarting},
	}
	got := summarizeMCPStatus(states, states[1])
	if !strings.Contains(got, "Starting MCP servers (1/2): fs") {
		t.Fatalf("summary = %q", got)
	}
}

func TestSummarizeMCPCompleteIncludesFailures(t *testing.T) {
	states := []whalemcp.ServerState{
		{Name: "context7", Status: whalemcp.StatusConnected, Connected: true, Tools: 2},
		{Name: "fs", Status: whalemcp.StatusFailed, Error: "timeout"},
	}
	got := summarizeMCPComplete(states)
	if !strings.Contains(got, "1 connected") || !strings.Contains(got, "1 failed") {
		t.Fatalf("summary = %q", got)
	}
}
