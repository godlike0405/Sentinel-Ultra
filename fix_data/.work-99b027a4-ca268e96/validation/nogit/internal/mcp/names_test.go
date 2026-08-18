package mcp

import (
	"strings"
	"testing"
)

func TestQualifyToolNameSanitizesAndParses(t *testing.T) {
	got := QualifyToolName("git-hub", "create_issue")
	if got != "mcp__git_hub__create_issue" {
		t.Fatalf("qualified name: %s", got)
	}
	server, tool, ok := ParseQualifiedToolName(got)
	if !ok || server != "git_hub" || tool != "create_issue" {
		t.Fatalf("parse: server=%q tool=%q ok=%v", server, tool, ok)
	}
}

func TestQualifyToolNameCapsLength(t *testing.T) {
	got := QualifyToolName(strings.Repeat("server", 10), strings.Repeat("tool", 20))
	if len(got) > maxToolNameLength {
		t.Fatalf("name too long: %d %q", len(got), got)
	}
	if !strings.HasPrefix(got, "mcp__") {
		t.Fatalf("missing prefix: %s", got)
	}
}

func TestUniqueToolNameDisambiguates(t *testing.T) {
	seen := map[string]bool{}
	first := UniqueToolName("mcp__a__b", seen)
	second := UniqueToolName("mcp__a__b", seen)
	if first == second {
		t.Fatalf("expected disambiguated names, got %q", first)
	}
	if len(second) > maxToolNameLength {
		t.Fatalf("second too long: %d", len(second))
	}
}
