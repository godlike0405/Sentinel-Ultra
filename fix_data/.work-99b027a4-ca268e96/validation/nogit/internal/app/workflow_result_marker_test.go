package app

import (
	"strings"
	"testing"

	"github.com/usewhale/whale/internal/core"
)

func TestRecordWorkflowResultPersistsHiddenMarkerOnce(t *testing.T) {
	cfg := DefaultConfig()
	cfg.DataDir = t.TempDir()
	app, err := New(t.Context(), cfg, StartOptions{NewSession: true})
	if err != nil {
		t.Fatalf("New: %v", err)
	}

	if err := app.RecordWorkflowResult("run-1", "Dynamic workflow completed\n\nexecutiveSummary: done"); err != nil {
		t.Fatalf("RecordWorkflowResult: %v", err)
	}
	if err := app.RecordWorkflowResult("run-1", "Dynamic workflow completed\n\nexecutiveSummary: done again"); err != nil {
		t.Fatalf("RecordWorkflowResult again: %v", err)
	}

	msgs, err := app.ListMessages()
	if err != nil {
		t.Fatalf("ListMessages: %v", err)
	}
	if len(msgs) != 1 {
		t.Fatalf("expected one workflow result marker, got %+v", msgs)
	}
	msg := msgs[0]
	if msg.Role != core.RoleUser || !msg.Hidden || msg.FinishReason != core.FinishReasonEndTurn {
		t.Fatalf("unexpected marker metadata: %+v", msg)
	}
	for _, want := range []string{"<workflow_result>", "run: run-1", "background workflow completed", "executiveSummary: done"} {
		if !strings.Contains(msg.Text, want) {
			t.Fatalf("marker missing %q:\n%s", want, msg.Text)
		}
	}
	if strings.Contains(msg.Text, "done again") {
		t.Fatalf("duplicate record should not rewrite marker:\n%s", msg.Text)
	}
}
