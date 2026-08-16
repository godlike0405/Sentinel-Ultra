# Reviewer Rubric
Reviewer Quality & Assessment Standards
Last updated: August 7, 2026
This guide defines the technical bar every Sentinel Ultra task must clear to be accepted, and the bar a reviewer's assessment of that task must itself meet. A Sentinel task exists to train and evaluate frontier coding agents, so the only thing that matters is that each task is correct, complete, and impossible to game: no broken oracle, no ungraded behavior, no way for an agent to pass without doing the real engineering work.
Reviewers are the last human gate before delivery. A miscalled verdict either ships a gameable task or bounces a clean one back into the backlog. Read this before your first review and return to it whenever you are unsure whether a task passes or a defect is real.
### 1. The Assessment Threshold
Every task is assessed against a tiered system. There are two independent paths to Needs Revision — both must be clear for a task to be accepted.
Path 1 · Single Major Defect. One confirmed violation of any Major Pillar is sufficient for Needs Revision. A Major defect means the task is gameable, unsolvable, or does not verify what it claims — severity overrides everything else in the task.
Path 2 · 5 or more Minor violations. Five or more Minor violations across any combination of Secondary Requirements trigger Needs Revision on systemic low quality. Tasks with 1–4 minor violations may be accepted with mandatory coaching comments.
#### Invalid vs. Fixable — call it correctly
Before assigning severity, decide which of three buckets the task is in. This is the distinction that costs ECs the most time.

Reviewers must tag Unfixable-Structure and Unfixable-Difficulty separately. Lumping them as "invalid" is what sends ECs into 3+ unpaid revision loops on tasks that were never fixable.
### 2. Major Pillars
A single confirmed violation in any pillar → Needs Revision, regardless of the rest of the task. Ordered by reviewer-flag frequency.
#### Pillar 1 — Oracle / Golden-Solution Correctness
Major · flagged in 51% of reviewer comments.
Standard: The golden patch must actually implement the solution the instruction describes, pass the graded tests deterministically, and introduce no behavior, files, or re-exports the instruction doesn't account for.
Meets: Oracle applies cleanly, all fail-to-pass tests pass on it, and every file/module/config it introduces is either stated in the instruction or derivable from the base repo.
Soft signal: Oracle passes but introduces a minor unstated helper or a config default an agent could still reasonably infer.
Needs Revision: Oracle fails its own tests, a NOP passes the tests, or the oracle depends on a path/module/value that appears only in the golden patch and is not stated or derivable.
#### Pillar 2 — Verifiability: fail_to_pass / pass_to_pass Integrity
Major · flagged in 45% of reviewer comments.
Standard: The declared fail_to_pass / pass_to_pass lists must match what the verifier actually grades. At least 10 outcome-based fail-to-pass tests, a regression test, deterministic.
Meets: Declared lists equal the verifier's real graded set; count ≥ 10; tests run real code and check real behavior.
Soft signal: A single test miscounted or misnamed but the graded behavior is still fully covered.
Needs Revision: Declared list undercounts/omits tests that gate reward, a static list-length check passes while the true graded count differs materially, or tests are trivial/gameable.
#### Pillar 3 — No Leakage / Not Reward-Hackable
Major · hints exposed in 21% of reviewer comments.
Standard: Nothing in the instruction or environment lets an agent shortcut the real work.
Meets: No PR URL, no solution spoilers, no hidden test details, no way to pass by editing tests.
Soft signal: Instruction is slightly over-prescriptive ("look in X") but does not hand over the solution.
Needs Revision: Solution hints, PR links, answer text, or test internals exposed; or the tests can be satisfied by editing them rather than solving the task.
#### Pillar 4 — Airgapped-Verifier / Network Integrity
Major · flagged in 41% of reviewer comments.
Standard: All graded behavior must be verifiable inside the airgapped verifier; network access must be correctly restricted in the shipped environment.
Meets: Tests pass with networking disabled; no graded behavior depends on external hosts; network_mode / allowed-hosts set correctly.
Soft signal: A non-graded setup step reaches the network but the graded path does not.
Needs Revision: Graded behavior requires internet the verifier won't have, or the shipped environment leaves network open where it should be restricted.
#### Pillar 5 — Git State / Repo Cleanliness
Major (early gate) · flagged in 31% of reviewer comments.
Standard: The shipped repo is a clean, single-history starting state with no leaked fix, no dangling objects, no stray remotes/worktrees/stash, HEAD == base.
Meets: git fsck clean (no dangling/unreachable), no refs/stash, no .git/logs leaking the fix, no extra remotes, HEAD matches the declared base commit.
Soft signal: Local artifacts (.venv, __pycache__, .DS_Store) left in the tree but no history leakage.
Needs Revision: Dangling commits / stash entries / reflog that expose the fix, leftover remotes or worktrees, or a HEAD/base-commit mismatch. Check this before assessing content.
### 3. Secondary Requirements (Minor — they accumulate)
Reach 5 or more across any combination → Needs Revision. Tasks with 1–4 are accepted with mandatory coaching comments.
Verifier timeout vs. config timeout mismatch (18%) — Verifier timeout set shorter than the task's own configured timeout (e.g. 1800s config, 300s verifier), which can kill valid solutions early. Mechanical; name the two numbers.
Base image / environment pinning (17%) — Unpinned base image or deps that make the build non-reproducible.
PR-scope violation (13%) — Task reduces/replaces the source PR rather than preserving or expanding it. If the ONLY fix is reducing PR scope, this escalates to Unfixable-Structure.
Test coverage gap (13%) — A behavior described in the instruction is not graded by any test, but core verifiability still holds.
Metadata mismatch (10%) — Files-changed counts or writeup don't match the actual diff.
Over-prescriptive instruction — Names exact functions/files/line numbers, removing the engineering challenge (short of full leakage).
Templated / AI-generated instruction — Reads like a generated prompt, not real engineering communication.
Instruction ambiguity — A choice the tests require is neither stated nor reasonably derivable, forcing guesswork.
Non-deterministic test — A graded test flakes across runs without a fixed seed/order.
Missing regression test — No test guards against reintroducing the bug.
Difficulty drift (recoverable) — Slightly under-difficult but raisable by expanding PR scope; only Minor if actually recoverable in-scope.
### 4. Reviewer Integrity — No LLM-Generated Reviews
Major. Applies to the reviewer's own written assessment, not the task.
Standard: Review content must be 100% original human engineering judgment, grounded in the actual task bundle and eval logs. Larger repos hit context limits; pasting LLM output or unrelated text into the review is a breach of review integrity.
Meets: Comments are specific and idiosyncratic — cite exact files, tests, config keys, or eval results from this task.
Soft signal (any 4 in one review = Major): uniform em-dash usage, exhaustive parallel bullet lists, mirrored instruction language, academic filler, zero natural typos, rubric-aware framing.
Needs Revision / flag: pasted LLM output or garbage text left in the review, meta-commentary ("as an AI", "the pasted diff"), references to content not in the task, or claiming logs are inaccessible when they are visibly present.
### 5. Quick Reference
#### Major Pillars

#### Secondary Requirements (accumulate — 5 = Needs Revision)

#### Verdict decision
Any Major → Needs Revision (name the fix), or Not Fixable if the fix is out of EC scope.
5+ Minor → Needs Revision (systemic).
1–4 Minor → Accept + mandatory coaching comments.
Unfixable → tag Structure vs Difficulty separately.

| --- | --- | --- |
| Bucket | Meaning | Reviewer action |
| Fixable | Defect is mechanical or content-level and the EC can correct it within scope (bad oracle, miscounted tests, git dirt, timeout mismatch, leaked hint, over-prescriptive instruction). | Needs Revision, with the specific fix named. |
| Unfixable — Structure | The only fix is to change/reduce the source PR scope, or the environment has issues ECs are not allowed to touch. | Mark Not Fixable; state the structural reason. Do not ask for revisions the EC cannot make. |
| Unfixable — Difficulty | Task is genuinely too easy/too hard and cannot be recalibrated without leaving the PR scope. | Mark Not Fixable for difficulty; keep distinct from structure so pay/routing treat it differently. |

| --- | --- | --- | --- |
| # | Pillar | Severity | Key trigger for Needs Revision |
| 1 | Oracle / Golden-Solution Correctness | Major | Oracle fails its tests, NOP passes, or unstated golden-only dependency |
| 2 | fail_to_pass / pass_to_pass Integrity | Major | Declared list ≠ graded set; <10 F2P; gameable tests |
| 3 | No Leakage / Not Reward-Hackable | Major | Hints/PR link/test internals exposed; passable by editing tests |
| 4 | Airgapped-Verifier / Network | Major | Graded behavior needs internet; network left open |
| 5 | Git State / Repo Cleanliness | Major (gate) | Leaked history, stash/reflog/dangling, HEAD≠base |
| — | Reviewer Integrity (LLM use) | Major | Pasted LLM/garbage text, or 4+ soft signals |

| --- | --- | --- |
| # | Requirement | Trigger |
| 1 | Timeout mismatch | Verifier timeout < config timeout |
| 2 | Base image / pinning | Unpinned image or deps |
| 3 | PR-scope violation | Scope reduced/replaced (→ Structure if only fix) |
| 4 | Coverage gap | Instructed behavior ungraded |
| 5 | Metadata mismatch | Files-changed / writeup ≠ diff |
| 6 | Over-prescriptive instruction | Names exact funcs/files/lines |
| 7 | Templated / AI-generated instruction | Reads generated |
| 8 | Instruction ambiguity | Required choice not derivable |
| 9 | Non-deterministic test | Flakes without seed/order |
| 10 | Missing regression test | No guard against re-break |
| 11 | Difficulty drift (recoverable) | Under-difficult but raisable in-scope |
