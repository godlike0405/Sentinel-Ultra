package session

import (
	"testing"

	"github.com/usewhale/whale/internal/core"
)

func TestUserInputStateRoundTrip(t *testing.T) {
	dir := t.TempDir()
	in := UserInputState{
		Pending:    true,
		ToolCallID: "tc-1",
		Questions: []core.UserInputQuestion{
			{
				Header:   "Mode",
				ID:       "mode",
				Question: "Pick mode",
				Options: []core.UserInputOption{
					{Label: "A", Description: "a"},
					{Label: "B", Description: "b"},
				},
			},
		},
	}
	if err := SaveUserInputState(dir, "s1", in); err != nil {
		t.Fatalf("save user input state: %v", err)
	}
	got, err := LoadUserInputState(dir, "s1")
	if err != nil {
		t.Fatalf("load user input state: %v", err)
	}
	if !got.Pending || got.ToolCallID != "tc-1" || len(got.Questions) != 1 {
		t.Fatalf("unexpected user input state: %+v", got)
	}
	if err := ClearUserInputState(dir, "s1"); err != nil {
		t.Fatalf("clear user input state: %v", err)
	}
	got2, err := LoadUserInputState(dir, "s1")
	if err != nil {
		t.Fatalf("reload user input state: %v", err)
	}
	if got2.Pending || got2.ToolCallID != "" {
		t.Fatalf("expected empty user input state after clear: %+v", got2)
	}
}
