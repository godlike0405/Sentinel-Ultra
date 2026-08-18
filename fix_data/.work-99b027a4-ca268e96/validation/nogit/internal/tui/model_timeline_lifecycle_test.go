package tui

import (
	"strings"
	"testing"

	"github.com/usewhale/whale/internal/runtime/protocol"
	tuirender "github.com/usewhale/whale/internal/tui/render"
)

func TestTimelineRendersHookLifecycleNotice(t *testing.T) {
	m := newModel(nil, "", "", "")
	next, _ := m.Update(svcMsg(protocol.Event{
		Kind: protocol.EventHookStarted,
		Hook: &protocol.HookRun{ID: "hook-1", Name: "approval gate", Status: "running"},
		Text: "PermissionRequest hook running",
	}))
	m = next.(model)
	if !m.hasPendingLifecycleItems() {
		t.Fatal("hook started should keep lifecycle pending")
	}

	next, _ = m.Update(svcMsg(protocol.Event{
		Kind: protocol.EventHookCompleted,
		Hook: &protocol.HookRun{ID: "hook-1", Name: "approval gate", Status: "blocked", Message: "blocked by policy"},
		Text: "PermissionRequest hook blocked: blocked by policy",
	}))
	m = next.(model)

	rendered := strings.Join(tuirender.ChatLines(m.transcript, 100), "\n")
	if !strings.Contains(rendered, "PermissionRequest hook blocked") || strings.Contains(rendered, "hook running") {
		t.Fatalf("expected completed hook notice from timeline:\n%s", rendered)
	}
	if m.hasPendingLifecycleItems() {
		t.Fatal("hook completion should clear lifecycle pending state")
	}
}

func TestTimelineRendersUserInputLifecycle(t *testing.T) {
	m := newModel(nil, "", "", "")
	next, _ := m.Update(svcMsg(protocol.Event{
		Kind:       protocol.EventUserInputRequired,
		ToolCallID: "input-1",
		ToolName:   "request_user_input",
		Questions:  []protocol.UserInputQuestion{{ID: "confirm", Question: "Proceed?"}},
	}))
	m = next.(model)
	live := strings.Join(tuirender.ChatLines(m.liveTranscriptMessages(), 100), "\n")
	if !strings.Contains(live, "User input required") || !m.hasPendingLifecycleItems() {
		t.Fatalf("expected pending user input live row:\n%s", live)
	}

	next, _ = m.Update(svcMsg(protocol.Event{Kind: protocol.EventUserInputDone, ToolCallID: "input-1", ToolName: "request_user_input", Status: "submitted"}))
	m = next.(model)
	rendered := strings.Join(tuirender.ChatLines(m.transcript, 100), "\n")
	if !strings.Contains(rendered, "User input submitted") || m.hasPendingLifecycleItems() {
		t.Fatalf("expected committed user input done notice:\n%s", rendered)
	}
}

func TestTimelineRendersWorkflowResultAfterSnapshot(t *testing.T) {
	m := newModel(nil, "", "", "")
	next, _ := m.Update(svcMsg(protocol.Event{
		Kind:          protocol.EventWorkflowSnapshot,
		WorkflowRunID: "run-1",
		Status:        "running",
		LocalResult: &protocol.LocalResult{Kind: "workflow", WorkflowPanelSnapshot: &protocol.WorkflowPanelSnapshot{
			RunID:        "run-1",
			Status:       "running",
			Summary:      "reviewing repo",
			CurrentPhase: "inspect",
		}},
	}))
	m = next.(model)
	live := strings.Join(tuirender.ChatLines(m.liveTranscriptMessages(), 100), "\n")
	if strings.Contains(live, "Workflow") || strings.Contains(live, "run-1") || m.hasPendingLifecycleItems() {
		t.Fatalf("running workflow snapshot should not render a chat lifecycle row:\n%s", live)
	}

	next, _ = m.Update(svcMsg(protocol.Event{
		Kind:          protocol.EventWorkflowResult,
		WorkflowRunID: "run-1",
		Text:          "Workflow\n\nexecutiveSummary: visible final result",
		LocalResult: &protocol.LocalResult{Kind: "workflow-terminal", PlainText: "Workflow\n\nexecutiveSummary: visible final result", WorkflowPanelSnapshot: &protocol.WorkflowPanelSnapshot{
			RunID:   "run-1",
			Status:  "completed",
			Summary: "done",
		}},
	}))
	m = next.(model)
	if len(m.transcript) != 1 {
		t.Fatalf("expected one committed workflow lifecycle row, got %+v", m.transcript)
	}
	if msg := m.transcript[0]; msg.Role != "assistant" || !strings.Contains(msg.Text, "executiveSummary") || !strings.Contains(msg.Text, "Workflow") {
		t.Fatalf("workflow result should commit final result, got %+v", msg)
	}
}

func TestWorkflowSnapshotPrunesReasoningOnlyFallbackWithoutRenderingSnapshot(t *testing.T) {
	m := newModel(nil, "", "", "")
	m.sawTerminalToolOutcomeThisTurn = true
	m.appendStatus("The model returned reasoning only and did not produce a visible answer. Ask it to answer directly or retry the last step.")
	m.commitLiveTranscript(false)

	next, _ := m.Update(svcMsg(protocol.Event{
		Kind:          protocol.EventWorkflowSnapshot,
		WorkflowRunID: "run-1",
		Status:        "running",
		Text:          "workflow running",
		LocalResult: &protocol.LocalResult{Kind: "workflow", WorkflowPanelSnapshot: &protocol.WorkflowPanelSnapshot{
			RunID:   "run-1",
			Status:  "running",
			Summary: "workflow running",
		}},
	}))
	m = next.(model)

	rendered := strings.Join(tuirender.ChatLines(m.chatMessages(), 100), "\n")
	if strings.Contains(rendered, "Reasoning only") || strings.Contains(rendered, "Workflow · run-1") || strings.Contains(rendered, "workflow running") {
		t.Fatalf("workflow snapshot should prune fallback without rendering a chat row:\n%s", rendered)
	}
	if m.status != "workflow" {
		t.Fatalf("workflow snapshot should keep workflow status, got %q", m.status)
	}
}

func TestAsyncWorkflowSnapshotDoesNotSuppressUnrelatedReasoningOnlyFallback(t *testing.T) {
	m := model{assembler: tuirender.NewAssembler(), mode: modeChat, width: 100, height: 24, busy: true}
	next, _ := m.Update(svcMsg(protocol.Event{Kind: protocol.EventReasoningDelta, Text: "I should answer."}))
	m = next.(model)
	next, _ = m.Update(svcMsg(protocol.Event{
		Kind:          protocol.EventWorkflowSnapshot,
		WorkflowRunID: "run-background",
		Status:        "running",
		Text:          "background workflow running",
		LocalResult: &protocol.LocalResult{Kind: "workflow", WorkflowPanelSnapshot: &protocol.WorkflowPanelSnapshot{
			RunID:   "run-background",
			Status:  "running",
			Summary: "background workflow running",
		}},
	}))
	m = next.(model)
	next, _ = m.Update(svcMsg(protocol.Event{Kind: protocol.EventTurnDone}))
	m = next.(model)

	rendered := strings.Join(tuirender.ChatLines(m.transcript, 100), "\n")
	if !strings.Contains(rendered, "Reasoning only") || !strings.Contains(rendered, "did not produce a visible answer") {
		t.Fatalf("background workflow snapshot should not suppress unrelated reasoning-only fallback:\n%s", rendered)
	}
	if strings.Contains(rendered, "Workflow · run-background") || strings.Contains(rendered, "background workflow running") {
		t.Fatalf("background workflow snapshot should not render a chat row:\n%s", rendered)
	}
}

func TestWorkflowResultPrunesReasoningOnlyFallback(t *testing.T) {
	m := newModel(nil, "", "", "")
	m.appendStatus("The model returned reasoning only and did not produce a visible answer. Ask it to answer directly or retry the last step.")
	m.commitLiveTranscript(false)

	next, _ := m.Update(svcMsg(protocol.Event{
		Kind:          protocol.EventWorkflowResult,
		WorkflowRunID: "run-1",
		Text:          "Workflow\n\nexecutiveSummary: visible final result",
		LocalResult: &protocol.LocalResult{Kind: "workflow-terminal", PlainText: "Workflow\n\nexecutiveSummary: visible final result", WorkflowPanelSnapshot: &protocol.WorkflowPanelSnapshot{
			RunID:   "run-1",
			Status:  "completed",
			Summary: "done",
		}},
	}))
	m = next.(model)

	rendered := strings.Join(tuirender.ChatLines(m.transcript, 100), "\n")
	if strings.Contains(rendered, "Reasoning only") || strings.Contains(rendered, "did not produce a visible answer") {
		t.Fatalf("workflow result should prune reasoning-only fallback:\n%s", rendered)
	}
	if len(m.transcript) != 1 || !strings.Contains(m.transcript[0].Text, "executiveSummary") {
		t.Fatalf("workflow result should remain in transcript: %+v", m.transcript)
	}
}
