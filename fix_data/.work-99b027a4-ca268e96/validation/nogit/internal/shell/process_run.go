package shell

import (
	"context"
	"os/exec"
	"time"
)

func waitCommandContext(ctx context.Context, cmd *exec.Cmd, cancel func() error) error {
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()
	select {
	case err := <-done:
		return err
	case <-ctx.Done():
		if cancel != nil {
			_ = cancel()
		} else if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		if cmd.WaitDelay > 0 {
			select {
			case err := <-done:
				return err
			case <-time.After(cmd.WaitDelay):
				if cmd.Process != nil {
					_ = cmd.Process.Kill()
				}
			}
		}
		return <-done
	}
}
