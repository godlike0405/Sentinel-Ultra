package tools

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

const (
	maxToolTextChars  = 12000
	maxViewLineChars  = 1000
	maxSummarySamples = 5
)

type truncationMeta struct {
	Truncated bool `json:"truncated"`
	Original  int  `json:"original_chars"`
	Kept      int  `json:"kept_chars"`
	Omitted   int  `json:"omitted_chars"`
}

func truncateTextSmart(s string, limit int) (string, truncationMeta) {
	if limit <= 0 {
		limit = maxToolTextChars
	}
	runes := []rune(s)
	if len(runes) <= limit {
		return s, truncationMeta{Truncated: false, Original: len(runes), Kept: len(runes)}
	}

	headLen := limit * 2 / 3
	tailLen := limit - headLen
	head := string(runes[:headLen])
	tail := string(runes[len(runes)-tailLen:])
	out := fmt.Sprintf("%s\n...[%d chars omitted]...\n%s", head, len(runes)-limit, tail)
	return out, truncationMeta{
		Truncated: true,
		Original:  len(runes),
		Kept:      utf8.RuneCountInString(out),
		Omitted:   len(runes) - limit,
	}
}

func summarizeText(s string, limit int) string {
	if strings.TrimSpace(s) == "" {
		return ""
	}
	lines := strings.Split(s, "\n")
	signals := make([]string, 0, maxSummarySamples)
	for _, ln := range lines {
		ln = strings.TrimSpace(ln)
		if ln == "" {
			continue
		}
		lower := strings.ToLower(ln)
		if strings.Contains(lower, "error") ||
			strings.Contains(lower, "fail") ||
			strings.Contains(lower, "panic") ||
			strings.Contains(lower, "warning") ||
			strings.Contains(lower, "exception") {
			signals = append(signals, clipRunes(ln, 180))
			if len(signals) >= maxSummarySamples {
				break
			}
		}
	}
	if len(signals) == 0 {
		signals = append(signals, clipRunes(strings.TrimSpace(lines[len(lines)-1]), 180))
	}
	out := strings.Join(signals, " | ")
	return clipRunes(out, limit)
}

func clipRunes(s string, limit int) string {
	if limit <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) <= limit {
		return s
	}
	return string(r[:limit]) + "..."
}
