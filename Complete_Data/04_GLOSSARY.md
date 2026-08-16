![Snorkel AI](<../Sentinel Ultra/Glossary_files/snorkel_logo_header-1-04af18ea.svg>)

# Glossary

Key terms used across Sentinel Ultra

Key terms used across these guidelines, the Tasking Guide, and the platform. Where a different word is sometimes used for the same thing, both are noted. Links point to the section that covers each term in depth.

## Roles & workflow

| Term | Meaning |
| --- | --- |
| **EC (Expert Contributor)** | You — the person reviewing, fixing, and validating tasks. Your step-by-step process lives in the [Tasking Guide](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking). |
| **Submitter** | The EC who reviews a task, decides its verdict, and fixes it if needed. See [Submitter form questions](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking::step-by-step-submitter-form-questions). |
| **Reviewer** | A second EC who independently verifies the submitter's work. See [Reviewer form questions](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking::step-by-step-reviewer-form-questions). |
| **Adjudicator** | A final reviewer who resolves disagreements between submitter and reviewer. |
| **Source PR / commit / issue** | The real upstream change a task is derived from and anchored to. Every task comes from a real source — there are no net-new tasks. See [PR Scope and Task Difficulty](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::pr-scope-and-task-difficulty). |
| **PR scope** | What the task is fundamentally about. You may *expand* it to add difficulty, but never reduce or replace it — see [PR scope rules](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::pr-scope-rules). |

## Task anatomy

| Term | Meaning |
| --- | --- |
| **Harbor** | The framework/format every task is built in. See the [Harbor Framework tab](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor) or the [Harbor documentation](https://harborframework.com/docs). |
| **Task** | A single software-engineering problem in Harbor format: instruction, environment, solution, and tests. See [Task Structure](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor::task-structure-components). |
| **`instruction.md`** | The problem statement the agent receives — what to do and how success is measured. |
| **`problem_statement.md`** | A restatement of the instruction placed inside the environment. |
| **`task.toml`** | Task metadata: pinned image URI, resource budget, timeouts, source, and difficulty fields. See [Task Metadata](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor::task-metadata). |
| **Environment** | The container the task runs in — the `Dockerfile` plus `repo/` (the cloned base repository). For what can go wrong here, see [Environment Issues](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::environment-limited-fixes). |
| **`runs/`** | Logs of past agent attempts, delivered alongside the task as reference. |

## Solution (oracle)

| Term | Meaning |
| --- | --- |
| **Oracle** (a.k.a. golden solution, reference solution) | The known-correct solution that proves the task is solvable. See [Task Structure](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor::task-structure-components) and [Rewriting the Oracle](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::solution-oracle-editable-in-two-cases). |
| **`solve.sh`** | Script that applies the golden patch to bring the repo to the solved state. |
| **`golden.patch`** (a.k.a. gold patch; formerly `init_state.patch`) | The self-contained patch containing all of the solution's changes. If a task ships with `solution.patch` instead, rename it to `golden.patch` — that was a short-lived draft name. |

## Tests & grading

| Term | Meaning |
| --- | --- |
| **Fail-to-pass (f2p) tests** | Tests that fail on the unsolved repo and pass after the fix — the core behavioral checks. At least 10 are required; see [Verifiability](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::3-verifiability). They live in `tests.patch`. |
| **Pass-to-pass (p2p) tests** | Tests that must pass both before and after the fix; a regression guard. |
| **`tests.patch`** | The patch containing the fail-to-pass tests. |
| **`config.json`** | Declares how the suite runs and which test ids are fail-to-pass vs pass-to-pass. |
| **`test.sh`** | Runs the suite and writes the reward. |
| **`grade.py`** | The grading script. |
| **Verifier** | The component that runs the tests and computes the reward. See [how tasks are evaluated](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor::optional-context-on-how-tasks-are-evaluated). |
| **Reward** | The pass/fail signal: 1.0 only if every fail-to-pass test passes and no pass-to-pass test regresses. |

## Quality & difficulty

![](<../Sentinel Ultra/Glossary_files/dr-bubbles-speed-d4bed3d4.svg>)

| Term | Meaning |
| --- | --- |
| **Agent** | The model or coding agent attempting the task. |
| **Reward hacking** | Passing the tests without doing the intended engineering work (e.g. editing the tests, hardcoding outputs). Preventing this is a central goal — see [Verifiability](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::3-verifiability). |
| **Difficulty bar / pass@k** | The benchmark threshold a task must clear — e.g. a frontier model solves a Medium task in ≤ 4 of 8 attempts, a Hard task in ≤ 2 of 8. See [Task difficulty](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::task-difficulty). |
| **Outcome-based test** | A test that checks observable behavior by running code, not by inspecting diffs, file names, or source keywords. See [outcome-based tests](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::outcome-based-tests). |
