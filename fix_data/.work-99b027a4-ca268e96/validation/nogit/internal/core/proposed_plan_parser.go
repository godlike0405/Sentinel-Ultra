package core

import (
	"strings"
	"unicode"
)

const (
	ProposedPlanOpenTag  = "<proposed_plan>"
	ProposedPlanCloseTag = "</proposed_plan>"
)

type ProposedPlanSegmentKind string

const (
	ProposedPlanSegmentNormal ProposedPlanSegmentKind = "normal"
	ProposedPlanSegmentStart  ProposedPlanSegmentKind = "start"
	ProposedPlanSegmentDelta  ProposedPlanSegmentKind = "delta"
	ProposedPlanSegmentEnd    ProposedPlanSegmentKind = "end"
)

type ProposedPlanSegment struct {
	Kind ProposedPlanSegmentKind
	Text string
}

type ProposedPlanParser struct {
	inPlan      bool
	detectTag   bool
	initialized bool
	lineBuf     string
}

func (p *ProposedPlanParser) Parse(delta string) []ProposedPlanSegment {
	if delta == "" {
		return nil
	}
	p.ensureInitialized()
	var out []ProposedPlanSegment
	var run strings.Builder
	flushRun := func() {
		if run.Len() == 0 {
			return
		}
		p.pushText(run.String(), &out)
		run.Reset()
	}
	for _, ch := range delta {
		if p.detectTag {
			flushRun()
			p.lineBuf += string(ch)
			if ch == '\n' {
				p.finishLine(&out)
				continue
			}
			slug := strings.TrimRightFunc(strings.TrimLeftFunc(p.lineBuf, unicode.IsSpace), unicode.IsSpace)
			if slug == "" || p.isTagPrefix(slug) {
				continue
			}
			buffered := p.lineBuf
			p.lineBuf = ""
			p.detectTag = false
			p.pushText(buffered, &out)
			continue
		}
		run.WriteRune(ch)
		if ch == '\n' {
			flushRun()
			p.detectTag = true
		}
	}
	flushRun()
	return out
}

func (p *ProposedPlanParser) Finish() []ProposedPlanSegment {
	p.ensureInitialized()
	var out []ProposedPlanSegment
	if p.lineBuf != "" {
		line := p.lineBuf
		p.lineBuf = ""
		p.handleCompleteLine(line, &out)
	}
	if p.inPlan {
		p.inPlan = false
		appendSegment(&out, ProposedPlanSegment{Kind: ProposedPlanSegmentEnd})
	}
	p.detectTag = true
	return out
}

func (p *ProposedPlanParser) ensureInitialized() {
	if p.initialized {
		return
	}
	p.initialized = true
	p.detectTag = true
}

func (p *ProposedPlanParser) finishLine(out *[]ProposedPlanSegment) {
	line := p.lineBuf
	p.lineBuf = ""
	p.handleCompleteLine(line, out)
	p.detectTag = true
}

func (p *ProposedPlanParser) handleCompleteLine(line string, out *[]ProposedPlanSegment) {
	trimmed := strings.TrimSpace(strings.TrimSuffix(line, "\n"))
	switch {
	case trimmed == ProposedPlanOpenTag && !p.inPlan:
		p.inPlan = true
		appendSegment(out, ProposedPlanSegment{Kind: ProposedPlanSegmentStart})
	case trimmed == ProposedPlanCloseTag && p.inPlan:
		p.inPlan = false
		appendSegment(out, ProposedPlanSegment{Kind: ProposedPlanSegmentEnd})
	default:
		p.pushText(line, out)
	}
}

func (p *ProposedPlanParser) pushText(text string, out *[]ProposedPlanSegment) {
	if text == "" {
		return
	}
	if p.inPlan {
		appendSegment(out, ProposedPlanSegment{Kind: ProposedPlanSegmentDelta, Text: text})
		return
	}
	appendSegment(out, ProposedPlanSegment{Kind: ProposedPlanSegmentNormal, Text: text})
}

func appendSegment(out *[]ProposedPlanSegment, seg ProposedPlanSegment) {
	if seg.Text == "" {
		switch seg.Kind {
		case ProposedPlanSegmentStart, ProposedPlanSegmentEnd:
		default:
			return
		}
	}
	if len(*out) > 0 {
		last := &(*out)[len(*out)-1]
		if last.Kind == seg.Kind && (seg.Kind == ProposedPlanSegmentNormal || seg.Kind == ProposedPlanSegmentDelta) {
			last.Text += seg.Text
			return
		}
	}
	*out = append(*out, seg)
}

func StripProposedPlanBlocks(text string) string {
	var p ProposedPlanParser
	var out strings.Builder
	for _, seg := range append(p.Parse(text), p.Finish()...) {
		if seg.Kind == ProposedPlanSegmentNormal {
			out.WriteString(seg.Text)
		}
	}
	return out.String()
}

func ExtractProposedPlanText(text string) (string, bool) {
	var p ProposedPlanParser
	var out strings.Builder
	seen := false
	for _, seg := range append(p.Parse(text), p.Finish()...) {
		switch seg.Kind {
		case ProposedPlanSegmentStart:
			seen = true
			out.Reset()
		case ProposedPlanSegmentDelta:
			out.WriteString(seg.Text)
		}
	}
	return out.String(), seen
}

func (p *ProposedPlanParser) isTagPrefix(slug string) bool {
	return strings.HasPrefix(ProposedPlanOpenTag, slug) || strings.HasPrefix(ProposedPlanCloseTag, slug)
}
