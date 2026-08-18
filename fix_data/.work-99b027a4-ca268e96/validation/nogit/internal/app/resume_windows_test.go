//go:build windows

package app

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
)

func TestMain(m *testing.M) {
	if os.Getenv("WHALE_RESUME_ARGDUMP") == "1" {
		cwd, _ := os.Getwd()
		fmt.Println("cwd=" + cwd)
		for i, arg := range os.Args[1:] {
			fmt.Printf("arg%d=%s\n", i+1, arg)
		}
		os.Exit(0)
	}
	os.Exit(m.Run())
}

func TestResumeCommandWindowsExecutesFromOuterCmd(t *testing.T) {
	root := t.TempDir()
	workspace := filepath.Join(root, `Whale %USERNAME% & Co`, "workspace original")
	binDir := filepath.Join(root, `Program Files`, `Whale %USERNAME% & Co`)
	if err := os.MkdirAll(workspace, 0o755); err != nil {
		t.Fatalf("mkdir workspace: %v", err)
	}
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		t.Fatalf("mkdir bin dir: %v", err)
	}

	exe, err := os.Executable()
	if err != nil {
		t.Fatalf("os.Executable: %v", err)
	}
	bin := filepath.Join(binDir, "whale.exe")
	exeBytes, err := os.ReadFile(exe)
	if err != nil {
		t.Fatalf("read test executable: %v", err)
	}
	if err := os.WriteFile(bin, exeBytes, 0o755); err != nil {
		t.Fatalf("write fake whale executable: %v", err)
	}

	sessionID := `s%USERNAME%&1`
	commandLine := "cmd /v:off /c " + resumeCommandFor("windows", workspace, sessionID, bin)
	cmd := exec.Command("cmd")
	cmd.Env = append(os.Environ(), "WHALE_RESUME_ARGDUMP=1")
	cmd.SysProcAttr = &syscall.SysProcAttr{CmdLine: commandLine}
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("resume command failed: %v\n%s", err, out)
	}
	rendered := string(out)
	if !hasLineEqualFold(rendered, "cwd="+workspace) ||
		!strings.Contains(rendered, "arg1=resume") ||
		!strings.Contains(rendered, "arg2="+sessionID) {
		t.Fatalf("unexpected resume command output:\n%s", rendered)
	}
}

func hasLineEqualFold(output, want string) bool {
	for _, line := range strings.Split(output, "\n") {
		if strings.EqualFold(strings.TrimSpace(line), want) {
			return true
		}
	}
	return false
}
