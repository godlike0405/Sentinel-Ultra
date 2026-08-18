package build

import (
	"runtime/debug"
	"strings"
)

// Version can be injected at build time:
// go build -ldflags "-X whale/internal/build.Version=v0.1.0"
var Version = "dev"

func CurrentVersion() string {
	v := strings.TrimSpace(Version)
	if v != "" && v != "dev" {
		return v
	}
	bi, ok := debug.ReadBuildInfo()
	if !ok {
		return "dev"
	}
	mv := strings.TrimSpace(bi.Main.Version)
	if mv != "" && mv != "(devel)" {
		return mv
	}
	rev := ""
	modified := ""
	for _, s := range bi.Settings {
		switch s.Key {
		case "vcs.revision":
			rev = strings.TrimSpace(s.Value)
		case "vcs.modified":
			modified = strings.TrimSpace(s.Value)
		}
	}
	if rev == "" {
		return "dev"
	}
	short := rev
	if len(short) > 7 {
		short = short[:7]
	}
	if modified == "true" {
		return "dev-" + short + "-dirty"
	}
	return "dev-" + short
}
