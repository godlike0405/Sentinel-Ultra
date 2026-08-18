package core

import "testing"

func TestProposedPlanParserStreamsSegments(t *testing.T) {
	var p ProposedPlanParser
	var got []ProposedPlanSegment
	for _, chunk := range []string{"Intro\n<prop", "osed_plan>\n- one\n", "</proposed_plan>\nOutro"} {
		got = append(got, p.Parse(chunk)...)
	}
	got = append(got, p.Finish()...)

	want := []ProposedPlanSegment{
		{Kind: ProposedPlanSegmentNormal, Text: "Intro\n"},
		{Kind: ProposedPlanSegmentStart},
		{Kind: ProposedPlanSegmentDelta, Text: "- one\n"},
		{Kind: ProposedPlanSegmentEnd},
		{Kind: ProposedPlanSegmentNormal, Text: "Outro"},
	}
	if len(got) != len(want) {
		t.Fatalf("len got=%d want=%d: %+v", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("segment %d got=%+v want=%+v", i, got[i], want[i])
		}
	}
}

func TestExtractAndStripProposedPlan(t *testing.T) {
	text := "before\n<proposed_plan>\n# Plan\n- A\n</proposed_plan>\nafter"
	plan, ok := ExtractProposedPlanText(text)
	if !ok || plan != "# Plan\n- A\n" {
		t.Fatalf("unexpected plan ok=%v plan=%q", ok, plan)
	}
	if got := StripProposedPlanBlocks(text); got != "before\nafter" {
		t.Fatalf("unexpected stripped text: %q", got)
	}
}

func TestProposedPlanParserClosesMissingEndTag(t *testing.T) {
	var p ProposedPlanParser
	got := p.Parse("<proposed_plan>\n- A")
	got = append(got, p.Finish()...)
	if len(got) != 3 || got[0].Kind != ProposedPlanSegmentStart || got[1].Kind != ProposedPlanSegmentDelta || got[2].Kind != ProposedPlanSegmentEnd {
		t.Fatalf("unexpected finish segments: %+v", got)
	}
}

func TestProposedPlanParserRejectsInlineAndDecoratedTags(t *testing.T) {
	cases := []string{
		"Use `<proposed_plan>` when ready.\n",
		"> <proposed_plan>\n- quoted\n> </proposed_plan>\n",
		"<proposed_plan> extra\n- not a plan\n</proposed_plan>\n",
		"prefix <proposed_plan>\n- not a plan\n</proposed_plan>\n",
	}
	for _, text := range cases {
		var p ProposedPlanParser
		got := append(p.Parse(text), p.Finish()...)
		if len(got) != 1 || got[0].Kind != ProposedPlanSegmentNormal || got[0].Text != text {
			t.Fatalf("expected decorated tag to stay normal for %q, got %+v", text, got)
		}
		if plan, ok := ExtractProposedPlanText(text); ok || plan != "" {
			t.Fatalf("decorated tag extracted plan ok=%v plan=%q for %q", ok, plan, text)
		}
		if stripped := StripProposedPlanBlocks(text); stripped != text {
			t.Fatalf("decorated tag stripped unexpectedly:\nwant %q\ngot  %q", text, stripped)
		}
	}
}

func TestProposedPlanParserAllowsIndentedStandaloneTags(t *testing.T) {
	text := "before\n  <proposed_plan>  \n- A\n  </proposed_plan>\nafter"
	plan, ok := ExtractProposedPlanText(text)
	if !ok || plan != "- A\n" {
		t.Fatalf("unexpected indented plan ok=%v plan=%q", ok, plan)
	}
}
