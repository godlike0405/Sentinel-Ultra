![Snorkel AI](<../Sentinel Ultra/FAQ_files/snorkel_logo_header-1-04af18ea.svg>)

![Dr. Bubbles](<../Sentinel Ultra/FAQ_files/dr-bubbles-cap-1214daa2.png>)

# FAQ

Frequently asked questions

Common questions about working on Sentinel Ultra. If your question isn't here, reach out to the team on the Slack channel.

## Is there a daily limit to how many tasks I can do?

As of **July 1, 2026**, there's no daily cap on how many tasks you can complete. There is one throughput rule: you can have at most **two tasks in the "pending revision" stage** at once. While you're at that limit, the platform won't let you claim a new task until one of those clears — so keep your in-revision tasks moving.

## How do I decide between Valid as-is, Fixable, and Not Fixable?

- **Valid as-is** — the task already meets every requirement; no changes needed.
- **Fixable** — the task has issues in the instructions, tests, and/or oracle, but you can correct all of them yourself.
- **Not Fixable** — the only way to make the task valid would be to reduce or replace the PR scope, or the environment has issues you're not allowed to fix.

See [Task Verdicts](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::task-verdicts) and [the four core principles](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::the-four-core-principles) in the Guidelines for the full criteria.

## A task won't build, or the environment looks broken — what do I do?

Check the **Environment** panel in the Guidelines ([What you can edit → Environment](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::environment-limited-fixes)). It lists exactly which environment problems you're allowed to fix (e.g. a missing `bash`, an unpinned base image, missing `tmux`) versus the ones that make a task **Not Fixable** (e.g. tangled dependency/build failures or external-network dependencies). If it's on the fixable list, correct it; if not, mark the task Not Fixable and explain why.

**Git problems are fixable.** Leaked fix history, a remote, a `HEAD`/base-commit mismatch, a reflog, or an oversized `.git` don't make a task Not Fixable — do the git work inside `environment/repo`, re-zip, and realign `task.toml` to `HEAD` if needed (the shipped repo is the source of truth). See the [Git — fixable in the repo](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable) panel for the issue-by-issue fixes and a checklist. You still may not edit the repo's tracked source files.

## Do I need to run the oracle and NOP tests locally?

It depends on your verdict:

- **Valid as-is — yes.** These tasks aren't re-run by the platform's difficulty evals, so run the oracle and NOP locally before submitting to confirm the task passes.
- **Fixable — optional.** The platform's evals run them when you submit, so a local run is just for your own confidence.

## What counts as "changing the PR scope" vs. "adding complexity"?

You may **add complexity** — build on what the original PR already does. You may **not change the scope** — turn it into a different task or shrink it.

Say the source PR adds **CSV export** to a reports page:

- ✅ **Adding complexity:** make that same feature more capable or more robust — e.g. also let the user pick which columns to export, or handle edge cases the PR missed (empty results, commas and quotes inside cell values, very large exports).
- ❌ **Changing the scope:** swap it for a *different* feature (PDF export instead of CSV), replace it with something unrelated, or strip it down to be simpler (export only the current page instead of the full dataset).

Rule of thumb: if the task still clearly maps back to the original PR — just bigger or more thorough — that's adding complexity. If it no longer resembles the PR, or does *less* than the PR, you've changed the scope, which makes it **Not Fixable**. See [PR scope rules](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::pr-scope-rules) in the Guidelines.
