package memory

import "github.com/usewhale/whale/internal/core"

type RewriteReason string

const (
	RewriteReasonCompact  RewriteReason = "compact"
	RewriteReasonRecovery RewriteReason = "recovery"
)

type AppendOnlyLog struct {
	entries []core.Message
}

func NewAppendOnlyLog() *AppendOnlyLog {
	return &AppendOnlyLog{entries: make([]core.Message, 0)}
}

func (l *AppendOnlyLog) Append(msg core.Message) {
	l.entries = append(l.entries, cloneMessage(msg))
}

func (l *AppendOnlyLog) Extend(msgs []core.Message) {
	for _, m := range msgs {
		l.Append(m)
	}
}

func (l *AppendOnlyLog) Entries() []core.Message {
	return cloneMessages(l.entries)
}

func (l *AppendOnlyLog) RewriteWithReason(reason RewriteReason, replacement []core.Message) bool {
	switch reason {
	case RewriteReasonCompact, RewriteReasonRecovery:
	default:
		return false
	}
	l.entries = cloneMessages(replacement)
	return true
}

func (l *AppendOnlyLog) Len() int {
	return len(l.entries)
}
