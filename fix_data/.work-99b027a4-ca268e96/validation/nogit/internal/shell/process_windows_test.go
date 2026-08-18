//go:build windows

package shell

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestWindowsRunCommandKillsProcessTree(t *testing.T) {
	dir := t.TempDir()
	readyPath := filepath.Join(dir, "ready")
	markerPath := filepath.Join(dir, "marker")

	ctx, cancel := context.WithCancel(context.Background())
	cmd := exec.Command(os.Args[0], "-test.run=TestWindowsProcessTreeHelper")
	cmd.Env = append(os.Environ(),
		"WHALE_PROCESS_TREE_HELPER=parent",
		"WHALE_PROCESS_TREE_READY="+readyPath,
		"WHALE_PROCESS_TREE_MARKER="+markerPath,
	)
	done := make(chan error, 1)
	go func() {
		done <- RunCommand(ctx, cmd)
	}()
	waitForFile(t, readyPath, 2*time.Second)
	childPIDBytes, err := os.ReadFile(readyPath)
	if err != nil {
		t.Fatalf("read child pid: %v", err)
	}
	childPID := strings.TrimSpace(string(childPIDBytes))
	if childPID == "" {
		t.Fatal("helper did not write child pid")
	}

	cancel()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("helper process did not exit promptly after cancel")
	}
	time.Sleep(300 * time.Millisecond)

	if windowsPIDExists(t, childPID) {
		t.Fatalf("descendant process %s survived cancellation", childPID)
	}
}

func TestWindowsRunCommandKeepsLaunchedChildOnSuccess(t *testing.T) {
	dir := t.TempDir()
	markerPath := filepath.Join(dir, "marker")

	cmd := exec.Command(os.Args[0], "-test.run=TestWindowsProcessTreeHelper")
	cmd.Env = append(os.Environ(),
		"WHALE_PROCESS_TREE_HELPER=success-parent",
		"WHALE_PROCESS_TREE_MARKER="+markerPath,
	)
	if err := RunCommand(context.Background(), cmd); err != nil {
		t.Fatalf("run helper: %v", err)
	}

	waitForFile(t, markerPath, 3*time.Second)
}

func TestWindowsCancelCommandTreeAndJobKeepsTreeFallback(t *testing.T) {
	oldKill := killCommandTreeFunc
	oldTerminate := terminateJobFunc
	t.Cleanup(func() {
		killCommandTreeFunc = oldKill
		terminateJobFunc = oldTerminate
	})

	fakeCmd := &exec.Cmd{}
	fakeJob := syscall.Handle(123)
	calls := []string{}
	treeErr := errors.New("tree failed")
	killCommandTreeFunc = func(cmd *exec.Cmd) error {
		if cmd != fakeCmd {
			t.Fatalf("unexpected command pointer: %p", cmd)
		}
		calls = append(calls, "tree")
		return treeErr
	}
	terminateJobFunc = func(job syscall.Handle) error {
		if job != fakeJob {
			t.Fatalf("unexpected job handle: %v", job)
		}
		calls = append(calls, "job")
		return nil
	}

	err := cancelCommandTreeAndJob(fakeCmd, fakeJob)
	if !errors.Is(err, treeErr) {
		t.Fatalf("expected tree error, got %v", err)
	}
	if len(calls) != 2 || calls[0] != "tree" || calls[1] != "job" {
		t.Fatalf("expected tree fallback before job termination, got %v", calls)
	}
}

func TestWindowsProcessTreeHelper(t *testing.T) {
	switch os.Getenv("WHALE_PROCESS_TREE_HELPER") {
	case "parent":
		markerPath := os.Getenv("WHALE_PROCESS_TREE_MARKER")
		readyPath := os.Getenv("WHALE_PROCESS_TREE_READY")
		cmd := exec.Command(os.Args[0], "-test.run=TestWindowsProcessTreeHelper")
		cmd.Env = append(os.Environ(),
			"WHALE_PROCESS_TREE_HELPER=child",
			"WHALE_PROCESS_TREE_MARKER="+markerPath,
		)
		if err := cmd.Start(); err != nil {
			os.Exit(2)
		}
		if err := os.WriteFile(readyPath, []byte(strconv.Itoa(cmd.Process.Pid)), 0o644); err != nil {
			os.Exit(3)
		}
		time.Sleep(10 * time.Second)
		os.Exit(0)
	case "success-parent":
		markerPath := os.Getenv("WHALE_PROCESS_TREE_MARKER")
		time.Sleep(700 * time.Millisecond)
		cmd := exec.Command(os.Args[0], "-test.run=TestWindowsProcessTreeHelper")
		cmd.Env = append(os.Environ(),
			"WHALE_PROCESS_TREE_HELPER=success-child",
			"WHALE_PROCESS_TREE_MARKER="+markerPath,
		)
		if err := cmd.Start(); err != nil {
			os.Exit(5)
		}
		os.Exit(0)
	case "success-child":
		time.Sleep(700 * time.Millisecond)
		if err := os.WriteFile(os.Getenv("WHALE_PROCESS_TREE_MARKER"), []byte("survived"), 0o644); err != nil {
			os.Exit(6)
		}
		os.Exit(0)
	case "child":
		time.Sleep(time.Second)
		if err := os.WriteFile(os.Getenv("WHALE_PROCESS_TREE_MARKER"), []byte("alive"), 0o644); err != nil {
			os.Exit(4)
		}
		os.Exit(0)
	}
}

func windowsPIDExists(t *testing.T, pid string) bool {
	t.Helper()
	out, err := exec.Command("tasklist", "/FI", "PID eq "+pid, "/FO", "CSV", "/NH").CombinedOutput()
	if err != nil {
		t.Fatalf("tasklist failed: %v\n%s", err, string(out))
	}
	return strings.Contains(string(out), `"`+pid+`"`)
}

func waitForFile(t *testing.T, path string, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", path)
}
