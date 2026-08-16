![Snorkel AI](<../Sentinel Ultra/GuideLines_files/snorkel_logo_header-1-04af18ea.svg>)

# Sentinel Ultra Contributor Guidelines

Last updated: July 22, 2026

**Welcome to Sentinel Ultra**<br>Sentinel Ultra is Snorkel AI's initiative to build a high-quality dataset of [Harbor-format](https://harborframework.com/docs) software-engineering tasks, drawn from real open-source pull requests, commits, and issues. The dataset is used to train and evaluate frontier coding agents and models on realistic engineering work.

Because of that purpose, the thing that matters most is that every task is **correct, complete, and impossible to game** — no errors, no gaps in coverage, and no way for an agent to pass without doing the real engineering work. Difficulty matters too, but the platform's evals help confirm a task clears the difficulty bar; your focus is on the errors and gaps that automated checks can't catch.

**How a task reaches you**<br>Each task starts from a real source (a PR, commit, or issue) and is packaged into the Harbor format. It then moves through:

1. **Authoring** — the task is created from the source.
2. **Submission** — an EC (you) reviews the task, decides whether it's valid, and fixes it if needed.
3. **Review** — a second EC independently verifies the submission.
4. **Adjudication** — a final pass resolves disagreements between submitter and reviewer.
5. **Delivery** — accepted tasks are delivered to train and evaluate coding agents.

These guidelines explain how to evaluate a task, identify issues, make corrections, and complete your submission successfully.

*If you are not familiar with the Harbor framework, review the* [Harbor documentation](https://harborframework.com/docs) *for terminology and layout. The [Harbor Framework tab](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor) has important information on task structure and the `task.toml` fields you'll need to check on every task.*

## Your Role as an Expert Contributor (EC)

You will review Harbor tasks derived from real open-source pull requests and provide feedback through the Snorkel Experts platform. Each task asks an agent to navigate a codebase, understand the requirements, implement changes, and validate behavior through tests.

Your role is to ensure tasks are **solvable, clear, free of leakage, verifiable, and authentic** — the five things the core principles below cover in depth:

- **Solvable** — completable from the instruction alone, by a competent engineer, within the task's limits.
  - No arbitrary guesswork: every choice the tests require is stated or reasonably implied.
  - Claims hold up: the instruction only references behavior, APIs, and files that actually exist in the repo.
- **Clear** — the instruction describes the problem and the expected behavior, not how to implement it.
  - Not overly prescriptive (e.g. no "Where to look: [files]", no naming the exact functions to edit).
  - Any required output format or schema is documented, not left to guesswork.
- **Free of leakage** — nothing in the task lets an agent shortcut the real work.
  - No solution hints, PR links, or spoilers in the instruction or environment.
  - No hidden test details exposed, and no way to pass by editing the tests.
- **Verifiable** — a sound, comprehensive test suite proves the behavior.
  - At least 10 fail-to-pass tests, outcome-based (they run code and check real behavior).
  - Includes a regression test, is deterministic, and doesn't depend on the solution.
- **Authentic** — a realistic, substantial engineering task.
  - A plausible workflow (bug fix, feature, refactor), typically ~100+ lines across multiple files.
  - Reads like real engineering communication, not a templated or AI-generated prompt.

You're also responsible for keeping each task **consistent with the scope of the source PR** — you may expand on it to add complexity, but you may not reduce or replace it.

## Task verdicts

When you receive a task in platform, you’ll give a verdict on which of the three states below the task falls into.

| Verdict | When it applies |
| --- | --- |
| **Valid as-is** | Instruction, tests, and oracle all align with each other and with the source PR. No rewrite or edits are required. |
| **Fixable** | The task has one or more of the issues below:  • **Instructions** are overly prescriptive or expose verifier internals  • **Instruction** reads as templated/AI-generated  • **Tests** miss requirements stated in the instruction  • **Tests** grade behavior that is not in the instruction, or rely on arbitrary names  • **Fewer than 10 fail-to-pass tests** — add tests to reach at least 10 (ideally 10–20)  • **Task leaks solution information** (e.g. PR URL in instruction, environment spoilers, test-gaming shortcuts)  • **Oracle does not implement the solution** following the instructions  • Overall task is too easy — but you can raise difficulty by adding to the PR scope  • A specific, listed Dockerfile issue (see [Environment](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::environment-limited-fixes) section)  • A git-hygiene issue in the shipped repo — leaked fix history, a remote, a HEAD/base-commit mismatch, reflog, an oversized `.git` (see [Git](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable) section) |
| **Not Fixable** | Either of:  • **PR scope needs to be changed or reduced** — the only way to make the task valid is to reduce or replace the PR scope entirely  • **Environment Issues** — the environment has issues ECs aren't allowed to fix (see [Environment](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::environment-limited-fixes) section) |

If Not Fixable, you’ll give the reasons in the submission form (see Part B).

## The four core principles

Apply these to every task — together they determine the verdict. Two of them — **Clarity & No Leakage** and **Verifiability** — are two sides of the same goal: making a task **impossible to reward-hack**, so an agent has to do the real engineering work to pass.

|  | Principle | What to check |
| --- | --- | --- |
| **1** | **Solvability** | A competent engineer can solve it from the instruction alone, within limits. |
| **2** | **Clarity & No Leakage** | Describes the problem and behavior — not the implementation — and reveals nothing exploitable. |
| **3** | **Verifiability** | A sound, comprehensive, outcome-based test suite that can't be gamed. |
| **4** | **Authenticity** | A realistic, substantial engineering task that reads like real communication and matches the PR. |

### 1 Solvability

A task is valid only if a competent engineer can solve it from the instruction alone — within the task's time and resource limits, and without guessing arbitrary implementation choices.

**No unsupported claims:** the instruction must only reference behaviors, APIs, files, or repo structure that actually exist in the pinned repository. If it describes something that isn't there, the task isn't solvable as written.

### 2 Clarity & No Leakage

The instruction should give an engineer enough to solve the task **without telling them how to implement it and without revealing the answer.** This principle has two failure modes — over-prescription and leakage — and together they are how most reward-hacking sneaks in.

#### Signs an instruction is overly prescriptive:

- Says "Where to look:" followed by a list of the relevant files.
- Names the exact hidden test, fixture, mock endpoint, cassette, or harness file used to grade the task.
- Explains how the verifier proves success instead of describing user- or API-visible behavior.
- Identifies exact internal functions, branches, comprehensions, or callbacks to edit when a behavioral description would do.
- Provides root-cause analysis that removes the need to inspect the code.
- Says "the tests reference this name" or "this file validates the fix."
- Copies exact assertion strings, state paths, or fixture values from tests — unless they're a genuine public/API contract.

**Document required output formats.** If the task requires a specific output format, schema, or API response shape, state that format in the instruction (or a clearly referenced file in the environment). Describing the expected *shape* is necessary and is not leakage — leaving it to guesswork is what breaks solvability.

#### No leakage

![](<../Sentinel Ultra/GuideLines_files/dr-bubbles-hacker-643a4c0f.svg>)

Tasks must not leak the solution. Check for:

- **PR leakage:** PR URLs, titles, numbers, or commit SHAs in the instruction that let an agent scrape the fix.
- **Environment spoilers:** commit messages, comments, or docs in the base repo/Docker setup that describe the exact change.
- **Test-modification gaming:** loose test constraints that can be satisfied by editing the test files instead of the implementation.

### 3 Verifiability

Tests are the ground truth for a task. They must comprehensively and fairly verify the required behavior, and they must be impossible to game.

When you run evals, an agentic rubric-panel judge now scores these two directions mechanically as **test_coverage** and **test_faithfulness**, and a failing verdict blocks submission. See [Quality Check — the agentic rubric-panel judge](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking::quality-check-agentic-judge) in the Tasking Guide for the verdict logic, the six auto-fail patterns, and the test-writing checklist.

### Test ↔ instruction alignment

Tests should map 1:1 with the instruction's requirements; the agent must be able to pass them using only the instruction and the environment. Check both directions:

| Direction | Requirement |
| --- | --- |
| Instruction → Tests | Every required behavior is tested. |
| Tests → Instruction | Every assertion maps to something stated or reasonably implied. |
| No hidden checks | Tests don't grade behavior the instruction never asked for. |

Tests likely need a rewrite when they enforce undescribed behavior, require non-derivable names/paths/formats, over-constrain implementation, depend on verifier internals or hidden fixtures, can be passed by editing the tests, or miss/partially cover major requirements.

### At least 10 fail-to-pass tests

Every task must ship with at least **10 fail-to-pass tests** — the single most important guard against reward hacking and the main way to ensure sufficient behavioral coverage. If the task arrives with fewer than 10, mark it **Fixable** and add tests during your rewrite to reach at least 10 — ideally 10–20. Added tests must cover requirements stated or reasonably implied in the instruction (never undescribed behavior).

### Outcome-based tests

Tests must verify **observable behavior** by running code and checking results — invoking the corrected API, querying a service, inspecting runtime output. They must **not** grade by patch structure, diff format, line numbers, file names, or source-code keyword matching, and must not be satisfiable by hardcoding or special-casing expected values.

### Regression test required

The suite must include at least one test that directly reproduces the failure described in the issue — it **fails on the pre-patch repo and passes after the fix.**

### Deterministic and fast

![](<../Sentinel Ultra/GuideLines_files/dr-bubbles-speed-d4bed3d4.svg>)

Tests must use deterministic inputs, seeds, and assertions, with no flaky or order-dependent behavior, and must finish within the configured timeout. Scope long suites to the relevant subset.

### Independent of the oracle

Tests must not import or call the golden solution, compare against files created only by the solution, or otherwise depend on solution-side artifacts. Any fixtures or mock data must be committed into the verifier image so the agent cannot tamper with them.

### The arbitrary naming problem

A common alignment failure: tests expect a specific name the instruction never gave — a function/method/class name, exact error string, output format (JSON keys, log format), new module/file name, or CLI flag / config key.

A name is **derivable** (and therefore acceptable) only if it:

- already exists in the base codebase being modified (e.g. an existing parsedate()),
- follows a standard language/framework convention (e.g. Python str, standard REST resource names), or
- is explicitly stated in the instruction.

*Example — Invalid but Fixable:* instruction says "Add a feature to validate emails," but the test asserts validateemailaddress(email) = True. The instruction never specified that name → add it in your rewrite.

*To catch it:* list the names/formats the instruction explicitly specifies → scan the tests for expected names → flag any that aren't derivable.

### 4 Authenticity

![](<../Sentinel Ultra/GuideLines_files/dr-bubbles-fairy-c3b151fb.svg>)

A valid task looks like real engineering work and reads like real engineering communication.

**Substantial and agentic.** The task must require genuine code exploration, multi-step reasoning, and real changes — not a one-line edit or a zero-shot generation. As a rule of thumb, the underlying fix is roughly **100+ lines across two or more files.** A task solvable by a trivial edit, or that is really a contrived puzzle with no real-world analogue, is not authentic.

**Reads like a real engineering ask.** A good instruction matches one natural persona:

- **Casual/Slack-like** — direct, assumes domain knowledge.
- **Structured ticket** — Summary / Steps to Reproduce / Expected Behavior.
- **Technical memo** — professional refactor/logic context.
- **Prose/email** — a peer or tech lead explaining context and impact.
- **Acceptance criteria** — bulleted "when X, the system should Y."

*Red flags:* robotic phrasing ("The system shall…", "It is required that…"), tone that mismatches the persona, structure identical across many tasks, or writing that reads like code documentation rather than a task assignment.

**PR ↔ instruction alignment.** The instruction must ask for the same change as the PR (bug X → describes bug X; feature Y → requests feature Y). If you expanded scope, it should still be the original PR *plus* your additions — not a different task.

## PR Scope and Task Difficulty

### Task difficulty

Sentinel tasks train and evaluate frontier coding agents, so they have to be genuinely hard — an easy task gives no useful signal. By the time a task reaches you it has already passed our difficulty checks, so you don't need to judge difficulty from scratch (it's also why the difficulty evals don't re-run on tasks you mark **Valid as-is**).

Clearing the difficulty bar doesn't mean a task is free of *other* issues, though — and fixing those issues can pull difficulty back below the benchmark. When that happens, the platform's evals send the task back to you to raise it again.

#### **Troubleshooting task difficulty**

**First, check for over-prescriptive instructions.** Often an instruction hands the agent context it should have discovered itself — the files to touch, the root cause, or a step-by-step approach. Remove anything the agent could reasonably find by exploring the codebase (and any solution-revealing names or paths, which are also leakage), and describe the behavior you expect instead of the how.

**Balancing context is the crux of this work:** a task needs *enough* context to be solvable, but *not so much* that it becomes instructional.

**If trimming isn't enough, expand the PR scope.** When the source PR simply isn't complex enough, add to its scope so the task is genuinely harder (see the rules below).

**Keep any added difficulty real.** Good difficulty comes from the problem itself — complex debugging, root-cause analysis, a substantial feature, or hard domain/security work. It must **not** come from vague or underspecified requirements, or from stapling unrelated changes together; those make a task confusing, not difficult, and a reviewer will flag them.

### PR scope rules

When you fix a task, you can change the instruction, tests, and oracle — but you cannot change what the task is about. The source PR anchors what the task is.

You may:<br>✅ **Add to the scope of the PR** to make the task harder.

- Example: Original PR adds a `/health` endpoint. You extend it so the endpoint also handles auto-restart on failure.
- Example: Original PR fixes a single edge case in a date parser. You extend it to handle three additional edge cases.

You **may not:**

❌ Reduce the scope of the PR to make it more concise<br>❌ Replace the PR with a different feature or task type entirely

- Example: Original PR is a bug fix. You can't rewrite it as a feature add.
- Example: Original PR is a refactor of module X. You can't rewrite it as a refactor of module Y.

If the only way to make a task solvable, difficult enough, or valid is to reduce or replace the PR scope, the task is **Not Fixable**.

**Why this matters:** The task is anchored to a real PR via `task.toml`. If the task no longer resembles the PR, the link is misleading and the dataset loses its grounding in real-world engineering work.

## What you can edit in a task, and how

You can edit the instruction, tests, and solution, make limited fixes to the Dockerfile, and clean up git issues in the shipped repo — but never edit the repo's tracked source files. Expand each component for how to edit it well.

### ✅ Instructions — editable

Rewrite overly prescriptive instructions to mirror real-world engineering tasks. Focus on expected behavior, constraints, and observable outcomes, while still requiring standard codebase investigation.

| ❌ Overly Prescriptive | ✅ Preferred Instructions |
| --- | --- |
| “The test testdownloadpackagesresumeonmirrorswitch uses /yum/partial and /yum/rangeonly to verify resume behavior.” | “When a resumed download fails after writing a valid partial file, retrying against another mirror should preserve the partial data and request only the remaining bytes.” |
| “Fix the range() call inside the list comprehension that creates schemas.SlotBase*.*” | “Generated slots must never extend past the schedule’s availability end time.” |
| “The hook should expose handleScrollContainerWheel because the tests reference this name.” | “The hook should expose a stable wheel handler for the scroll container.” |

### ✅ Tests — editable

- Map tests 1:1 with the instruction's requirements.
- Ensure the suite has at least 10 fail-to-pass tests (ideally 10–20); if it's short, add tests covering requirements stated or reasonably implied in the instruction.
- Keep them flexible enough to allow multiple valid implementations where appropriate.
- Don't introduce arbitrary names, strings, paths, or formats that aren't derivable from the instruction.
- Validate observable behavior, not implementation details.

**Example `config.json`** — tells the harness **how** to run the suite and **which** test ids decide the reward. `fail_to_pass` is the required, non-empty list; `pass_to_pass` is the regression guard.

```
{
  "execution": {
    "commands": ["python -m pytest -q tests/test_resume.py"],
    "timeout_sec": 1800
  },
  "grading": {
    "fail_to_pass": [
      "tests/test_resume.py::test_partial_file_preserved",
      "tests/test_resume.py::test_range_request_on_retry"
    ],
    "pass_to_pass": [
      "tests/test_resume.py::test_basic_download"
    ],
    "parser": { "framework": "pytest", "result_source": "stdout_stderr" }
  },
  "artifacts": { "reward": "/logs/verifier/reward.txt" }
}
```

**Example `test.sh`** — applies the tests, runs the suite, and writes the reward to the path Harbor reads. The exit code should match the reward it writes.

```
#!/usr/bin/env bash
set -euo pipefail

# Add the fail-to-pass tests to the repo
git apply /tests/tests.patch

# Run the suite; write 1.0 only if it passes, else 0.0
cd /workspace/repo
if python -m pytest -q tests/test_resume.py; then
  echo "1.0" > /logs/verifier/reward.txt
else
  echo "0.0" > /logs/verifier/reward.txt
  exit 1
fi
```

### ✅ Solution & oracle — editable in two cases

You may edit solve.sh / golden.patch in two cases: (1) to correct an oracle that does not implement the instruction, or (2) to expand PR scope to increase difficulty. When you do:

- **Match the canonical fix.** The solution should correspond to the actual fix from the source PR — not an alternative you invented. Only diverge if the upstream fix is genuinely unavailable or unsuitable, and document why.
- **No unnecessary changes.** The patch should contain only what's needed to resolve the task. Don't fold in unrelated refactors, style cleanups, or drive-by edits.
- The expanded oracle must still resemble the source PR (anchor preserved, with additions) — never reduce or replace its intent.
- Update the **instruction and tests in lockstep** so the trio stays internally consistent, and the instruction reads as one realistic ask, not a tacked-on list.
- If you expanded scope, re-run the difficulty eval to confirm the task now clears the bar.

If a fix would require reducing or replacing the PR's behavior, mark the task **Not Fixable** instead.

### ⚠️ Environment — limited fixes

**`problem_statement.md` must be an exact copy of `instruction.md`.** Check before submitting that the two files are identical — if you edit the instruction, copy the same content into `problem_statement.md`. (We're working to automate this so you don't have to do it in future!)

You may make only specific, allowed fixes to the environment (chiefly `environment/Dockerfile`). Use the tables below to decide whether an environment issue is within the limited fixes you can make — otherwise the task is **Not Fixable**.

Many environment failures are catchable before you submit — the offline Docker build, the `tests.patch`-applies-to-base check, git-history hygiene, and the stray-artifact sweep are all in the [Before You Upload](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking::before-you-upload) checklist in the Tasking Guide.

**Fixable environment issues**

| Issue | What's happening | Fix |
| --- | --- | --- |
| Alpine image missing bash | solve.sh/test.sh use a bash shebang but Alpine ships only ash (saw 55x) | apk add -no-cache bash. Has autocorrect: alpinebashautocorrect. |
| Missing `environment/frozen-requirements.txt` | Dockerfile COPYs it but it's absent (saw 683x) | Generate it. Has autocorrect: frozenrequirementsautocorrect. |
| `tmux` not installed in the task image | Harbor drives the agent/verifier inside a `tmux` pane; no tmux means the session never starts and the run errors before tests | apt-get install y tmux / apk add -no-cache tmux. Good autocorrect candidate. |
| asciinema not installed | Harbor records the terminal session with asciinema; a missing binary breaks the run | apt-get install y asciinema / pip install asciinema / apk add asciinema |
| Unpinned base image (FROM ...:latest) | Reproducibility failure | Pin to a concrete tag |
| DownloadVerifierDirError / verifier-output-not-found | When caused by the above (bash/sh mismatch, missing artifact path, missing tmux/asciinema) | Fix the upstream cause |
| Resource limits too low | Build OOM / disk-full from undersized cpus/memorymb/storagemb | Bump limits |
| Bad shell/shebang, CRLF line endings, non-executable scripts | Script fails to exec | Normalize / chmod x |
| Stray pipeline artifacts / wrong metadata blocking build prep | e.g. metadata.json in root, cpp vs c++, missing language. Strictly metadata, but they gate the task before it builds. | Clean up |

**Not Fixable environment issues**

| Issue | When it's defensible |
| --- | --- |
| Image/dependency build failures | apt/pip/npm/cargo install errors, missing system libs, compiler flags. Adding a missing dev package or flag is under worth fixing; a tangled toolchain/version conflict is not. |
| Oracle timeout | harbor run timed out after n seconds. Can try bumping the timeout. |
| External-network dependency at build/solve time | curl/wget/HF/model pulls against a restricted or flaky sandbox. Vendoring one small file is under fixable; a multi-GB model pull or live external service is not. |

Git-repository problems (leaked fix history, remotes, a HEAD/base-commit mismatch, reflog, an oversized `.git`) are handled separately — see [Git — fixable in the repo](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable) below. Most of them are fixable.

### ✅ Git — fixable in the repo

The shipped repo (`environment/repo/`) is a real git checkout, and its **HEAD is the source of truth** for the task. Git problems are **fixable**: do the git work **inside `environment/repo`**, then re-zip the task. You may clean git metadata (remotes, stray branches/tags, reflog, `.git` size) and realign `task.toml` to HEAD — but you must still **never edit the repo's tracked source files**, since that's what anchors the task to the real PR.

When HEAD and the `base_commit_sha` declared in `task.toml` disagree, the shipped repo (HEAD) wins — realign the declared commit to HEAD. This misalignment mostly shows up on older tasks authored before a static-asset-generation fix; newer tasks generate the two in sync.

**Common git issues and how to fix them**

| Issue | Why it matters | Fix |
| --- | --- | --- |
| `.git` missing | No `.git` means there's no repo for the agent to work in — usually a zip tool that dropped dotfiles | Make sure `environment/repo/` is a real repo and `.git/` is in the zip |
| HEAD doesn't resolve | A detached, empty, or corrupt HEAD can't be checked out | Ensure the repo has at least one commit and HEAD points at it (`git rev-parse --verify HEAD`) |
| HEAD ≠ declared base commit | The agent must start from the commit `task.toml` declares; the shipped repo (HEAD) is the source of truth | `git checkout <base_commit_sha>`, or edit `task.toml` so its base commit equals HEAD |
| Commits / branches / tags beyond HEAD | Any ref past HEAD can carry the fix history and **leak the answer**, making the difficulty signal worthless | Delete them so `git rev-list --all --not HEAD` is empty; ship a single branch at the base commit with no stray tags |
| Remote configured | An escape hatch to external history and an untrusted-config surface; tasks must be self-contained and offline | `git remote remove <name>` for each remote |
| Filter drivers (`filter.*`) | clean/smudge drivers are arbitrary commands git can run (e.g. on `git status`) — a security risk and non-reproducible | Remove every `filter.*` section from `.git/config` |
| Dirty working tree | Uncommitted or untracked changes make the start non-reproducible, and an uncommitted solution leaks the answer | Commit or discard until `git status --porcelain` prints nothing |
| Reflog present (`.git/logs`) | Records rewound commits (like your solution) and bloats the repo | `git reflog expire --expire=now --all && git gc --prune=now`, then remove `.git/logs` |
| `.git` over 100 MB | Almost always accidental large blobs; slows every trial and wastes storage | `git gc --aggressive --prune=now`; if still large, strip big blobs or ship a fresh single-commit base history (then reset the base commit in `task.toml`) |
| `tests/tests.patch` won't apply | A patch cut against a different base fails on *every* trial and invalidates the run | Fix HEAD == base commit first, then regenerate the patch against the shipped repo state |

**Pre-submission checklist** — run inside `environment/repo` before you re-zip; every line should be clean or empty.

```
cd environment/repo

git rev-parse --verify HEAD                   # HEAD resolves
git rev-parse HEAD                            # == base_commit_sha in task.toml?
git rev-list --all --not HEAD                 # MUST be empty (no leaked commits)
git remote                                    # MUST be empty
git config --local --get-regexp '^filter\.'   # MUST be empty
git status --porcelain                        # MUST be empty (clean tree)
ls .git/logs 2>/dev/null                      # MUST NOT exist / be empty
du -sh .git                                   # MUST be < 100 MB
git apply --check ../../tests/tests.patch     # MUST apply cleanly
```

The [Before You Upload](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-tasking::before-you-upload) checklist in the Tasking Guide has more on regenerating `tests.patch` when it doesn't apply.

### ❌ Repo source files — never edit

![](<../Sentinel Ultra/GuideLines_files/dr-bubbles-salmon-sashimi-cb6802d2.svg>)

Never edit the **tracked source files** inside `environment/repo/`. The task is anchored to the real base repository; changing its code breaks that grounding and is not allowed. This is separate from git hygiene — cleaning `.git` metadata and restoring the tree to the base commit (see [Git — fixable in the repo](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable)) is allowed and expected.
