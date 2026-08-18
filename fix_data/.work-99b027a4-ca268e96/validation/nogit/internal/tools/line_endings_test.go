package tools

import (
	"strings"
	"testing"
)

func TestNormalizeLineEndingsKeepsUniformFilesOnFastPath(t *testing.T) {
	lf := strings.Repeat("alpha\n", 4096)
	normalized, snapshot := normalizeLineEndings(lf)
	if normalized != lf {
		t.Fatal("LF-only content should not be rewritten")
	}
	if snapshot.mixed || snapshot.style != lineEndingLF || len(snapshot.lines) != 0 {
		t.Fatalf("LF snapshot = %+v, want unmixed LF with no per-line snapshot", snapshot)
	}

	crlf := strings.Repeat("alpha\r\n", 4096)
	normalized, snapshot = normalizeLineEndings(crlf)
	if normalized != strings.Repeat("alpha\n", 4096) {
		t.Fatal("CRLF content was not normalized to LF")
	}
	if snapshot.mixed || snapshot.style != lineEndingCRLF || len(snapshot.lines) != 0 {
		t.Fatalf("CRLF snapshot = %+v, want unmixed CRLF with no per-line snapshot", snapshot)
	}
}

func TestRestoreMixedLineEndingsLargeRepeatedBlockInsertionDoesNotShiftSeparators(t *testing.T) {
	const lineCount = 2100
	var before strings.Builder
	for i := 0; i < lineCount; i++ {
		before.WriteString("repeat")
		if i%2 == 0 {
			before.WriteString("\r\n")
		} else {
			before.WriteString("\n")
		}
	}

	normalized, snapshot := normalizeLineEndings(before.String())
	after := "inserted\n" + normalized
	got := restoreLineEndings(after, snapshot)
	want := "inserted\n" + before.String()
	if got != want {
		t.Fatal("large repeated mixed-ending block insertion shifted original separators")
	}
}

func TestRestoreMixedLineEndingsLargeRepeatedBlockInsertionBeyondMyersCap(t *testing.T) {
	const lineCount = 2100
	insertedCount := maxLineEndingMyersEdits + 1
	var before strings.Builder
	for i := 0; i < lineCount; i++ {
		before.WriteString("repeat")
		if i%2 == 0 {
			before.WriteString("\r\n")
		} else {
			before.WriteString("\n")
		}
	}
	var inserted strings.Builder
	for i := 0; i < insertedCount; i++ {
		inserted.WriteString("inserted\n")
	}

	normalized, snapshot := normalizeLineEndings(before.String())
	got := restoreLineEndings(inserted.String()+normalized, snapshot)
	want := inserted.String() + before.String()
	if got != want {
		t.Fatal("large repeated mixed-ending fallback shifted original separators after Myers cap")
	}
}

func TestRestoreMixedLineEndingsDuplicateReplacementKeepsUnchangedSuffix(t *testing.T) {
	normalized, snapshot := normalizeLineEndings("a\r\nb\nc\r\n")
	if normalized != "a\nb\nc\n" {
		t.Fatalf("normalized = %q", normalized)
	}
	got := restoreLineEndings("a\nc\nc\n", snapshot)
	if want := "a\r\nc\nc\r\n"; got != want {
		t.Fatalf("content = %q, want %q", got, want)
	}
}

func TestRestoreMixedLineEndingsLargeDuplicateReplacementKeepsUnchangedSuffix(t *testing.T) {
	const prefixLines = 2098
	var before strings.Builder
	for i := 0; i < prefixLines; i++ {
		before.WriteString("pad\r\n")
	}
	before.WriteString("b\nc\r\n")

	normalized, snapshot := normalizeLineEndings(before.String())
	after := strings.Replace(normalized, "b\nc\n", "c\nc\n", 1)
	got := restoreLineEndings(after, snapshot)

	var want strings.Builder
	for i := 0; i < prefixLines; i++ {
		want.WriteString("pad\r\n")
	}
	want.WriteString("c\nc\r\n")
	if got != want.String() {
		t.Fatal("large duplicate replacement shifted the unchanged suffix separator")
	}
}

func TestRestoreMixedLineEndingsDuplicateAppendKeepsOriginalPrefix(t *testing.T) {
	normalized, snapshot := normalizeLineEndings("a\nc\r\n")
	if normalized != "a\nc\n" {
		t.Fatalf("normalized = %q", normalized)
	}
	got := restoreLineEndings("a\nc\nc\n", snapshot)
	if want := "a\nc\r\nc\n"; got != want {
		t.Fatalf("content = %q, want %q", got, want)
	}
}
