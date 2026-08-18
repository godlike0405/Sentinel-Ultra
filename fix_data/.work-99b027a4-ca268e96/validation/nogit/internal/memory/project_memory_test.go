package memory

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReadProjectMemoryByPriority(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "AGENTS.md"), []byte("agents"), 0o600); err != nil {
		t.Fatalf("write agents: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "CLAUDE.md"), []byte("claude"), 0o600); err != nil {
		t.Fatalf("write claude: %v", err)
	}
	pm, ok := ReadProjectMemory(dir, []string{"AGENTS.md", "CLAUDE.md"}, 8000)
	if !ok {
		t.Fatal("expected memory file found")
	}
	if !strings.HasSuffix(pm.Path, "AGENTS.md") || pm.Content != "agents" {
		t.Fatalf("unexpected memory: %+v", pm)
	}
}

func TestReadProjectMemoryTruncates(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "AGENTS.md"), []byte("1234567890"), 0o600); err != nil {
		t.Fatalf("write agents: %v", err)
	}
	pm, ok := ReadProjectMemory(dir, []string{"AGENTS.md"}, 5)
	if !ok {
		t.Fatal("expected memory file found")
	}
	if !pm.Truncated || !strings.Contains(pm.Content, "truncated") {
		t.Fatalf("expected truncation, got %+v", pm)
	}
}
