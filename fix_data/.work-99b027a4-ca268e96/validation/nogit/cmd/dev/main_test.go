package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestDefaultBinPathUsesWindowsExecutableSuffix(t *testing.T) {
	if got := defaultBinPath("windows"); got != filepath.Join("bin", "whale.exe") {
		t.Fatalf("windows bin = %q", got)
	}
	if got := defaultBinPath("linux"); got != filepath.Join("bin", "whale") {
		t.Fatalf("linux bin = %q", got)
	}
}

func TestAppendEnvReplacesExistingValue(t *testing.T) {
	got := appendEnv([]string{"A=1", "GOCACHE=old"}, "GOCACHE", "new")
	want := []string{"A=1", "GOCACHE=new"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("env = %#v, want %#v", got, want)
	}
}

func TestGoFilesSkipsGeneratedLocalStateDirs(t *testing.T) {
	root := t.TempDir()
	write := func(path string) {
		t.Helper()
		abs := filepath.Join(root, path)
		if err := os.MkdirAll(filepath.Dir(abs), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(abs, []byte("package main\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("cmd/dev/main.go")
	write(filepath.Join(".gocache", "ignored.go"))
	write(filepath.Join("bin", "ignored.go"))

	got, err := goFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{filepath.Join("cmd", "dev", "main.go")}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("files = %#v, want %#v", got, want)
	}
}

func TestPathWithin(t *testing.T) {
	root := filepath.Clean("/repo")
	if !pathWithin(root, filepath.Join(root, ".gocache")) {
		t.Fatal("expected repo-local cache to be inside root")
	}
	if pathWithin(root, filepath.Clean("/tmp/cache")) {
		t.Fatal("expected external cache to be outside root")
	}
}
