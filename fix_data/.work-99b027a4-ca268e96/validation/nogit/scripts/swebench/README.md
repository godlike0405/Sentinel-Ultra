# SWE-bench Runner

This directory wraps the normal `whale exec` headless path into a repeatable single-instance SWE-bench flow:

1. Load one dataset instance from a local `SWE-bench` checkout.
2. Render a repo-local prompt for `whale`.
3. Clone the target repository at the instance `base_commit`.
4. Run `whale exec` inside that checkout to produce a patch.
5. Write `predictions.json`.
6. Run `python -m swebench.harness.run_evaluation`.

## Prerequisites

- `../SWE-bench` exists beside `whale`, with `.venv` already created and `pip install -e .` done.
- `docker`, `git`, and `rg` are installed on the machine running the script.
- Either `go` is installed, or you pass an existing `whale` binary via `--whale-bin` / `WHALE_BIN`.
- `DEEPSEEK_API_KEY` is exported.
- For ARM local Docker builds, pass `--namespace ''` or set `SWE_BENCH_NAMESPACE=''`.

## Example

```bash
cd /path/to/whale
export DEEPSEEK_API_KEY=...
./scripts/swebench/run_instance.sh \
  --instance-id sympy__sympy-20590 \
  --model deepseek-v4-pro
```

Useful switches:

- `--prepare-only`: stop after prompt + repo checkout.
- `--skip-eval`: stop after writing `predictions.json`.
- `--run-id <id>`: make artifact paths deterministic.
- `--swebench-dir <path>`: point at a non-sibling `SWE-bench` checkout.
- `--whale-bin <path>`: reuse a prebuilt `whale` binary on machines without Go.

Artifacts are written under `tmp/swebench/<run_id>/artifacts/`.
