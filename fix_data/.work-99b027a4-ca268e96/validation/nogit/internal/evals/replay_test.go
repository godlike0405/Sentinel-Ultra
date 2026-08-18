package evals

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRecordRoundTripPreservesStepIdentity(t *testing.T) {
	recordPath := filepath.Join(t.TempDir(), "roundtrip.jsonl")
	run, err := RunTask(context.Background(), TaskSpec{
		ID:    "record-roundtrip",
		Suite: SuiteCapability,
		Scenario: ScenarioSpec{
			RecordPath: recordPath,
			Turns: []TurnSpec{
				{
					Steps: []StepSpec{
						{ID: "write", ToolName: "write", Input: `{"file_path":"docs/a.txt","content":"hello\n"}`},
						{ID: "read", ToolName: "read_file", Input: `{"file_path":"docs/a.txt","offset":0,"limit":20}`},
					},
				},
			},
		},
	})
	if err != nil {
		t.Fatalf("run task: %v", err)
	}
	entries, err := ReadRecord(recordPath)
	if err != nil {
		t.Fatalf("read record: %v", err)
	}
	if len(entries) != len(run.Steps) {
		t.Fatalf("expected %d entries, got %d", len(run.Steps), len(entries))
	}
	if entries[0].StepID != "write" || entries[1].StepID != "read" {
		t.Fatalf("unexpected step ids: %+v", entries)
	}
	if entries[0].Suite != SuiteCapability {
		t.Fatalf("unexpected suite: %s", entries[0].Suite)
	}
}

func TestDiffRecordsDetectsToolAndInputChange(t *testing.T) {
	left := []RecordEntry{
		{StepID: "mutate", Tool: "edit", Input: `{"file_path":"a.txt","search":"old","replace":"new"}`, ResultDigest: "ok"},
	}
	right := []RecordEntry{
		{StepID: "mutate", Tool: "write", Input: `{"file_path":"a.txt","content":"new"}`, ResultDigest: "ok"},
	}
	diff := DiffRecords(left, right)
	if diff.Equal {
		t.Fatal("expected diff to detect tool/input change")
	}
	joined := strings.Join(diff.Differences, "\n")
	if !strings.Contains(joined, "tool: edit != write") || !strings.Contains(joined, "input:") {
		t.Fatalf("unexpected diff output: %s", joined)
	}
}

func TestDiffRecordsDetectsEnvelopeChange(t *testing.T) {
	left := []RecordEntry{
		{StepID: "wait", Tool: "shell_wait", EnvelopeCode: "running", ResultDigest: "still running"},
	}
	right := []RecordEntry{
		{StepID: "wait", Tool: "shell_wait", EnvelopeCode: "not_found", ResultDigest: "task not found"},
	}
	diff := DiffRecords(left, right)
	if diff.Equal {
		t.Fatal("expected diff to detect envelope change")
	}
	joined := strings.Join(diff.Differences, "\n")
	if !strings.Contains(joined, "envelope_code: running != not_found") {
		t.Fatalf("unexpected diff output: %s", joined)
	}
}

func TestFailureKindFromVerificationError(t *testing.T) {
	_, err := RunTask(context.Background(), TaskSpec{
		ID:    "verification-failure",
		Suite: SuiteRegression,
		Scenario: ScenarioSpec{
			Turns: []TurnSpec{
				{
					Steps: []StepSpec{
						{ID: "write", ToolName: "write", Input: `{"file_path":"a.txt","content":"hello\n"}`},
					},
				},
			},
			Verify: func(run *Run) error {
				return os.ErrNotExist
			},
		},
	})
	if err == nil {
		t.Fatal("expected task failure")
	}
	if got := FailureKindFromError(err); got != FailureKindVerification {
		t.Fatalf("expected verification failure kind, got %s", got)
	}
}

func TestDiffRunAgainstRecordMatchesEquivalentRun(t *testing.T) {
	recordPath := filepath.Join(t.TempDir(), "baseline.jsonl")
	spec := TaskSpec{
		ID:    "baseline-compare",
		Suite: SuiteCapability,
		Scenario: ScenarioSpec{
			RecordPath: recordPath,
			Turns: []TurnSpec{
				{
					Steps: []StepSpec{
						{ID: "write", ToolName: "write", Input: `{"file_path":"docs/b.txt","content":"compare\n"}`},
						{ID: "read", ToolName: "read_file", Input: `{"file_path":"docs/b.txt","offset":0,"limit":20}`},
					},
				},
			},
		},
	}
	if _, err := RunTask(context.Background(), spec); err != nil {
		t.Fatalf("baseline run: %v", err)
	}
	run, err := RunTask(context.Background(), TaskSpec{
		ID:    spec.ID,
		Suite: spec.Suite,
		Scenario: ScenarioSpec{
			Turns: spec.Scenario.Turns,
		},
	})
	if err != nil {
		t.Fatalf("comparison run: %v", err)
	}
	diff, err := DiffRunAgainstRecord(recordPath, run)
	if err != nil {
		t.Fatalf("diff run against record: %v", err)
	}
	if !diff.Equal {
		t.Fatalf("expected normalized run diff to match baseline, got %v", diff.Differences)
	}
}

func TestDiffRecordsDetectsStepCountDrift(t *testing.T) {
	left := []RecordEntry{
		{StepID: "write", Tool: "write", ResultDigest: "ok"},
		{StepID: "read", Tool: "read_file", ResultDigest: "ok"},
	}
	right := []RecordEntry{
		{StepID: "write", Tool: "write", ResultDigest: "ok"},
	}
	diff := DiffRecords(left, right)
	if diff.Equal {
		t.Fatal("expected diff to detect step count drift")
	}
	if !strings.Contains(strings.Join(diff.Differences, "\n"), "step_count: 2 != 1") {
		t.Fatalf("unexpected diff output: %v", diff.Differences)
	}
}

func TestDiffRecordsDetectsResultDigestOnlyDrift(t *testing.T) {
	left := []RecordEntry{
		{StepID: "wait", Tool: "shell_wait", EnvelopeCode: "exited", ResultDigest: "stdout alpha"},
	}
	right := []RecordEntry{
		{StepID: "wait", Tool: "shell_wait", EnvelopeCode: "exited", ResultDigest: "stdout beta"},
	}
	diff := DiffRecords(left, right)
	if diff.Equal {
		t.Fatal("expected diff to detect result digest drift")
	}
	if !strings.Contains(strings.Join(diff.Differences, "\n"), "result_digest: stdout alpha != stdout beta") {
		t.Fatalf("unexpected diff output: %v", diff.Differences)
	}
}
