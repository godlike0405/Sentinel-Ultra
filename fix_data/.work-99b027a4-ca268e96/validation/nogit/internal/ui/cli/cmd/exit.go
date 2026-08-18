package cmd

import "fmt"

type ExitError struct {
	Code int
}

func (e ExitError) Error() string {
	return fmt.Sprintf("exit %d", e.Code)
}

func ExitCode(err error) (int, bool) {
	if err == nil {
		return 0, false
	}
	exitErr, ok := err.(ExitError)
	if !ok {
		return 0, false
	}
	return exitErr.Code, true
}
