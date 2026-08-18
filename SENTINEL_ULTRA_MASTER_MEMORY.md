# Sentinel Ultra Master Memory

This is the consolidated operational memory for creating, reviewing,
modifying, fixing, validating, and packaging Sentinel Ultra tasks in this
workspace.

It unifies three persistent sources:

1. `Complete_Data/` — official contributor guidance, tasking guide, Harbor
   framework, glossary, FAQ, and Reviewer Rubric.
2. `SENTINEL_TASK_WORKFLOW.md` — the user's standing workflow, verdict branches,
   form structure, prescriptiveness rules, recurring failures, oracle policy,
   and difficulty guidance.
3. `.codex-task-review-memory.md` — reusable lessons from automated-review and
   verifier failures.

The original files remain the detailed provenance. `AGENTS.md` still requires
the workflow and review-memory files to be read completely before task work.
When this master summary and a source differ, follow the newest explicit user
instruction and the more specific rule, never misrepresent validation, and
record the conflict.

## 1. Start of every task

- Work under `./fix_data`.
- Announce the task/package, applicable rule sources, audit scope, planned
  Docker/patch/NOP/oracle checks, and start of handling-time tracking.
- Do not preselect a verdict.
- Read the complete task: instruction, problem statement, metadata,
  Docker/environment, repository, solution, verifier, tests, grading config,
  packaging, and supplied run/eval logs.
- Check Git integrity before assessing content because leaked history is an
  early Major gate.

## 2. Core acceptance contract

Every task must be:

- Solvable from the instruction and shipped environment without arbitrary
  guessing.
- Clear about behavior and public contracts without prescribing implementation.
- Free of PR, solution, golden-patch, test, verifier, and history leakage.
- Verifiable by deterministic, outcome-based, reward-hack-resistant tests.
- Authentic, substantial engineering work anchored to a real source PR,
  commit, or issue.

Preserve the complete source scope. Natural additive expansion is permitted;
scope reduction, replacement, or substitution is not. Never edit tracked
source files inside `environment/repo`.

## 3. Verdicts

### Valid as-is

- No file requires correction.
- Instruction, tests, oracle, PR scope, environment, Git, metadata, and package
  all satisfy the rules.
- Required local oracle and NOP validation has succeeded.
- Give `Valid as-is` in both duplicate validity fields and answer only the
  Valid-as-is form branch.

### Fixable

- Every defect can be corrected within permitted instruction, test, oracle,
  metadata, Docker/environment, packaging, or Git-metadata changes.
- Fix every permitted material error, including additional errors discovered
  during answers or validation.
- Keep instruction, problem statement, tests, oracle, and metadata in lockstep.
- Give `Fixable` in both duplicate validity fields and answer only the Fixable
  branch after the corrected task passes the audit.

### Invalid/Not Fixable

- Use only when the necessary correction lies outside EC scope.
- Identify **Unfixable-Structure** when the only correction requires reducing
  or replacing source scope or prohibited environment changes.
- Identify **Unfixable-Difficulty** separately when difficulty cannot be
  recalibrated without leaving source scope.
- Exhaust safe permitted checks first. Ordinary instruction, test, oracle,
  metadata, packaging, and recoverable Git defects are Fixable.
- Give the same Invalid/Not Fixable verdict twice and answer only that branch.

## 4. Reviewer Rubric gate

Two independent routes require revision:

- One confirmed Major Pillar defect.
- Five or more accumulated Secondary/Minor defects.

One to four Minor defects require specific coaching comments in a review; when
creating or fixing a task, correct them instead of knowingly shipping them.

### Mandatory 10-axis Agentic Judge threshold

Assess `clarity`, `oracle_no_gaming`, `oracle_reproducibility`,
`oracle_spec_faithfulness`, `packaging`, `prescriptiveness`, `realism`,
`self_containedness`, `test_coverage`, and `test_faithfulness` independently.
Every axis must reach at least **3.5/5** before the task is ready. Use actual
platform scores when available; otherwise label the result as an internal
preflight estimate. Revise any axis below threshold, cite exact evidence per
axis, and do not average away a low individual coverage/faithfulness concern.

### Major Pillars

1. Oracle/golden correctness: applies cleanly, implements the instruction,
   passes the real graded suite deterministically, and has no unstated
   golden-only dependency. Oracle failure or NOP success is Major.
2. F2P/P2P integrity: declared IDs exactly match executed reward-gating tests;
   at least 10 real outcome-based F2P tests plus a regression test; no stale,
   duplicate, skipped, deselected, misnamed, or non-gating IDs.
3. No leakage/reward hacking: no PR/answer/test/verifier spoilers and no route
   to pass by editing or forging the verifier surface.
4. Airgapped verifier: graded behavior works without internet or live services.
5. Git state: clean single-history base, HEAD equals declared base, and no
   leaked refs, remotes, worktrees, stash, reflog, dangling/unreachable objects,
   or filter drivers.

### Secondary/Minor inventory

Count separately: verifier/config timeout mismatch, unpinned image/dependencies,
PR-scope violation, coverage gap, metadata/writeup mismatch, prescriptiveness,
generated instruction style, ambiguity, nondeterminism, missing regression
test, and recoverable difficulty drift.

## 5. Instruction and prescriptiveness

- State the engineering problem, public contract, constraints, and observable
  acceptance criteria: the **what**, not the **how**.
- Ask: **Could a competent agent reasonably discover this by exploring the
  codebase?** If yes, omit it unless it is a genuine public contract or required
  observable behavior.
- Remove ordered procedures, file/symbol/line localization, root-cause spoilers,
  solution code or revealing pseudocode, exact internal algorithms/data
  structures, hidden-test/verifier references, and pre-answered diagnostic
  details.
- Public API names, CLI flags, schemas, formats, thresholds, error semantics,
  compatibility constraints, and product edge cases are appropriate when the
  implementation cannot otherwise derive them.
- Do not remove a legitimate contract merely to appear less prescriptive; doing
  so can create hidden requirements and ambiguity.
- Instructions must read like genuine engineering communication, not a robotic
  template.
- `instruction.md` and `environment/problem_statement.md` must be byte-identical.

## 6. Instruction-to-test and test-to-instruction alignment

- Build a requirement-to-assertion matrix before packaging.
- Every imperative, output field, threshold, mode, edge case, and negative
  isolation guarantee requires an enforcing assertion.
- Every assertion must map to a stated or reasonably derivable contract.
- Exercise every promised runtime/input mode independently. A test of one mode
  does not prove another.
- Test positive and negative ownership where required; proving one initializer
  runs does not prove another initializer stays inactive.
- Clarify observable capacity, readiness, shutdown, locking, and compatibility
  meanings without dictating code location or mechanism.
- Define vague success language such as deterministic validation, graceful
  handling, or drift detection with an observable baseline, exit/status
  contract, and unsupported-case semantics.
- Target existence, registration, compilation, repeated exit-zero runs, or
  transitive execution do not by themselves prove the promised behavior.
- Include a controlled negative case showing that a stub/no-op implementation
  fails, and deliberately induce conditions such as drift when the instruction
  promises that they will be detected.

## 7. Test quality

- Keep `grading.fail_to_pass` between 10 and 20 inclusive; for form language
  saying “more than 10,” normally target 11–20.
- Include a direct regression that fails on the untouched base and passes on
  the oracle.
- Preserve pass-to-pass protection and never modify pre-existing regression
  test files; add verifier-owned tests instead.
- Tests must run real code and verify observable behavior, including the real
  CLI/service/entry point when requested.
- Reject silent skips, fail-open branches, broad swallowed exceptions,
  existence-only artifacts, circular expectations, agent-controlled coverage,
  source-token checks, patch/diff checks, and hidden arbitrary constants.
- Do not require unstated internal APIs, names, signatures, fields, namespaces,
  helper overloads, source locations, or implementation primitives.
- Use behavioral stress/interleaving or platform semantics rather than source
  vocabulary to prove locking, concurrency, interrupt safety, or performance.
- A compatibility symbol need not disappear if the actual contract is that its
  limit becomes behaviorally inactive; test usable behavior.

## 8. Verifier integrity

- Declared F2P/P2P IDs must exactly equal the executed and reward-gating IDs.
- Do not grade markers parsed from combined stdout/stderr; agent-controlled
  code can forge them.
- Prefer verifier-owned structured results derived from framework result
  objects.
- Require successful raw test-process exit and exact expected/observed ID
  equality.
- Fail closed on missing, malformed, duplicate, unexpected, skipped, or
  non-passing records.
- Delete any pre-existing structured-results artifact after agent-controlled
  build and before tests.
- Run an explicit forged-output attack test after verifier changes.
- Treat any coverage/faithfulness judge score of 3 or below as requiring
  revision; fix the cited counterexample instead of averaging scores.

## 9. Patch safety

- Verify `golden.patch` and `tests.patch` against the pristine declared base.
- Run `git apply --check` before execution.
- Enumerate files newly created by `tests.patch` and detect base/setup/agent
  path collisions.
- Build before materializing verifier-owned tests when possible.
- Remove the known verifier-owned new-file destination immediately before
  applying `tests.patch` so an agent-created collision cannot create conflicts.
- If a test path is predictably agent-created, rename it to a maintainable
  verifier-only path and update config, runner, grader, and IDs together.
- Confirm renamed tests truly execute and gate reward.
- `solve.sh` must not reverse-apply `golden.patch` as a fallback or duplicate the
  fix on a second invocation.

## 10. Mandatory oracle and NOP validation

For every task creation and every modification:

1. Start from the untouched shipped base.
2. Confirm patches apply cleanly.
3. Run NOP: F2P must fail, P2P must pass, reward must be `0.0`.
4. Restore a clean base.
5. Apply `solution/solve.sh`/`golden.patch`.
6. Run the actual verifier: every declared F2P/P2P test must execute and pass,
   reward must be `1.0`, and process exit must agree with reward.
7. Check the oracle for hardcoded inputs, hidden test-side truth, fabricated
   output, golden-only APIs, and fixture-specific shortcuts.
8. Fix permitted failures and repeat. Never claim success for unexecuted checks.

## 11. Environment, metadata, and network

- Build `environment/Dockerfile` from a fresh checkout, preferably without
  cached layers, and report executed versus static validation accurately.
- Pin the base image and dependencies; verify package availability, shells,
  copied paths, executable bits, and line endings.
- Allowed environment fixes include small listed setup corrections such as
  bash/tmux/asciinema, missing frozen requirements, pinning, resource limits,
  shebangs, and artifact paths. Tangled toolchains or unavoidable live/large
  external dependencies may be unfixable.
- Graded behavior must remain network-independent through fixtures and offline
  tool settings.
- Do not add `network_mode`/`allowed_hosts` unless the Harbor installation's
  egress sidecar/buildx support is confirmed. If unsupported, remove those
  fields and keep the verifier airgapped by design.
- Treat `unknown flag: --file` during sidecar build and a later unset
  `EGRESS_CONTROL_SIDECAR_IMAGE_NAME` cleanup error as one cascading failure.
- Validate task resource/time limits and ensure verifier timeout is not shorter
  than the test/config timeout.
- Keep `gpus = 0`; metadata source, category, difficulty explanation, and actual
  diff/writeup must agree.

## 12. Git gate

Inside `environment/repo`, verify:

- `.git` exists and HEAD resolves.
- HEAD equals `base_commit_sha`.
- Working tree is clean; preserve required tracked upstream files, including
  tracked editor configuration.
- No remotes, extra refs/tags/branches beyond HEAD, stash, temporary worktrees,
  filter drivers, reflog, or leaked fix history.
- `git fsck` reports no dangling/unreachable objects that expose the solution.
- `.git` is below 100 MB.
- Both patches apply to the clean base.

Git metadata cleanup is permitted; tracked repository source edits are not.

## 13. Difficulty escalation

- Keep `solvable = true`; an `easy` result is the defect for a Hard task.
- Add cohesive behavioral depth within source scope: state transitions,
  repeated/composed operations, security invariants, serialization/reuse,
  compatibility, and all relevant public paths.
- Do not create difficulty using ambiguity, flakiness, hidden arbitrary choices,
  network dependence, or implementation leakage.
- Maintain legacy/current difficulty aliases consistently and use actual rollout
  evidence, not fabricated fractions or unsupported estimates.
- Re-run oracle, NOP, quality, and difficulty checks after expansion.
- A useful indicative Hard profile is oracle 3/3, NOP 0/1, and frontier agents
  succeeding around 1/4–2/4 each, subject to current platform thresholds.

For mutable storage tasks such as `StrBuilder`, combine truncation, regrowth,
serialization, repeated/matcher replacement, empty deletion, in-place mutation,
and discarded-data non-reappearance. State the invariant without prescribing a
specific helper such as `Arrays.fill`.

## 14. Packaging

- Parse every JSON and TOML file.
- Preserve executable bits on `solve.sh` and `test.sh`.
- Exclude `runs/`, wrapping task directories, nested source ZIPs, caches,
  virtual environments, IDE files, `node_modules`, swap/backup files, and
  solution leakage.
- The archive must unpack directly to `instruction.md`, `task.toml`,
  `environment/`, `solution/`, and `tests/`.
- Run archive integrity and content-list checks before delivery.
- Do not package until coverage, faithfulness, P2P protection, patch safety,
  verifier integrity, clean-base/oracle behavior, and archive hygiene have all
  been revalidated.

## 15. Required user-facing output

- At task start, provide the kickoff described in Section 1.
- Give both duplicate validity questions with matching answers.
- Follow only the final verdict's exact step branch and reproduce each question
  immediately before its answer.
- For Fixable: affected components, issue checkboxes, detailed evidence/fix per
  category, changed files, PR-scope statement, compliance confirmations,
  difficulty, engineer estimate, reviewer comments, and all time fields.
- For Valid as-is: compliance confirmations, difficulty, engineer estimate,
  reviewer comments, and time fields; make no changes.
- For Invalid: precise category and evidence, environment subtype if relevant,
  unfixability explanation, difficulty, engineer estimate, reviewer comments,
  and time fields.
- Use `NA` only when genuinely inapplicable. Distinguish executed checks from
  static inspection and update cumulative revision time after every revision.
- Provide a separate labeled, self-contained copyable answer for every required
  field. Never combine multiple form fields into one answer block.
- Write naturally and specifically, citing current-task evidence instead of
  generic rubric language or repetitive AI-like phrasing.
- Wrap long answers into short readable paragraphs or lines so the full text is
  easy to review and copy.

## 16. Reviewer integrity

The Reviewer Rubric prohibits pasting AI-generated review prose as original
human judgment. This assistance can provide an evidence-backed audit and draft,
but the human EC must independently inspect the cited bundle/logs, verify the
findings, rewrite or approve the assessment in their own judgment, and take
responsibility for submission. Never fabricate evidence or imply an unexecuted
check passed.

## 17. Reusable lessons

After fixing any task error, including manual-review findings, local execution
failures, platform evaluations, automated-review failures, agent rollout
failures, packaging defects, and reviewer feedback:

1. Diagnose the task-specific cause.
2. Add a concise, generally applicable prevention check to
   `.codex-task-review-memory.md` without weakening or deleting prior lessons.
3. Record the validation command/evidence and the clean-base, oracle, NOP, or
   regression check needed to prevent recurrence.
4. Do not store task-specific secrets, solution code, or hidden-test answers.
5. Incorporate the lesson into this master memory when it materially changes the
   standard workflow.
6. Reapply the lesson to the task just fixed, revalidate it, and report concrete
   evidence.
