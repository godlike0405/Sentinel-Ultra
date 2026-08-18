# Security Policy

## Supported versions

Whale is currently experimental and does not yet maintain a long-term support matrix. Security fixes will land on the main development line first.

## Reporting a vulnerability

Please do not open a public GitHub issue for credential exposure, hook execution bugs, sandbox escapes, or similar security-sensitive problems.

This repository should keep GitHub private vulnerability reporting enabled before any public release. Report vulnerabilities through the repository Security tab using GitHub's private vulnerability reporting flow.

If the Security tab is unavailable because private reporting has not been enabled yet or was disabled accidentally, do not post exploit details publicly. Instead, open a minimal public issue that only requests a private contact path, without including secrets, proof-of-concept payloads, or reproduction details.

## Security boundaries in this repository

- `~/.whale/credentials.json` may contain a live DeepSeek API key.
- `DEEPSEEK_API_KEY` takes precedence over the saved credential file.
- `~/.whale/` and session state files should be treated as local secrets and machine state, not source-controlled data.
- `./.whale/settings.json` and `~/.whale/settings.json` can define hooks that execute shell commands.
- `whale exec` uses the same underlying tool loop as the interactive TUI, so normal approval, tool, and hook behavior still applies in headless mode.

## Safe disclosure notes

When reporting a bug, include:

- Whale version or commit
- operating system
- reproduction steps
- whether the issue requires local hooks, custom config, or a real API key

Do not include real API keys, credential files, or private session transcripts in the report.
