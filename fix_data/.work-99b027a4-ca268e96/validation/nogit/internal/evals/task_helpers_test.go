package evals

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/usewhale/whale/internal/core"
	"github.com/usewhale/whale/internal/session"
)

func todoStateForRun(run *Run) (session.TodoState, error) {
	return session.LoadTodoState(filepath.Join(run.Root, ".sessions"), run.SessionID)
}

func todoIDFromHistory(history []core.Message) (string, error) {
	for i := len(history) - 1; i >= 0; i-- {
		msg := history[i]
		if msg.Role != core.RoleTool {
			continue
		}
		for _, tr := range msg.ToolResults {
			if !strings.HasPrefix(tr.Name, "todo_") {
				continue
			}
			var payload struct {
				Success bool `json:"success"`
				Data    struct {
					Items []session.TodoItem `json:"items"`
				} `json:"data"`
			}
			if err := json.Unmarshal([]byte(tr.Content), &payload); err != nil {
				continue
			}
			if len(payload.Data.Items) > 0 && payload.Data.Items[0].ID != "" {
				return payload.Data.Items[0].ID, nil
			}
		}
	}
	return "", fmt.Errorf("todo id not found in history")
}
