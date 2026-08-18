package agent

import (
	"context"
	"errors"
	"testing"

	"github.com/usewhale/whale/internal/session"
)

func TestRunStream_BlocksWhenBudgetExceeded(t *testing.T) {
	store := NewInMemoryStore()
	sessionsDir := t.TempDir()
	a := NewAgentWithRegistry(&mockProvider{}, store, nil,
		WithSessionsDir(sessionsDir),
		WithBudgetWarningUSD(1.0),
	)
	if err := session.SaveSessionMeta(sessionsDir, "s-budget", session.SessionMeta{TotalCostUSD: 1.2}); err != nil {
		t.Fatalf("save meta: %v", err)
	}
	_, err := a.RunStream(context.Background(), "s-budget", "hi")
	if err == nil {
		t.Fatalf("expected budget exceeded error")
	}
	if !errors.Is(err, ErrBudgetExceeded) {
		t.Fatalf("expected ErrBudgetExceeded, got: %v", err)
	}
}
