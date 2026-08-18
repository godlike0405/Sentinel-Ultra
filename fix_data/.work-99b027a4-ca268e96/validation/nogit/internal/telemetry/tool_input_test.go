package telemetry

import (
	"bufio"
	"encoding/json"
	"os"
	"testing"
	"time"
)

func TestAppendToolInputEventWritesSessionSidecar(t *testing.T) {
	dir := t.TempDir()
	now := time.UnixMilli(1234567890)
	err := AppendToolInputEvent(dir, ToolInputEvent{
		Session:            "s/1",
		Model:              "deepseek-v4-pro",
		AssistantMessageID: "m-2",
		ToolCallID:         "tc-1",
		Tool:               "read_file",
		Event:              "tool_input_repaired",
		RepairKind:         "renest_flat_input",
	}, now)
	if err != nil {
		t.Fatalf("append tool input event: %v", err)
	}

	path := ToolInputEventsPath(dir, "s/1")
	f, err := os.Open(path)
	if err != nil {
		t.Fatalf("open sidecar: %v", err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	if !scanner.Scan() {
		t.Fatal("expected one event line")
	}
	var got ToolInputEvent
	if err := json.Unmarshal(scanner.Bytes(), &got); err != nil {
		t.Fatalf("unmarshal event: %v", err)
	}
	if got.TS != now.UnixMilli() || got.Session != "s/1" || got.ToolCallID != "tc-1" || got.RepairKind != "renest_flat_input" {
		t.Fatalf("unexpected event: %+v", got)
	}
	var raw map[string]any
	if err := json.Unmarshal(scanner.Bytes(), &raw); err != nil {
		t.Fatalf("unmarshal raw event: %v", err)
	}
	if _, ok := raw["input"]; ok {
		t.Fatalf("raw input must not be logged: %v", raw)
	}
}

func TestAppendToolInputEventNoopsWithoutSessionOrEvent(t *testing.T) {
	dir := t.TempDir()
	if err := AppendToolInputEvent(dir, ToolInputEvent{Event: "tool_input_repaired"}, time.Now()); err != nil {
		t.Fatalf("empty session should be a no-op: %v", err)
	}
	if err := AppendToolInputEvent(dir, ToolInputEvent{Session: "s1"}, time.Now()); err != nil {
		t.Fatalf("empty event should be a no-op: %v", err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("read dir: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("expected no files, got %d", len(entries))
	}
}
