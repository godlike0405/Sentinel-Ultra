package tools

import (
	"fmt"
	"strings"
)

const (
	fileDiffMetadataKind     = "file_diff"
	fileDiffMetadataMaxBytes = 200 * 1024
	fileDiffContextLines     = 3
)

type fileChangePreview struct {
	path   string
	before string
	after  string
}

func fileDiffMetadata(changes []fileChangePreview) map[string]any {
	files := make([]map[string]any, 0, len(changes))
	totalBytes := 0
	anyTruncated := false
	for _, change := range changes {
		diff, additions, deletions := unifiedDiff(change.path, change.before, change.after)
		if strings.TrimSpace(diff) == "" {
			continue
		}
		truncated := false
		remaining := fileDiffMetadataMaxBytes - totalBytes
		if remaining <= 0 {
			diff = ""
			truncated = true
		} else if len(diff) > remaining {
			diff = truncateDiffText(diff, remaining)
			truncated = true
		}
		totalBytes += len(diff)
		if truncated {
			anyTruncated = true
		}
		files = append(files, map[string]any{
			"path":         change.path,
			"unified_diff": diff,
			"additions":    additions,
			"deletions":    deletions,
			"truncated":    truncated,
		})
	}
	if len(files) == 0 {
		return nil
	}
	return map[string]any{
		"kind":      fileDiffMetadataKind,
		"files":     files,
		"truncated": anyTruncated,
	}
}

func fileDiffCounts(changes []fileChangePreview) (int, int) {
	additions := 0
	deletions := 0
	for _, change := range changes {
		_, add, del := unifiedDiff(change.path, change.before, change.after)
		additions += add
		deletions += del
	}
	return additions, deletions
}

func fileDiffPreviewError(err error) map[string]any {
	if err == nil {
		return nil
	}
	return map[string]any{
		"kind":          fileDiffMetadataKind,
		"preview_error": err.Error(),
	}
}

func unifiedDiff(path, before, after string) (string, int, int) {
	oldLines := splitDiffLines(before)
	newLines := splitDiffLines(after)
	if linesEqual(oldLines, newLines) {
		return "", 0, 0
	}

	prefix := commonPrefix(oldLines, newLines)
	suffix := commonSuffix(oldLines[prefix:], newLines[prefix:])
	oldChangeEnd := len(oldLines) - suffix
	newChangeEnd := len(newLines) - suffix
	contextStart := diffMaxInt(0, prefix-fileDiffContextLines)
	oldContextEnd := diffMinInt(len(oldLines), oldChangeEnd+fileDiffContextLines)
	newContextEnd := diffMinInt(len(newLines), newChangeEnd+fileDiffContextLines)
	additions := newChangeEnd - prefix
	deletions := oldChangeEnd - prefix

	var b strings.Builder
	b.WriteString("--- a/")
	b.WriteString(path)
	b.WriteString("\n+++ b/")
	b.WriteString(path)
	b.WriteString("\n")
	b.WriteString(fmt.Sprintf("@@ -%s +%s @@\n",
		diffRange(contextStart, oldContextEnd-contextStart, len(oldLines)),
		diffRange(contextStart, newContextEnd-contextStart, len(newLines)),
	))

	for _, line := range oldLines[contextStart:prefix] {
		b.WriteString(" ")
		b.WriteString(line)
		b.WriteString("\n")
	}
	for _, line := range oldLines[prefix:oldChangeEnd] {
		b.WriteString("-")
		b.WriteString(line)
		b.WriteString("\n")
	}
	for _, line := range newLines[prefix:newChangeEnd] {
		b.WriteString("+")
		b.WriteString(line)
		b.WriteString("\n")
	}
	for _, line := range oldLines[len(oldLines)-suffix : oldContextEnd] {
		b.WriteString(" ")
		b.WriteString(line)
		b.WriteString("\n")
	}
	return strings.TrimRight(b.String(), "\n"), additions, deletions
}

func splitDiffLines(s string) []string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	if s == "" {
		return nil
	}
	s = strings.TrimSuffix(s, "\n")
	if s == "" {
		return []string{""}
	}
	return strings.Split(s, "\n")
}

func linesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func commonPrefix(a, b []string) int {
	n := diffMinInt(len(a), len(b))
	for i := 0; i < n; i++ {
		if a[i] != b[i] {
			return i
		}
	}
	return n
}

func commonSuffix(a, b []string) int {
	n := diffMinInt(len(a), len(b))
	for i := 0; i < n; i++ {
		if a[len(a)-1-i] != b[len(b)-1-i] {
			return i
		}
	}
	return n
}

func diffRange(start, length, total int) string {
	if total == 0 {
		return "0,0"
	}
	line := start + 1
	if length == 1 {
		return fmt.Sprintf("%d", line)
	}
	return fmt.Sprintf("%d,%d", line, length)
}

func truncateDiffText(s string, maxBytes int) string {
	if maxBytes <= 0 {
		return "... diff truncated ..."
	}
	suffix := "\n... diff truncated ..."
	if maxBytes <= len(suffix) {
		return suffix[len(suffix)-maxBytes:]
	}
	limit := maxBytes - len(suffix)
	if len(s) <= limit {
		return s
	}
	return strings.TrimRight(s[:limit], "\n") + suffix
}

func diffMinInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func diffMaxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
