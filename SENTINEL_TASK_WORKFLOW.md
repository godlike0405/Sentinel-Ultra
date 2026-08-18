# Sentinel Ultra Standing Task Workflow

This file records the user's standing workflow for `CDG_Sentinel_Ultra_00000`
and future Sentinel Ultra task modifications in this workspace.

## Governing references

- Read and apply every Markdown document in `Complete_Data/`.
- Treat `Complete_Data/Sentinel_Ultra_Reviewer_Rubric.md` (last updated
  August 7, 2026) as a mandatory acceptance rubric for every task created,
  reviewed, modified, or finally audited.
- Apply additional user-provided rules alongside those documents.
- If rules conflict, follow the user's latest explicit instruction unless it
  would require misrepresenting validation results or violating a higher-level
  constraint; flag any such conflict.

## Working directory

- Use `./fix_data` as the work directory for all task creation, inspection,
  modification, validation, audit, and output artifacts.
- Treat `Complete_Data/` and this workflow file as governing references rather
  than task work products.

## Workflow for every task

0. At task start, give the user a concise kickoff stating: the task/package
   being reviewed; that `Complete_Data/`, the Reviewer Rubric, and this workflow
   are being applied; that the complete instruction/environment/oracle/tests/
   metadata/runs audit will be performed; that Docker, patch, NOP, and oracle
   validation will be attempted; and that handling time begins at this point.
   Do not preselect a verdict before evidence is collected.
1. Read the complete task and any supplied run artifacts.
2. Analyze the instruction, source scope, metadata, environment, repository,
   oracle, tests, grading, packaging, and agent runs.
3. Answer the user's form questions step by step in their supplied order.
4. If the task is Fixable, fix all permitted material errors, including errors
   discovered while preparing answers or validating changes.
5. Audit the task after modification and report evidence-backed results.
6. Never claim a check passed unless it was actually verified.

## Verdict branches

### Fixable

- Use `Fixable` for both duplicate validity questions.
- Identify affected areas: Instructions, Tests, Oracle Solution, and/or
  Environment/Dockerfile.
- Select all applicable issue categories and explain each with concrete
  evidence, fixability, and the correction made.
- Implement all allowed fixes without editing tracked source files in
  `environment/repo` or reducing/replacing the source PR scope.
- Keep instruction, `environment/problem_statement.md`, tests, and oracle in
  lockstep.
- Perform the full post-fix audit.
- Provide a complete changed-files list, PR-scope statement (or `NA`), final
  confirmations, difficulty explanation, engineer estimate, reviewer comments,
  and handling times.
- If validation reveals a genuine unfixable condition, change the verdict to
  Invalid/Not Fixable and explain it with evidence.

### Valid as-is

- Use `Valid as-is` for both duplicate validity questions.
- Make no task changes.
- Verify all instruction/test/oracle alignment, natural instruction quality,
  absence of leakage, required test coverage, PR scope, metadata, environment,
  Git hygiene, and packaging.
- Run the required local checks, including patch applicability, NOP behavior,
  oracle behavior, pass-to-pass tests, Docker build, and verifier execution as
  applicable.
- Provide compliance confirmations, difficulty explanation, engineer estimate,
  reviewer comments, and handling times.
- Do not use this verdict if any correction is needed.

### Invalid/Not Fixable

- Use `Invalid/Not Fixable` for both duplicate validity questions.
- Use only a documented unfixable reason: the source PR scope must be reduced
  or replaced, or the environment has a genuinely unfixable condition.
- Exhaust safe, allowed checks before deciding that a task is unfixable.
- Do not treat ordinary instruction, test, oracle, metadata, packaging, or Git
  hygiene defects as unfixable.
- Do not alter the task to conceal invalidity, modify tracked repository source,
  reduce PR scope, or substitute a different task.
- Provide the category, exact evidence, checks performed, why allowed changes
  cannot resolve it, difficulty explanation, engineer estimate, reviewer
  comments, and handling times.

## Mandatory audit principles

- Preserve the source PR scope; only a natural expansion is allowed.
- Never edit tracked files inside `environment/repo`.
- Ensure `instruction.md` and `environment/problem_statement.md` are identical.
- Maintain complete instruction-to-test and test-to-instruction alignment.
- Require at least 10 meaningful fail-to-pass tests; when form wording says
  "more than 10," target 11-20 where feasible to avoid ambiguity.
- Include direct regression coverage and appropriate pass-to-pass protection.
- Tests must be deterministic, outcome-based, faithful, and resistant to
  reward hacking, silent skips, fail-open behavior, circular expectations, and
  agent-controlled coverage.
- Validate `tests.patch`, oracle and NOP outcomes, metadata/resource limits,
  Docker/offline reproducibility, Git hygiene, leakage, and bundle packaging.
- Fix additional permitted errors found during analysis or validation.

## Mandatory reviewer-rubric acceptance gate

Apply both independent acceptance paths from the Reviewer Rubric:

- One confirmed Major Pillar violation requires Needs Revision (or Not Fixable
  when the only correction is outside EC scope).
- Five or more Minor/Secondary violations in any combination require Needs
  Revision for systemic low quality.
- One to four Minor violations may be accepted only with specific mandatory
  coaching comments; when creating or modifying a task, fix these minor issues
  where permitted instead of knowingly shipping them.

### Major Pillars

1. **Oracle / golden-solution correctness**
   - The golden patch applies cleanly and implements the entire instruction.
   - It passes the real graded suite deterministically.
   - It introduces no unstated and non-derivable behavior, file, module,
     configuration, re-export, path, or value.
   - Oracle failure, NOP success, or a golden-only hidden dependency is Major.
2. **Fail-to-pass / pass-to-pass integrity**
   - The declared test lists must equal the tests the verifier actually grades.
   - Count the real executed and reward-gating fail-to-pass tests, not a static
     list or labels alone; require at least 10 outcome-based tests plus a direct
     regression test.
   - Detect missing, stale, duplicated, misnamed, deselected, skipped, or
     unexecuted test IDs and any tests that run but do not gate reward.
   - Material declaration/graded-set mismatch or trivial/gameable tests is
     Major.
3. **No leakage / no reward hacking**
   - No PR link, solution spoiler, answer text, hidden-test/verifier detail, or
     route to pass by editing tests instead of implementing behavior.
4. **Airgapped verifier / network integrity**
   - All graded behavior must run with networking disabled and without external
     hosts or live services.
   - Verify that the shipped environment's network restrictions are correct for
     the current platform schema and rubric.
   - The older guidance says to remove `network_mode` and `allowed_hosts`, while
     the newer Reviewer Rubric says network settings must be correctly
     restricted. Resolve this using the current task schema/platform behavior;
     never leave graded execution openly network-dependent, and explicitly flag
     the documentation conflict in the audit if it affects the task.
5. **Git state / repository cleanliness (early gate)**
   - Check this before content assessment.
   - Require HEAD to match the declared base, a clean single-history state, no
     extra refs, stash, remotes, worktrees, reflog, leaked fix, or filter driver.
   - Run `git fsck` and require no dangling/unreachable objects that could expose
     the solution; do not assume deleting visible refs alone removed leaked
     history.

### Secondary Requirements (Minor, cumulative)

Count and record each independently:

1. Verifier timeout shorter than the task/config execution timeout; cite both
   values and correct the mismatch within allowed limits.
2. Unpinned base image or dependencies that make builds non-reproducible.
3. PR scope reduced or replaced; escalate to Unfixable-Structure when the only
   correction would change/reduce the anchored source scope.
4. Any instructed behavior missing real graded coverage.
5. Metadata or files-changed/writeup content that does not match the actual
   task/diff.
6. Over-prescriptive instruction.
7. Templated or AI-generated-sounding instruction.
8. Instruction ambiguity that forces an arbitrary choice required by tests.
9. Non-deterministic graded test without fixed seed/order/input.
10. Missing direct regression test.
11. Recoverable difficulty drift that can be corrected by a natural in-scope
    expansion.

### Unfixable classification

- Keep **Unfixable-Structure** separate: the only correction requires reducing
  or replacing source PR scope, or changing an environment area ECs may not
  touch.
- Keep **Unfixable-Difficulty** separate: difficulty genuinely cannot be
  recalibrated without leaving source PR scope.
- Do not lump these into a vague `invalid` explanation; name the precise bucket
  and evidence in the Invalid/Not Fixable form branch.

## Mandatory difficulty-escalation guidance

Use this section whenever increasing a task's difficulty.

### Objective and interpretation

- `"solvable": true` is correct and must remain true; it proves a valid
  solution exists.
- `"difficulty": "easy"` is the problem when a task is intended to be Hard,
  especially when capable frontier agents pass every rollout.
- Never attempt to make a task hard by making it unsolvable, ambiguous, flaky,
  dependent on hidden arbitrary choices, or reliant on unavailable resources.
- The target is a genuinely solvable Hard task: oracle passes consistently,
  NOP fails, and capable agents succeed on only a minority of rollouts. A useful
  indicative profile is oracle 3/3, NOP 0/1, and each frontier agent around
  1/4-2/4, while recognizing that actual platform thresholds govern.

### How to increase difficulty correctly

- Preserve the complete source PR scope and add only natural, cohesive
  extensions of the same behavior.
- Add behavioral requirements that require deeper repository exploration,
  multi-step reasoning, state-transition correctness, security invariants,
  compatibility preservation, and interactions among existing code paths.
- Prefer difficult operation sequences and compositions over isolated happy
  paths. Verify that discarded or invalid state cannot reappear after later
  growth, serialization, reuse, mutation, or repeated transforms.
- Cover all distinct public operation paths that promise the behavior; do not
  let a partial fix in one common path pass unless it genuinely satisfies every
  required path.
- Add regression constraints for invalid inputs, no-op inputs, growth,
  truncation, return-value/identity contracts, prefix/suffix preservation,
  serialization, and unchanged existing behavior where relevant.
- Strengthen tests in lockstep with the instruction and oracle. Tests must be
  deterministic, outcome-based, reward-hack resistant, and faithful to stated
  or reasonably derivable requirements.
- Do not expose exact methods, helper functions, internal control flow, or code
  recipes used to implement the harder behavior. State the behavioral/security
  invariant and let the agent determine where and how to enforce it.
- Internal-state or serialized-byte inspection is acceptable only when needed
  to verify an explicitly required security/data-retention invariant and when
  it does not arbitrarily mandate one implementation. Prefer observable
  serialization/reuse behavior where it proves the invariant adequately.
- Re-run oracle, NOP, quality, and difficulty evaluations after expansion; keep
  instruction, tests, oracle, metadata, and difficulty explanation aligned.

### `StrBuilder` reference pattern

When the task concerns mutable backing storage, truncation, replacement, and
serialization, consider cohesive requirements such as:

- Clear every unused backing-storage position after shortening.
- Handle repeated replacements that shift content multiple times.
- Preserve serialization security without changing the public API.
- Preserve behavior during expansion after truncation.
- Support matcher-based replacements with overlapping or complex matches.
- Prevent discarded data from reappearing after later growth.

Use multi-step tests such as:

1. Append sensitive content, truncate it, grow again, serialize, and verify the
   discarded content is absent.
2. Perform multiple replacements, shorten repeatedly, mutate characters in
   place, expand capacity, and truncate again.
3. Exercise `replace(start, end, value)`, `replaceFirst`, `replaceAll`,
   matcher-based replacement, deletion by empty replacement, and multiple
   matches in one operation when those APIs exist and are within source scope.
4. Confirm negative length changes leave state unchanged, same-length changes
   are true no-ops, growth yields the documented empty/NUL state, replacement
   methods preserve their return contract, prefixes/suffixes remain correct,
   serialization works, and existing project tests remain unchanged.

An instruction may require that removed characters no longer remain observable
or retained (including a NUL-clearing contract when that is genuinely part of
the required behavior), but must not prescribe implementation code such as a
specific `Arrays.fill(...)` call or exact helper location.

### Reviewer-integrity constraint

- The rubric prohibits pasting LLM-generated review prose as if it were original
  human reviewer judgment.
- Assistance may provide an evidence-backed audit and draft, but the human EC
  must independently verify the task, inspect cited files/logs, revise the
  wording into their own genuine assessment, and take responsibility for the
  submitted review.
- Never include meta-commentary, unrelated content, fabricated citations, or
  claims that visible logs were inaccessible.
- Keep every finding specific to the actual bundle: cite exact files, test IDs,
  configuration keys, commands, and eval results.

## Known recurring build and patch failures

Check for both of these failure modes whenever creating, modifying, or auditing
a task. They are infrastructure failures: affected trials never start or are
discarded rather than counted as legitimate agent failures.

### Environment image fails to build

Symptoms:

- The sandbox reports that the declared environment image could not be built.
- No agent trial starts, so there is no meaningful difficulty evidence.

Required checks and response:

- Build `environment/Dockerfile` locally from a clean/fresh task checkout, not
  from a previously mutated container or working tree.
- Inspect the first failing Docker build step and verify the base image exists
  and is pinned to a concrete tag.
- Check package names, package availability for the base distribution, required
  system tools, shell compatibility, copied-file paths, executable bits, and
  line endings.
- Check whether any build step needs live network access. The final build must
  be reproducible in the restricted/offline grading environment.
- Rebuild from a clean cache where practical so cached layers do not conceal a
  missing dependency or network requirement.
- Apply only environment fixes allowed by the Sentinel Ultra rules. A small,
  listed Dockerfile/setup correction is Fixable; a tangled dependency/toolchain
  failure or unavoidable large/live external-network dependency may make the
  task Invalid/Not Fixable.
- Re-run the complete Docker build and task validation after correcting it.
- Never report the task as validated merely because the Dockerfile looks
  plausible; distinguish an executed build from static inspection.

### `tests.patch` cannot create a new test because an untracked file exists

Known example:

- `tests.patch` creates `tests/rag_vdb_milvus_lite_test.py` from scratch.
- During an agent rollout, the agent independently creates an untracked file at
  that exact path.
- `git apply` refuses to overwrite the existing untracked file, the entire
  patch aborts, no tests run, and the trial is discarded instead of counted as
  a fail.

Required checks and response:

- Enumerate every path that `tests/tests.patch` creates as a new file.
- Confirm none of those paths already exists in the base checkout, is generated
  by environment setup, or is strongly suggested as an implementation/output
  path by the instruction or repository naming conventions.
- Test patch application against the pristine base with
  `git apply --check ../../tests/tests.patch` from `environment/repo`.
- Also consider the post-agent state: inspect available rollout logs and agent
  changes for untracked-path collisions before the verifier applies the patch.
- If a verifier-owned newly created test file is collision-prone, rename it in
  `tests.patch` to a clear test-only path that agents are unlikely to create as
  part of solving the ticket, then update `config.json`, `test.sh`, grading
  references, test IDs, and any other dependent paths in lockstep.
- Do not mention the verifier-only filename in `instruction.md` and do not use
  obscure naming as a substitute for robust behavioral tests. The new path must
  remain maintainable, and the tests must still be outcome-based and resistant
  to tampering or reward hacking.
- Prefer adding tests to an appropriate verifier-controlled test location; do
  not modify pre-existing pass-to-pass test files.
- Re-run patch applicability, NOP, oracle, and packaging checks after the
  rename. Confirm the expected test IDs actually execute rather than silently
  disappearing due to stale path references.

## Mandatory prescriptiveness audit

Check every new, reviewed, or modified task for instruction prescriptiveness.
This check applies even when the initially reported defect is unrelated.
Prescriptiveness means telling the agent *how to solve the task* instead of
describing *what behavior and requirements the completed work must satisfy*.
A strong instruction should read like a real engineering ticket and leave
ordinary repository exploration, diagnosis, and implementation design to the
agent.

### Prescriptiveness issues to detect

- A `Where to look` section or explicit list of implementation files when an
  engineer could discover them by exploring the repository.
- Directions naming the exact internal functions, classes, branches,
  comprehensions, callbacks, or lines to edit when only behavior needs to be
  specified.
- A prescribed implementation algorithm, data structure, dependency, or
  ordered sequence of code changes when multiple valid implementations should
  be accepted.
- Included solution code, pseudocode that substantially reveals the patch, or
  implementation hints that remove meaningful design/debugging work.
- Root-cause analysis that gives away what the agent should discover through
  debugging.
- Pre-answered edge cases that disclose the diagnosis or implementation choice
  the agent should discover, rather than specifying an externally meaningful
  behavior the product must support.
- References to hidden tests, fixtures, mocks, cassettes, harness files,
  assertions, test names, verifier mechanics, or how the grader proves success.
- Statements such as "the tests expect this name" or "this file validates the
  fix."
- Exact internal state paths, fixture values, or assertion strings copied from
  tests unless they are genuine public contracts.
- Unnecessary file paths, symbol names, patch locations, or solution-oriented
  hints that reduce repository exploration and engineering reasoning.
- Ticket text written as a step-by-step implementation tutorial instead of a
  problem statement with observable acceptance criteria.

### What is not automatically over-prescriptive

- Public API names, CLI flags, configuration keys, protocols, schemas, output
  fields, error contracts, and formats that users must know to implement the
  requested behavior.
- Existing names fixed by the repository or standard framework/language
  conventions.
- Necessary constraints, compatibility requirements, edge cases, and
  measurable observable outcomes. An edge case belongs in the instruction when
  it is part of the required product behavior; it is prescriptive when it
  merely tells the agent how the internals fail or how to implement the fix.
- File or component references that are part of the public contract or needed
  to make the task self-contained, provided they do not reveal the solution.

### Required correction

- Apply this decision test to every potentially prescriptive detail: **Could a
  competent agent reasonably discover it by exploring the codebase?** If yes,
  it normally should not be stated in the instruction unless it is part of a
  genuine public contract or necessary observable requirement.
- Rewrite implementation instructions as observable behavior and acceptance
  criteria.
- Remove discoverable file-localization hints, root-cause spoilers, hidden-test
  references, verifier details, and prescribed code-edit sequences.
- Preserve enough domain context, public contracts, constraints, output shapes,
  and edge cases for a competent engineer to solve the task without guessing.
- Do not remove required names or formats if tests legitimately enforce them;
  state those contracts clearly in the instruction instead.
- After rewriting, re-check instruction-to-test and test-to-instruction
  alignment and update tests/oracle in lockstep where necessary.
- Confirm that the rewrite preserves the source PR scope and does not create
  ambiguity as artificial difficulty.
- Update `environment/problem_statement.md` to exactly match the revised
  `instruction.md`.
- When prescriptiveness required a change, select `Instructions` and `The
  instructions are overly-prescriptive` in the Fixable branch and provide
  concrete before-and-after evidence.

### Evaluation context

- The dedicated in-app instruction prescriptiveness evaluation uses an LLM
  judge over `instruction.md`; it is advisory, does not itself block
  submission, and its findings are shown to the author.
- The broader quality-check rubric also scores instruction prescriptiveness,
  and reviewers can see that score even though the blocking verdict is driven
  by the test-quality axes.
- Detailed schemas, conventions, public contracts, and behavioral requirements
  generally score well.
- Ordered how-to steps, file-localization hints, pre-answered diagnostic or
  implementation edge cases, and solution-revealing names or paths score
  poorly.

## Mandatory oracle validation

- For every task creation and every task modification, execute the oracle by applying
  `solution/solve.sh` / `solution/golden.patch` to the untouched shipped base
  and running the actual verifier.
- Confirm that the oracle produces reward `1.0`, that all fail-to-pass and
  pass-to-pass tests succeed, and that the verifier exit status agrees with the
  reward file.
- Diagnose and fix every permitted issue discovered by the oracle run, then
  repeat the run until it passes.
- Restore or use a clean base between validation states so oracle testing does
  not contaminate the shipped repository.
- If oracle execution is impossible or exposes a genuinely unfixable
  condition, do not claim success; record the commands, failure evidence,
  attempted permitted fixes, and blocker in the applicable form steps.

## Harbor egress-control compatibility

- Do not add `network_mode` or `allowed_hosts` speculatively. Preserve them
  when the seed/current platform contract explicitly requires verifier
  `no-network`, agent `allowlist`, and environment `public` behavior.
- A Docker CLI rejection of the sidecar build with `unknown flag: --file` is a
  host-tooling incompatibility when those settings are required; report it and
  validate on a compatible runner instead of erasing the network contract. If
  the settings are optional for that platform, removing them avoids the
  sidecar. The later unset `EGRESS_CONTROL_SIDECAR_IMAGE_NAME` compose error is
  a cleanup consequence of the failed sidecar build, not an independent defect.
- Keep graded behavior network-independent through test fixtures and
  tool-specific offline settings such as `GOPROXY=off` and
  `GOTOOLCHAIN=local`, while allowing the environment image build to preload
  required dependencies.

## Form-answer requirements

- Use the complete form structure proactively as an audit checklist while
  creating and modifying a task, not only after the work is finished. Re-check
  affected components, issue categories, evidence, fixes, compliance
  confirmations, changed files, PR-scope impact, difficulty rationale,
  reviewer notes, and validation/handling-time fields as the work proceeds.
- Follow the exact branch, step numbering, headings, option order, and sequence
  in the user's supplied question template; do not replace it with a generic
  summary structure.
- Provide every step and every field in the applicable verdict branch. Do not
  omit a step; use `NA` where a field genuinely does not apply, and explicitly
  identify any validation check that could not be executed.
- Make both duplicate verdict responses identical.
- Write answers so they can be pasted directly into the Snorkel form.
- Give every required form field its own clearly labeled, self-contained,
  copyable answer. Do not merge answers for separate fields.
- Use natural, task-specific wording grounded in exact bundle evidence; avoid
  generic rubric prose, robotic repetition, academic filler, and language that
  simply mirrors the prompt.
- Wrap longer answers into short readable paragraphs/lines so the complete text
  is easy to read and copy.
- List every changed file with its path, what changed, and why.
- State whether PR scope was expanded; otherwise write `NA`.
- Include requested time estimates and update cumulative revision time after
  each revision.
- Apply these rules to every Sentinel Ultra task created, reviewed, or modified.

## Mandatory verdict-dependent answer template

Use this template after every task creation, modification, or fix. Include the
question followed immediately by its evidence-based answer. Normalize obvious
OCR artifacts in the supplied form: `IO` means `10`, `IOAO` means `how long`,
and malformed words such as `i ormation` mean `information`.

Always provide the two initial validity questions first and give the same final
validated verdict in both. Then provide only the matching branch below.

### If Valid as-is

- **Step 3. Confirm the task complies with all requirements.** Answer each item
  separately: every instruction requirement is tested; every test requirement
  is specified or reasonably implied; instruction is natural, not overly
  prescriptive, and leak-free; oracle implements the instruction; suite has
  more than 10 fail-to-pass tests. Confirm only after actual verification.
- **Step 4. What makes this task difficult?** Give task-specific technical
  reasons: edge cases, dependencies, easily missed requirements, repository
  exploration, or test complexity.
- **Step 5. How much time would a senior engineer familiar with the codebase
  take?** Select exactly one: `10–20 minutes`, `20–40 minutes`, or `40+
  minutes`.
- **Step 6. Final Comment and Handling Time.** Give Comments for Reviewer,
  assumptions, edge cases, reasons files were unchanged, any reviewer-judgment
  points, initial validity-review minutes, and cumulative revision minutes.
  Update cumulative time after every revision.

### If Fixable

- **Step 2. Select where the task had issues.** Check all applicable:
  Instructions, Tests, Oracle Solution, Environment/Dockerfile.
- **Step 3. What issues did you find?** Check all applicable: incomplete
  instruction coverage; test requirements absent from instruction; generated
  instruction style; over-prescriptiveness; leakage; oracle mismatch; fewer
  than 10 fail-to-pass tests.
- **Step 4. Describe each issue in detail.** For each selected category, state
  the category, exact evidence/examples, whether it is fixable, and precisely
  how it can be fixed.
- Fix every permitted error and complete the full post-change audit before
  continuing to the confirmation steps.
- **Step 6. Files Changed.** List every path changed, what changed, and why.
  State `NA` if PR scope was not expanded; otherwise explain the natural
  additive expansion and confirm scope was not reduced or replaced.
- **Step 7. Confirm the corrected task meets all requirements.** Answer each
  item separately: every requirement tested; every test requirement specified
  or implied; natural non-LLM style; not overly prescriptive; no leakage;
  oracle implements instruction; PR scope complies; more than 10 fail-to-pass
  tests. Confirm only after actual verification.
- **Step 8. What makes this task difficult?** Give task-specific technical
  reasoning. Then select exactly one engineer estimate: `<10 minutes`, `10–20
  minutes`, `20–40 minutes`, or `40+ minutes`.
- **Step 9. Comments for Reviewer.** Explain non-obvious decisions,
  assumptions, edge cases, validation limitations/results, unchanged files,
  and reviewer-judgment points. Provide minutes for initial validity review,
  initial rewrite only, additional form questions, and cumulative revisions;
  update the cumulative figure after every revision.

### If Invalid/Not Fixable

- **Step 3. What issue did you find with the task/components?** Select PR scope
  needs to be changed/reduced and/or Environment Issues as supported by
  evidence. Also identify Unfixable-Structure versus Unfixable-Difficulty in
  the explanation when applicable under the newer Reviewer Rubric.
- **Step 4. If Environment Issues was selected, what specific issue did you
  find?** Select all applicable: image/dependency build failure, oracle
  timeout, external-network dependency at build/solve time.
- **Step 5. Explain why the task is unfixable.** Give exact files, commands,
  evidence, attempted permitted corrections, and why resolution lies outside
  EC scope. Do not use a vague invalid explanation.
- **Step 6. What makes this task difficult?** Explain the intended technical
  difficulty separately from the packaging condition that makes it invalid.
  Then select exactly one engineer estimate: `<10 minutes`, `10–20 minutes`,
  `20–40 minutes`, or `40+ minutes`.
- **Step 7. Comments for Reviewer.** Explain the blocker, assumptions,
  evidence, permitted checks attempted, and anything requiring reviewer
  judgment. Provide initial validity-review minutes and cumulative revision
  minutes, updating the latter after every revision.
