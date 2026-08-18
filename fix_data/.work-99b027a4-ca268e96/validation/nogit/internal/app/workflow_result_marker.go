package app

import (
	"context"
	"fmt"
	"strings"

	"github.com/usewhale/whale/internal/core"
)

func (a *App) RecordWorkflowResult(runID, text string) error {
	runID = strings.TrimSpace(runID)
	text = strings.TrimSpace(text)
	if a == nil || a.msgStore == nil || runID == "" || text == "" {
		return nil
	}
	messages, err := a.msgStore.List(context.Background(), a.sessionID)
	if err != nil {
		return fmt.Errorf("list messages for workflow result marker: %w", err)
	}
	if workflowResultAlreadyRecorded(messages, runID) {
		return nil
	}
	_, err = a.msgStore.Create(context.Background(), core.Message{
		SessionID:    a.sessionID,
		Role:         core.RoleUser,
		Text:         workflowResultMarkerText(runID, text),
		Hidden:       true,
		FinishReason: core.FinishReasonEndTurn,
	})
	if err != nil {
		return fmt.Errorf("record workflow result marker: %w", err)
	}
	return nil
}

func workflowResultMarkerText(runID, text string) string {
	return "<workflow_result>\nrun: " + strings.TrimSpace(runID) + "\n\nThe background workflow completed. Treat this as the authoritative workflow result for later user questions about this run.\n\n" + strings.TrimSpace(text) + "\n</workflow_result>"
}

func workflowResultAlreadyRecorded(messages []core.Message, runID string) bool {
	want := "run: " + strings.TrimSpace(runID)
	for _, msg := range messages {
		if msg.Hidden && strings.Contains(msg.Text, "<workflow_result>") && strings.Contains(msg.Text, want) {
			return true
		}
	}
	return false
}
