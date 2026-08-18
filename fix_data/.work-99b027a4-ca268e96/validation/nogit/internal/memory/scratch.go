package memory

import "github.com/usewhale/whale/internal/session"

type ToolArgsState struct {
	ToolName   string
	ArgsChars  int
	ReadyCount int
}

type UserInputGateState struct {
	State session.UserInputState
	Err   string
}

type VolatileScratch struct {
	Reasoning string
	ToolArgs  map[int]ToolArgsState
	Warnings  []string
	UserInput UserInputGateState
}

func NewVolatileScratch() *VolatileScratch {
	return &VolatileScratch{
		ToolArgs: make(map[int]ToolArgsState),
		Warnings: make([]string, 0),
	}
}

func (s *VolatileScratch) UpdateToolArgs(index int, name string, argsChars int, readyCount int) {
	s.ToolArgs[index] = ToolArgsState{
		ToolName:   name,
		ArgsChars:  argsChars,
		ReadyCount: readyCount,
	}
}

func (s *VolatileScratch) ResetTurn() {
	s.Reasoning = ""
	for k := range s.ToolArgs {
		delete(s.ToolArgs, k)
	}
	s.Warnings = s.Warnings[:0]
	s.UserInput = UserInputGateState{}
}

func (s *VolatileScratch) ResetSession() {
	s.ResetTurn()
}
