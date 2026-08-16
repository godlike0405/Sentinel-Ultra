![Snorkel AI](<../Sentinel Ultra/The Harbor Framework_files/snorkel_logo_header-1-04af18ea.svg>)

# The Harbor Framework

Background reference for Sentinel contributors

Tasks follow the [Harbor format](https://harborframework.com/docs) and are evaluated internally using terminal-based execution: Docker environments, solution/solve.sh as the oracle, tests/test.sh for verification, and a reward written by the verifier (e.g. to /logs/verifier/reward.txt). Harbor is a framework for evaluating agents and models in containers.

## Optional context on how tasks are evaluated

- Terminal-based execution — Tasks run in isolated container environments during internal evaluation
- Oracle solution — The reference solution is provided as solution/solve.sh, which applies solution/golden.patch (a self-contained patch of all the solution's changes)

**Note — Oracle solutions:** *Task solutions may be larger than strictly necessary or include extra functionality not asked for in the instruction. This is okay as long as the solution does what the instruction requires and tests enforce that. The point of the Oracle is to show that the task is solvable.*

- Test execution — `tests/test.sh` runs the suite and records the reward outcome
- Verification — Pass/fail is determined from the test run and reward file
- Platform-level evals — The platform runs automated checks before tasks reach a reviewer (structure check, Dockerfile check, oracle eval, difficulty eval, general quality).

## Task Structure & Components

Each task follows the Harbor format and contains a task directory with the following structure:

```
<task-id>/
├── task/
│   ├── task.toml              # Metadata + pinned image URI, timeouts, resources
│   ├── instruction.md         # Problem statement + measurable success criteria
│   ├── environment/
│   │   ├── Dockerfile         # Container build (base image + setup)
│   │   ├── repo/              # Cloned base repository (agent + verifier run against this)
│   │   └── problem_statement.md  # Restatement of the instruction, set in the environment
│   ├── solution/
│   │   ├── solve.sh           # Applies golden.patch to restore the solved state
│   │   └── golden.patch       # The golden patch — self-contained (all solution changes)
│   └── tests/
│       ├── test.sh            # Runs tests, writes reward to /logs/verifier/reward.txt
│       ├── tests.patch        # Contains the fail-to-pass tests
│       ├── config.json        # How to run the suite + which test ids are fail-to-pass / pass-to-pass
│       └── grade.py           # Grading script
└── runs/                      # Execution runs from LLMs/agents (logs, episodes, outcomes)
```

**If the `solution/` folder in your downloaded task contains `solution.patch` instead of `golden.patch`, rename it to `golden.patch`.** `golden.patch` is the current, correct file name — `solution.patch` was a short-lived draft name and shouldn't ship.

The `runs/` folder lives alongside `task/` at the top level of the task directory. It holds the execution runs produced by the LLMs and agents (i.e. the frontier models and agents mentioned in the guidelines). Each subfolder is typically named by model or agent, and contains the logs, episodes, and outcomes for that run. Use this folder as a reference to understand how models run on the task and to identify any task issues.

## Task Metadata

Each task includes metadata in `task.toml`. The file opens with a `schema_version` (the Harbor format version, **not** the task version) and is organized into `[environment]`, `[agent]`, `[verifier]`, and `[metadata]` sections. **Check these fields on every task** — the resource and timeout values must stay within the limits below.

### **[environment] — resources**

- `os` — the container OS (e.g. `linux`).
- `cpus` — `2` or `4`.
- `memory_mb` — minimum `2048`, maximum `16384`.
- `storage_mb` — minimum `5120`, maximum `10240`.
- `gpus` — always `0`.
- `build_timeout_sec` — maximum `1800`.
- Remove `network_mode` and `allowed_hosts` if present — leave them out of `task.toml` for now.

### **[agent]**

- `timeout_sec` — per-episode limit for the agent; maximum `7200`. Raise it if you see failures caused by agent timeout.

### **[verifier]**

- `timeout_sec` — verifier run limit; maximum `1800`.

### **[metadata] — free-form**

- `category` (and subcategory) — the task's primary classification; edit if needed.
- `difficulty_explanation` — why the task warrants its difficulty tier; edit if needed.
- `source` — URL of the source PR / commit / issue the task derives from.

### **Example `task.toml`**

```
schema_version = "1.3"            # Harbor format version (NOT the task version)

# ── [environment] ── resources ───────────────────────────────────────
[environment]
os                = "linux"
cpus              = 2       # 2 or 4
memory_mb         = 2048    # min shown; max 16384
storage_mb        = 5120    # min shown; max 10240
gpus              = 0       # always 0
build_timeout_sec = 600     # max 1800
# (remove network_mode and allowed_hosts if present)

# ── [agent] ── per-episode ceiling ───────────────────────────────────
[agent]
timeout_sec = 300           # max 7200 — raise if you see agent-timeout failures

# ── [verifier] ───────────────────────────────────────────────────────
[verifier]
timeout_sec = 120           # max 1800

# ── [metadata] ── free-form ──────────────────────────────────────────
[metadata]
category               = "security"                            # edit if needed
difficulty_explanation = "expert-level cybersecurity problem"  # edit if needed
source                 = "https://github.com/org/repo/pull/1234"
```

![](<../Sentinel Ultra/The Harbor Framework_files/dr-bubbles-crown-687d8694.png>)
