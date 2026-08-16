![Snorkel AI](<../Sentinel Ultra/Tasking Guide_files/snorkel_logo_header-1-04af18ea.svg>)

# Tasking Guide

Sentinel Ultra submission and review steps

---

## Submission Quick Start Guide

1. **Log in** — open the [Snorkel Experts platform](https://experts.snorkel-ai.com/home) and open the Submission task (search "Sentinel").
2. **Download your task zip** — it contains two folders: `task/` (the instruction, environment, solution, and tests you'll review) and `runs/` (agent attempt logs). Everything you'll inspect and edit is inside `task/`.
3. **Review** — decide Valid / Fixable / Not Fixable.
4. **If Fixable, rewrite** the instruction, tests, and/or oracle.<br>4b. **Prepare your upload:** zip only the contents of the `task/` folder — not the folder itself, and not `runs/`. The zip should unpack directly to `instruction.md`, `task.toml`, `environment/`, `solution/`, and `tests/`.
5. **Run evals** via the platform button; iterate until checks pass.
6. **Submit** — check *Send to reviewer* and submit.

📹[Sentinel Ultra Submission Flow Walkthrough](https://www.loom.com/share/52a317cb90674f8eb18b9bd208d7b01a)

---

## Before You Upload

Run these checks locally before you zip and submit. They're the failures that produce "0/8 valid trials — infra/harness failure" difficulty bounces and packaging-axis failures. They reproduce identically on every run, so resubmitting an unchanged zip will always fail the same way — verify locally first.

1. **`tests.patch` must apply cleanly to the base commit.** The most common infra failure. The fail-to-pass tests are injected by applying `tests/tests.patch` onto `environment/repo` at `base_commit_sha`. If the repo drifted, the patch was cut against a different base, or the f2p tests are already baked into the repo, every trial fails before any evidence is collected. Verify locally:
    ```
    unzip <your_task>.zip -d task && cd task
    cd environment/repo
    git stash -u 2>/dev/null
    git checkout $(grep base_commit_sha ../../task.toml | cut -d'"' -f2)
    git apply --check ../../tests/tests.patch      # must succeed with no output
    ```
    If it fails (`Hunk #N FAILED` / `does not match index`), regenerate the patch: from the repo at `base_commit_sha`, confirm the target test files are in their original state (they must not already contain the new f2p tests — the patch is what adds them); apply your fail-to-pass test additions by hand; `git add -A && git diff --cached -- <test paths> > ../../tests/tests.patch`, then `git checkout .` to restore the repo to base. Re-verify with `git apply --check`, then run the oracle + tests end to end. Common traps: the repo copy already includes your new tests (patch re-adds them → conflict); the patch touches a non-test file (e.g. `CMakeLists.txt`) that has since changed.
2. **Never modify pre-existing (regression / pass-to-pass) test files.** The harness checks that pre-existing test files are byte-identical to the base commit. If your fix seems to require changing an existing test, add a new test through `tests/tests.patch` instead (new functions or new files only), and revert the existing file to its `base_commit_sha` content.
3. **The Dockerfile must build offline.** The sandbox is network-restricted. `docker build environment/` locally and make it hermetic: run `apt-get update` before installs, use packages that exist in the base image's distro, pin the base image to a concrete tag (never `:latest`), avoid build-time downloads, or switch to a base image that already ships the tools you need.
4. **Git-history hygiene on `environment/repo`.** The repo must pass all of the git checks — `HEAD` equals `base_commit_sha`, no commits after the base, no remotes, no `filter.*` drivers, a clean working tree, `.git/` under 100 MB, and no reflog. These are **fixable**: do the git work inside `environment/repo` and re-zip — but never edit the repo's tracked source files. See [Git — fixable in the repo](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable) in the Guidelines for the full issue-by-issue breakdown and a pre-submission checklist.
5. **No stray artifacts or leakage in the bundle.** Before zipping, sweep the task directory:
    ```
    find . -name '__pycache__' -o -name '*.pyc' -o -name '.DS_Store' \
      -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \
      -o -name '.venv' -o -name 'node_modules' -o -name '.idea' -o -name '.vscode' \
      -o -name '*.swp' -o -name '*~' -o -name '*.orig' -o -name '*.bak'
    ```
    Delete everything the sweep finds — any one of these shipping into the container hard-caps the packaging score at 1. Confirm no solution material (golden patch content, expected outputs, `ground_truth.*` files) is readable from agent paths in the built image. Intentional dotfiles are fine: `.gitignore`, `.dockerignore`, `.gitattributes`, `.gitkeep`, `.github/`, `.env` when the task warrants them. `environment/problem_statement.md` must be an exact copy of `instruction.md` — re-copy it after any instruction edit. If the downloaded task contains `solution/solution.patch`, rename it to `golden.patch`. Zip the flat contents of `task/` only — no `runs/`, no wrapping `task/` folder; the zip should unpack directly to `instruction.md`, `task.toml`, `environment/`, `solution/`, and `tests/`.
6. **`task.toml` sanity.** Resource and timeout values within the published limits; `gpus` always `0`. Remove `network_mode` and `allowed_hosts` if present. `category`, `difficulty_explanation`, and the source URL accurate — the judge's packaging axis cross-checks metadata against the actual task content.
7. **Full local dry run** (required for Valid as-is, recommended for Fixable).
    ```
    docker build -t task-env environment/            # env builds offline
    # oracle run: apply golden.patch via solution/solve.sh, then run tests -> reward 1.0
    # NOP run:    run tests on the unsolved repo   -> reward 0.0 (f2p fail, p2p pass)
    ```
    Valid as-is tasks are not re-run by the platform's difficulty evals — your local run is the only check on them. For Fixable tasks the platform runs these on submission, but a local run saves you an eval round-trip.

---

## Detailed Tasking Steps

Use these steps for every task. If terminology or steps are unclear, see the Harbor documentation or reach out to fellow ECs or the Snorkel team on the Slack channel.

1. **Read the instruction** — Start with `instruction.md`. Note requirements, expected behavior, success criteria. (It should describe the problem and contract, not prescribe implementation or expose verifier internals — see [Clarity & No Leakage](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::2-clarity-no-leakage).)
2. **Cross-check the source PR and check `task.toml`** — Confirm that the task reflects the intended change and does not introduce unrelated scope (if expanding scope, confirm it's a natural extension). Also open `task.toml` and confirm its fields meet our requirements: the resource and timeout values are within the allowed limits, `gpus` is `0`, and `network_mode` / `allowed_hosts` are removed. See [Task Metadata](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-harbor::task-metadata) for the full list of fields and limits.
3. **Scan the environment** — Read `environment/Dockerfile` and skim `environment/repo/` to judge whether setup and codebase context look plausible for the instruction. **Build the environment locally in Harbor** (`docker build environment/`) to confirm it builds offline — the sandbox is network-restricted, so a build that reaches the network will fail.
4. **Review the solution artifacts** — Read `solution/solve.sh` and `solution/golden.patch`. Check that they appear to implement the instruction, and that the change is substantive (roughly 100+ lines spanning 2+ files). **Run the oracle locally in Harbor** — apply the golden patch via `solution/solve.sh`, then run the tests and confirm it reaches reward 1.0. (See [Rewriting the Oracle](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::solution-oracle-editable-in-two-cases) for what a sound oracle looks like.)
5. **Review the tests** — Read `tests/test.sh`, `tests.patch`, `config.json`, and `grade.py`. The fail-to-pass tests live in `tests.patch`; `config.json` declares which test ids are fail-to-pass and pass-to-pass and how the suite runs. Check that fail-to-pass coverage and assertions map to the instruction's requirements, and confirm your edits don't break any pass-to-pass test. Count the fail-to-pass tests: every task needs **at least 10** (ideally 10–20). If there are fewer, the task is Fixable — add tests covering stated or implied requirements during your rewrite. (See [Verifiability](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::3-verifiability) for the full test bar.)
6. **Review agent runs** — Open the `runs/` folder (it sits alongside `task/` in your downloaded zip) for evidence of timeouts, systematic misinterpretation, or instability. Cite concrete observations when they support your verdict or a timeout/metadata tweak.
7. **Run evals** before submitting — See [Section 3: Run Evals](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#section-3-run-evals). If the task is too easy after your rewrite, consider whether expanding PR scope is appropriate.
8. **Compile your findings** and submit via the platform.

**Remember:** *Your goal is a thorough, exhaustive review of the task's* **logic and content***. Check for coherent instructions, aligned tests and solution artifacts, sensible metadata, and use of runs/ when relevant. If you miss key findings or your submission lacks detail, the task may be sent back for revision.*

## Step-by-Step Submitter Form Questions

### Section 1 · Task Metadata

Download the task zip provided at the top of the form. It contains the task you'll inspect and make corrections to.

### Section 2 · Task Analysis

**What is your analysis of the Sentinel task you downloaded above?**

**Note:** This question appears twice in the platform, and both are required. Please make sure that both answers are the same.

- **Fixable** — The task has issues in the instructions, tests, and/or oracle, but you can correct all issues.
- **Invalid/Not Fixable** — The task is invalid and/or unfixable, as it requires changes outside of the instructions, tests, or oracle, or is invalid for other reasons.
- **Valid as-is** — The task is valid without changes.

---

**If Valid as-is:**

Confirm the task complies with **all** of the following requirements (you must check every item):

- Every requirement in the instructions is properly tested
- All test requirements are properly specified in the instructions
- The instructions do not sound like an LLM generated them
- The instructions are not overly-prescriptive
- The task does not leak solution information
- The oracle implements the solution following the instructions
- Contains more than 10 fail-to-pass tests in the test suite

Before submitting, **run the oracle and NOP tests locally** to confirm the task passes. Valid as-is tasks aren't re-run by the platform's difficulty evals, so this is the only check on them.

---

**If Fixable:**

1. **Select where the task had issues** (check all that apply):
  - Instructions
  - Tests
  - Oracle Solution
  - Environment / Dockerfile
2. **What issues did you find with the task?** (check all that apply):
  - Every requirement in the instructions is not properly tested
  - All test requirements are not properly specified in the instructions
  - The instructions appear LLM generated
  - The instructions are overly-prescriptive
  - The task leaks solution information
  - The oracle does not implement the solution following the instructions
  - Less than 10 fail-to-pass tests in the test suite
3. **Describe each issue in detail** — For each issue category selected above, use this format: 1) [Issue Category] — describe the specific issue with code examples where helpful<br>— Is this issue fixable or not fixable?<br>— If fixable, how? If not, why not?<br>2) [Issue Category 2]...
4. **Re-upload the entire corrected task as a single zip file.** Submit it as `<all-task-content>` — do not include `runs/` or the `task/` directory itself. The zip should unpack directly to `instruction.md`, `task.toml`, `environment/`, `solution/`, and `tests/`. **After you upload, you'll run evals and iterate right away** — keep re-running and fixing until the checks pass and the task is error-free, then come back and fill in the rest of this form. See [Section 3 · Run Evals](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#section-3-run-evals) below. Running the oracle and NOP locally in Harbor is recommended for Fixable tasks — the platform's evals run them when you submit, but a local run saves you an eval round-trip.
5. **Files Changed** — List every file you changed. For each file, include:
  - File path
  - What changed
  - Why you changed it<br>*(You do not need to repeat full validation details here if you already included them in the validation section.)*
6. **If you added to the PR in any way, explain how.** If you did not modify the PR in any way, write "NA". Remember you may not change or reduce the scope of the PR, but you may expand on it to add complexity.
7. **Confirm your corrected task meets all the following requirements** (you must select all):
  - Every requirement in the instructions is properly tested
  - All test requirements are properly specified in the instructions
  - The instructions do not sound like an LLM generated them
  - The instructions are not overly-prescriptive
  - The task does not leak solution information
  - The oracle implements the solution following the instructions
  - The PR was not modified in any way beyond what is allowed by the guidelines
  - More than 10 fail-to-pass tests in the test suite
8. **How long did it take you to complete the initial task rewrite only?** (in minutes)

---

**If Invalid/Not Fixable:**

1. **What issue did you find with the task/components?** (check all that apply):
  - PR scope needs to be changed or reduced
  - Environment Issues
2. **If Environment Issues was selected above, what specific issues did you find with the task?** (check all that apply):
  - Image/Dependency Build Failures
  - Oracle timeout
  - External-network dependency at build/solve time
  - Dirty git history that can't be recovered — rare; most git issues are fixable (see [Git — fixable in the repo](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::git-fixable)), so only select this for genuinely unrecoverable corruption
3. **Explain in more detail why this task is unfixable** — Describe each issue clearly. Vague or incomplete descriptions may lead to the submission being rejected.

---

**For Valid as-is and Fixable tasks:**

- **What makes this task difficult?** Describe what makes the task technically challenging — edge cases, implementation dependencies, requirements that may be overlooked on first reading, or complexity in the test setup. See [PR Scope and Task Difficulty](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::pr-scope-and-task-difficulty) in the Guidelines for what counts as good vs. bad difficulty.

---

**Final Comment and Handling Time (all paths):**

- **Comments for Reviewer** — Flag anything that would help the reviewer understand the task and your decisions: assumptions you made, edge cases you considered, reasons you didn't change a file, or parts of the task that may warrant reviewer judgment or a second opinion.
- **How much time would you estimate a senior engineer, familiar with the codebase, would take to solve this?**
  - <10 minutes
  - 10–20 minutes
  - 20–40 minutes
  - 40+ minutes
- **How long did it take you to review the initial task and determine its validity?** (in minutes)
- **How long did it take you to complete this entire submission?** (in minutes — if the task is sent back for revision, adjust this number to include the additional time)

### Section 3 · Run Evals

Once you've made changes, the platform runs automated checks on your task and surfaces feedback you can use to iterate. These checks catch issues before your task reaches a reviewer. (This Submission Feedback section appears for Fixable tasks.)

**Static Checks**

Click **Check feedback** under Static Checks for instant feedback on the task (structure and Dockerfile validation). These must pass for the task to be eligible for submission.

**Summary fields**

After your bundle runs, three read-only summaries are populated:

- **Difficulty Check** — Results of the agent simulation and stats for each verifier.
- **Oracle Check** — Results of running the golden solution against the verifiers.
- **Quality Check** — an agentic rubric-panel judge that scores your task and **can block submission**. A failing verdict sends the task to `NEEDS_REVISION` just like a failing difficulty or oracle check. See [Quality Check — the agentic rubric-panel judge](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#quality-check-agentic-judge) below.

You can also **Download difficulty check results** for the full logs, useful for debugging specific failures. Run the checks as many times as you need; each run produces fresh feedback.

**Send to Reviewer**

Check **Send to reviewer** to send the task to the reviewer once difficulty and quality checks are passing. If checks are failing when this is checked, the task will always result in revision — if you are intentionally sending it with failing checks, leave detailed comments for the reviewer explaining why.

*Note: In-app checks have a 5-minute runtime limit. If your task needs longer agent runs to fully evaluate, iterate with the box unchecked first.*

**What to Do When Checks Fail**

The goal is to revise and re-run until there are no failures before sending to the reviewer.

1. Review the summaries and download the full logs to understand the failure.
2. Revise your task (instruction, tests, solution, or Dockerfile as needed — within editing rules).
3. Re-upload and re-run with Send to reviewer unchecked.
4. Repeat until checks pass, then check Send to reviewer and submit.

#### Quality Check — the agentic rubric-panel judge

When you run evals, an automated rubric panel now reviews your task the same way a human reviewer would. Two independent LLM judges (Claude Opus and GPT-5.5) each read your instruction, tests, oracle solution, and task directory, and score the task against four rubrics (10 axes total, each 1–5). Where the two judges disagree by 2 or more points on an axis, a third blinded adjudicator settles it. The result appears in the Quality Check summary after your bundle runs, with a per-axis report and justifications that cite specific files and lines — read them; they tell you exactly what to fix.

**This is a blocking eval.** A failing verdict sends the task to `NEEDS_REVISION`, just like a failing difficulty or oracle check.

##### The 10 axes

| Rubric | Axes | What it reads |
| --- | --- | --- |
| Instruction quality | realism, clarity, self-containedness, prescriptiveness | `instruction.md` + environment only |
| Test quality | **test_coverage, test_faithfulness** | instruction + every test file |
| Oracle quality | spec faithfulness, no gaming, robustness/reproducibility | instruction + `solution/` |
| Packaging | packaging | directory listing + `task.toml` + Dockerfile |

##### What actually blocks your submission

The pass/fail verdict is driven by the two test-quality axes only: **test_coverage** and **test_faithfulness**. The other eight axes are scored and shown in the report (fix them — reviewers see them too), but they don't flip the verdict on their own.

The verdict logic:

- **REMOVE** (fails, `NEEDS_REVISION`) — the adjudicated score on either test axis is ≤ 2.0, or either judge scored an axis ≤ 2 and the failure matches one of the "essential" patterns below.
- **DISCUSS** (fails, `NEEDS_REVISION`) — any single judge scored either test axis ≤ 2, or the adjudicated score on either axis is ≤ 3.0.
- **OK** (passes) — both test axes land above 3.0 with no judge at ≤ 2.

**Practical bar:** both judges need to rate your test suite a solid 4+ on coverage and faithfulness. A single "3 with reservations" from one judge is enough to bounce the task. Borderline scores round down by design — don't argue with a 3, fix it.

##### The two questions the judge asks about your tests

Both axes are two sides of the same question: *is the verifier a fair grader of the contract written in the instruction?* This is exactly the [Test ↔ instruction alignment](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::test-instruction-alignment) principle in the Guidelines — the judge now enforces it mechanically, in both directions:

- **Coverage (Instruction → Tests):** every requirement stated in the instruction has a real, enforcing assertion. A broken or stub solution must fail at least one test. Gaps here mean **false positives** — an agent gets reward 1.0 without doing the work.
- **Faithfulness (Tests → Instruction):** every assertion maps back to something stated or reasonably implied in the instruction. Hidden requirements mean **false negatives** — a competent engineer who follows the instruction exactly still fails.

##### Patterns that trigger an automatic REMOVE

These six patterns are treated as customer-essential defects. If a judge scores a test axis ≤ 2 and cites one of these, the task is removed outright — no "discuss" middle ground:

| Pattern | What it looks like in a task |
| --- | --- |
| Silent skip | `@pytest.mark.skip`, `skipif`, catching `ImportError` and setting the module to `None`, or any construct that lets substantive tests silently not run. If a dependency is missing, the test must fail, not skip. |
| No CLI/entry-point invocation | The instruction asks for a CLI, service, or script, but `test.sh` only runs pytest against library internals and never actually invokes the thing being built. |
| Pre-created artifact passes | Tests assert a file exists (`path.exists()`, `is_file()`) without checking its contents, so `touch`-ing the right filename passes. Every existence check must be paired with a content/behavior assertion. |
| Agent controls coverage | Tests iterate over whatever the agent's own output reports (e.g. loop over entries in the agent's JSON and validate each) — the agent can shrink its output to shrink the test surface. Enumerate expected items from the instruction/environment, never from agent output. |
| Fail-open | `if not output.exists(): return`, `try: ... except Exception: pass`, assertions gated behind preconditions that may not hold. A missing or malformed artifact must fail the suite, never pass it. |
| Overreach | Tests enforce names, formats, thresholds, paths, or conventions the instruction never states (the [arbitrary naming problem](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::the-arbitrary-naming-problem) already in the Guidelines — now machine-checked). |

##### Test-writing checklist

**Do:**

- Map every imperative, named output field, named edge case, and named threshold in the instruction to at least one assertion. The judge literally builds this bipartite mapping; build it yourself first.
- Test observable behavior at the instruction's stated strictness — if the instruction says "all rows", don't assert "at least one row"; if it names a threshold, assert the threshold, not just `isinstance(score, float)`.
- Include the regression test that reproduces the original failure (fails pre-patch, passes post-patch) — already required; the judge checks for it.
- Keep tests deterministic: fixed seeds, no order dependence, no wall-clock or network dependence.
- Commit fixtures and mock data into the verifier image so the agent can't tamper with them.
- If the instruction requires a specific output format/schema, state it in the instruction — that makes your format assertions faithful instead of hidden.

**Don't:**

- Don't assert on source code text (substring/keyword scans like `"deque" in source`) — the judge flags source-pattern checks as unfaithful, and they're trivially gamed anyway.
- Don't embed verifier-only constants (`EXPECTED_COUNT = 47`) the agent can't derive from the instruction and environment.
- Don't compare against hidden golden files the instruction never foreshadows.
- Don't compute the expected value from the agent's own output (circular checks).
- Don't require exact error strings, JSON key orderings, whitespace styles, tolerances, or file paths unless the instruction (or an existing codebase/framework convention) fixes them.
- Don't wrap test bodies in broad `try/except` — ever.

##### The advisory axes still matter

The other eight axes appear in the Quality Check report and in what your reviewer reads, and they reinforce existing guideline requirements:

- **Instruction axes** — the judge rewards instructions that read like a real ticket (realism), fully specify success (clarity), reference only artifacts that exist in the repo (self-containedness), and state requirements, not procedure (prescriptiveness). Detailed output schemas and conventions are fine and score well; ordered how-to steps, file localization hints ("the bug is in `helpers/queue.py`"), and pre-answered edge cases score badly — the same over-prescription rules already in [Clarity & No Leakage](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::2-clarity-no-leakage).
- **Oracle axes** — the oracle must implement every instruction requirement with the correct logic (spec faithfulness), must genuinely do the work — no hardcoded answers, no fabricated tool output, no reading test-side ground truth, no fixture-specific shortcuts like treating `df['Date'].max()` as "today" (no gaming) — and must be reproducible: seed randomness, no live network calls, timeouts on subprocesses (robustness). Litmus test the judge applies: *"if the inputs were reshuffled within the spec, would this oracle still produce the right answer?"*
- **Packaging** — a single stray developer artifact that ships into the container (`__pycache__/`, `.DS_Store`, `.venv/`, `.pytest_cache/`, `.idea/`, `.vscode/`, editor swap files, `.ruff_cache/`, `node_modules/`) hard-caps this axis at 1, as does any solution leakage into agent-readable paths. See the [Before You Upload](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#before-you-upload) hygiene checklist.

##### If the Quality Check fails

1. Download the report and read the per-axis justifications — they cite the exact files, line ranges, and quoted instruction text behind each score.
2. Fix the cited defect. For coverage gaps, add or strengthen assertions; for faithfulness defects, either move the requirement into the instruction or relax the assertion.
3. Keep instruction, tests, and oracle in lockstep (per the existing editing rules), re-upload, and re-run with Send to reviewer unchecked until the check passes.

## Step-by-Step Reviewer Form Questions

![](<../Sentinel Ultra/Tasking Guide_files/dr-bubbles-matrix-0a61cff9.svg>)

Each submission is reviewed by another Expert Contributor (EC). The reviewer’s role is to independently verify the submitter’s findings, assess the quality and completeness of the analysis, and confirm that conclusions are supported by evidence from the task files and review process.

Reviewers should repeat the same document and logic review performed by the submitter. You're not required to run Harbor end-to-end, execute the Oracle or NOP tests, or build Docker images locally — but you may if it helps you verify a finding.

### Review Outcomes

- **Accept** — The submission is accurate, complete, and well-supported.
- **Needs Revision** — The task has authoring errors in the instruction, tests, oracle, or bundle that the original submitter can fix.
  - Note: Severity of the submitter errors are captured in the [Submission Quality Score](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#submission-quality-score)
- **Reject** — Use this **only** when a submission has already been through the **maximum number of revision cycles** and still needs more work. Reject is not a substitute for Needs Revision: as long as the submitter can still revise, choose **Needs Revision** so they get another chance to fix the task.

You'll know you've reached this case because **Needs Revision** is no longer available. If you select Needs Revision and try to submit, the platform blocks you with a **"Maximum Revisions Reached"** dialog:

**Maximum Revisions Reached**<br>This submission has reached its maximum revision limit. The "Needs Revision" option is not available. If the submission does not meet quality standards, select **Reject**. If Reject is not available for this workflow, **Accept** and add notes explaining the issues.<br><br>*Reviewer-only note: Your notes will be visible to the adjudicator.*<br>[ I Understand ]

When you see that dialog, click **I Understand**, then select **Reject**. If Reject isn't available for the workflow, select **Accept** and document the outstanding issues in your notes so the adjudicator can see them.

### Reviewer Responsibilities

- Reviewers reach their own independent assessment of the task, then give a verdict of **Accept**, **Needs Revision**, or **Reject** — regardless of whether it matches the submitter’s original rating. Reject is reserved for submissions that have exhausted their revision cycles (see [Review Outcomes](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#review-outcomes)).
- Reviewers are also evaluated on the quality of their feedback and the thoroughness of their review. Consistently low-quality reviews or feedback that does not meet project standards may result in removal from the project.
- Reviewers must check the **Comments for Reviewer** field before completing the review and acknowledge whether the submitter's notes changed their decision.

### When the submission is **Valid As-Is**

The reviewer should repeat the submitter’s **content review** and confirm the task reads as sound on inspection.

1. **Repeat the submitter’s workflow** — Download the task package and follow the same steps as in [Detailed Tasking Steps](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#detailed-tasking-steps): instruction, PR cross-check, environment skim, solution and test read-through, and runs/ as context. You're not required to run Harbor, the oracle, or NOP locally, but you may if it helps.
2. **Sanity-check coherence** — Confirm instruction, solution artifacts, and tests appear aligned with each other and with the source PR; flag any logic gaps the submitter missed.
3. **Verify task metadata** — Confirm that the task task.toml metadata is complete and accurate. Recall that only the source, verifier, agent, and environment timeouts affect validity.
4. **Confirm PR comparability** — The submitted task should not deviate from the original PR scope. Check this even on Valid as-is submissions.

### When the submission is **Not Fixable/Invalid**

The reviewer should try to confirm the submitter’s results and confirm that the submitter’s notes are correct and adequately describe the situation.

1. **Confirm the reported issues** — Follow the same document review as for a valid submission. For each issue the submitter listed, confirm it holds when you read the same files (e.g. instruction vs tests, patch vs PR, missing coverage, inconsistent solution).
2. **Compare against the submitter’s findings** — Check that the submission’s issue list (e.g. Issue 1, Issue 2, …) matches what you see on inspection. Verify that categories (instruction, environment, solution, tests, etc.) and descriptions are accurate.
3. **Confirm the Not Fixable category applies** — Reviewer should agree the reason matches one of the [Not Fixable categories](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::task-verdicts) defined in the Guidelines.

### When the submission is Fixable

The reviewer should confirm that the submitter correctly identified fixable issues and that the rewritten instructions and/or tests appropriately resolve those issues without introducing new inconsistencies, hidden requirements, or information leakage.

1. **Review rewritten artifacts** — Inspect the uploaded rewrites and confirm that they resolve the reported issues, preserve instruction ↔ test alignment, maintain solvability, and do not introduce unnecessary implementation constraints or verifier leakage.
2. **Validate task quality after rewrites** — Confirm that the corrected task still reflects the intended PR behavior, remains realistic and solvable, and does not introduce new hidden requirements or inconsistencies.
3. **Verify PR comparability —** If the submitter expanded oracle scope, confirm the expansion only adds to the original PR. The task should not have been reduced or changed to a different feature. See [PR scope rules](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#tab-guide::pr-scope-rules) in the Guidelines.
4. **Verify uploaded files —** Confirm that the upload contains the full corrected task bundle.
5. **Review agent logs —** Where relevant, review the provided agent logs to see how agents interpreted the task and whether the submitter's feedback (e.g. "agent times out" or "instruction ambiguous") is supported by the evidence.

### Reviewer Form Questions

1. **What is your verdict for this submission?**
  - **Accept** — Agree with the Valid / Invalid selection by the submitter and any applied fixes.
  - **Needs Revision** — Any task that still contains errors.
  - **Reject** — Use this **only** if you are seeing the "maximum revision reached" notification **and** the submission still needs more revisions. See [Review Outcomes](https://snorkel-ai.github.io/Sentinel_Ultra_Hub/#review-outcomes) above.
2. **If Accept:** Confirm the task meets all of the following requirements (check all that apply):
  - Tests every requirement in the instructions
  - Test requirements are specified in the instructions
  - Does not appear generated by an LLM
  - Does not leak solution information
  - Oracle solution matches the instruction requirements
  - Instructions are not overly-prescriptive
3. **If Needs Revision — Error Categories:** Tag the issues you found in the submitted task that led to your Needs Revision decision. These may be issues the submitter introduced or base-task issues they failed to catch or correct. Select all that apply — these labels are for internal tracking only and do not replace thorough revision notes.
  - Instruction Styling
  - Instruction Prescriptiveness
  - Test ↔ Instruction Misalignment
  - Test Coverage Issues
  - Exposing Hints/Answers
  - Oracle Solution Issues
  - PR Scope Violation (e.g., reduced or replaced PR scope rather than adding to it)
  - Test Build Issues
  - Time-Based Tests
  - Task Difficulty
  - Metadata Issues
  - Uses Internet
  - Agent Timeout
  - Wrong Coding Language
  - Test Dependency Location
  - Pinning Issues
  - Environment
  - PR Relevancy
  - Other
4. **If Needs Revision:** Explain in more detail what revisions are needed from the submitter based on your selection(s) above.
5. **Acknowledgement of Submitter Rebuttal:** Before submitting, open the rebuttal comments in the left-hand panel and read the submitter's notes in full. Confirm one of the following:
  - I read the submitter's rebuttal and it does not change my review outcome.
  - I read the submitter's rebuttal and revised my review outcome accordingly.
  - No rebuttal comments available.
6. **What is the overall quality of the submission?** *(Based on Submission Quality Score below)*
7. **How long (in minutes) did it take you to complete this review?**

### Submission Quality Score

You’ll then give the submission an overall quality score. This rating should reflect the accuracy, completeness, reasoning, and specificity shown in the submission.

| Score | Description | Action |
| --- | --- | --- |
| **1** | The submitter has deviated from the provided source content (e.g., wrong PR, substituted repo code, or otherwise diverging from the source asset), or the submission is low-effort, sloppy, or appears to be spam. | **NEEDS REVISION** |
| **2** | The source material is intact but execution has noticeable gaps — untested requirements, instruction/test misalignment, or bundle mismatches — that need meaningful revision. | **NEEDS REVISION** |
| **3** | The task is correct and complete; any remaining issues are too minor to warrant sending back for revision. | **ACCEPT** |
| **4** | All components (instruction, oracle solution, tests, bundle) are thorough and accurate with no significant issues. | **ACCEPT** |
| **5** | Every component is precise, well-reasoned, and clearly written — a reference-quality submission requiring no changes. | **ACCEPT** |
