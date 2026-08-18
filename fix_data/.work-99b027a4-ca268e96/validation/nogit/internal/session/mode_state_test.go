package session

import "testing"

func TestModeStateSaveLoad(t *testing.T) {
	dir := t.TempDir()
	if err := SaveModeState(dir, "s1", ModePlan); err != nil {
		t.Fatalf("save mode failed: %v", err)
	}
	st, err := LoadModeState(dir, "s1")
	if err != nil {
		t.Fatalf("load mode failed: %v", err)
	}
	if st.Mode != ModePlan {
		t.Fatalf("expected plan mode, got %s", st.Mode)
	}
}

func TestModeStateSaveLoadAsk(t *testing.T) {
	dir := t.TempDir()
	if err := SaveModeState(dir, "s1", ModeAsk); err != nil {
		t.Fatalf("save mode failed: %v", err)
	}
	st, err := LoadModeState(dir, "s1")
	if err != nil {
		t.Fatalf("load mode failed: %v", err)
	}
	if st.Mode != ModeAsk {
		t.Fatalf("expected ask mode, got %s", st.Mode)
	}
}

func TestModeStateDefaultAgentWhenMissing(t *testing.T) {
	dir := t.TempDir()
	st, err := LoadModeState(dir, "missing")
	if err != nil {
		t.Fatalf("load mode failed: %v", err)
	}
	if st.Mode != ModeAgent {
		t.Fatalf("expected default agent mode, got %s", st.Mode)
	}
}
