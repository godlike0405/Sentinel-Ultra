package app

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRunExecReturnsFinalOutput(t *testing.T) {
	t.Setenv("DEEPSEEK_API_KEY", "sk-1234567890abcdef1234")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = fmt.Fprint(w, "data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\n")
		_, _ = fmt.Fprint(w, "data: {\"choices\":[{\"delta\":{\"content\":\" world\"},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":1,\"completion_tokens\":2,\"total_tokens\":3}}\n\n")
		_, _ = fmt.Fprint(w, "data: [DONE]\n\n")
	}))
	defer srv.Close()
	t.Setenv("DEEPSEEK_BASE_URL", srv.URL)

	res, err := RunExec(context.Background(), DefaultConfig(), StartOptions{NewSession: true}, "hi")
	if err != nil {
		t.Fatalf("RunExec: %v", err)
	}
	if res.Status != "completed" {
		t.Fatalf("status = %q", res.Status)
	}
	if res.Output != "hello world" {
		t.Fatalf("output = %q", res.Output)
	}
	if res.SessionID == "" {
		t.Fatal("expected session id")
	}
	if res.Model == "" {
		t.Fatal("expected model")
	}
}
