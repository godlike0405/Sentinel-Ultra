package agent

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestJSONLStoreCreateListUpdate(t *testing.T) {
	dir := t.TempDir()
	store, err := NewJSONLStore(filepath.Join(dir, "sessions"))
	if err != nil {
		t.Fatalf("new store: %v", err)
	}
	ctx := context.Background()

	m1, err := store.Create(ctx, Message{SessionID: "s1", Role: RoleUser, Text: "hi"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if m1.ID == "" {
		t.Fatal("expected message id")
	}

	list, err := store.List(ctx, "s1")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 || list[0].Text != "hi" {
		t.Fatalf("unexpected list: %+v", list)
	}

	m1.Text = "hello"
	if err := store.Update(ctx, m1); err != nil {
		t.Fatalf("update: %v", err)
	}
	list2, err := store.List(ctx, "s1")
	if err != nil {
		t.Fatalf("list2: %v", err)
	}
	if len(list2) != 1 || list2[0].Text != "hello" {
		t.Fatalf("unexpected updated list: %+v", list2)
	}
}

func TestMostRecentSessionID(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	a := filepath.Join(dir, "a.jsonl")
	b := filepath.Join(dir, "b.jsonl")
	if err := os.WriteFile(a, []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	time.Sleep(20 * time.Millisecond)
	if err := os.WriteFile(b, []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err := MostRecentSessionID(dir)
	if err != nil {
		t.Fatalf("recent: %v", err)
	}
	if got != "b" {
		t.Fatalf("expected b, got %s", got)
	}
}

func TestJSONLStoreApprovalPersistence(t *testing.T) {
	dir := t.TempDir()
	store, err := NewJSONLStore(filepath.Join(dir, "sessions"))
	if err != nil {
		t.Fatalf("new store: %v", err)
	}
	ctx := context.Background()
	if err := store.GrantApproval(ctx, "s1", "shell_run|cmd:echo hi"); err != nil {
		t.Fatalf("grant approval: %v", err)
	}
	got, err := store.GetApprovals(ctx, "s1")
	if err != nil {
		t.Fatalf("get approvals: %v", err)
	}
	if !got["shell_run|cmd:echo hi"] {
		t.Fatalf("expected approval key persisted, got: %+v", got)
	}
}
