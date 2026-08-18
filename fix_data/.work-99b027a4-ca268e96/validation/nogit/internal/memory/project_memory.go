package memory

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/usewhale/whale/internal/defaults"
)

type ProjectMemory struct {
	Path          string
	Content       string
	OriginalChars int
	Truncated     bool
}

func ReadProjectMemory(workspaceRoot string, fileOrder []string, maxChars int) (ProjectMemory, bool) {
	root := strings.TrimSpace(workspaceRoot)
	if root == "" {
		return ProjectMemory{}, false
	}
	if maxChars <= 0 {
		maxChars = defaults.DefaultMemoryMaxChars
	}
	for _, name := range fileOrder {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		path := filepath.Join(root, name)
		b, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		raw := strings.TrimSpace(string(b))
		if raw == "" {
			return ProjectMemory{}, false
		}
		pm := ProjectMemory{
			Path:          path,
			Content:       raw,
			OriginalChars: len(raw),
		}
		if len(raw) > maxChars {
			pm.Truncated = true
			pm.Content = raw[:maxChars] + "\n... (truncated)"
		}
		return pm, true
	}
	return ProjectMemory{}, false
}
