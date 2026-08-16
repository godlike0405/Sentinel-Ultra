#!/usr/bin/env bash
# Compact verifier entrypoint — SELF-CONTAINED (generic; shipped per task).
#
# Resolves the workspace, applies the eval tests (tests/tests.patch) at verify
# time, runs the configured test command(s), then grades via an EMBEDDED copy of
# grade.py (inlined at materialize time at the grader marker below — no sibling
# grade.py ships). Reads tests/config.json = {execution, grading, artifacts}.
# A fallback trap guarantees reward.txt exists.
set -uo pipefail

CONFIG="/tests/config.json"
LOG_DIR="/logs/verifier"
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
REPORT="$LOG_DIR/report.json"
OUTPUT="$LOG_DIR/output.json"
REWARD="$LOG_DIR/reward.txt"
RESULTS_XML="$LOG_DIR/pytest-results.xml"

mkdir -p "$LOG_DIR"

# Safety net: if we crash before the grader writes the reward, write 0.
write_zero_reward_if_missing() {
  if [ ! -f "$REWARD" ]; then echo "0" > "$REWARD"; fi
}
trap write_zero_reward_if_missing EXIT

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: missing $CONFIG" | tee "$STDERR_LOG"
  echo '{"success": false, "infrastructure_error": "missing config.json", "reward": 0.0}' > "$REPORT"
  echo "0" > "$REWARD"
  exit 2
fi

# Resolve the workspace from hardcoded fallbacks (config carries no workspace).
WORKSPACE=""
for p in /app /testbed /workspace; do
  if [ -d "$p" ]; then WORKSPACE="$p"; break; fi
done
if [ -z "$WORKSPACE" ]; then
  echo "ERROR: could not resolve workspace" | tee "$STDERR_LOG"
  echo '{"success": false, "infrastructure_error": "missing workspace", "reward": 0.0}' > "$REPORT"
  echo "0" > "$REWARD"
  exit 2
fi
cd "$WORKSPACE" || exit 2

# Export configured env vars (execution.env).
python3 - <<'PY' > /tmp/verifier_env.sh
import json, shlex
cfg = json.load(open("/tests/config.json"))
env = (cfg.get("execution") or {}).get("env", {})
if isinstance(env, dict):
    for k, v in env.items():
        if isinstance(k, str):
            print(f"export {k}={shlex.quote(str(v))}")
PY
# shellcheck disable=SC1091
source /tmp/verifier_env.sh

# Apply the eval tests at VERIFY time. They ship as tests/tests.patch (NOT in
# repo/), so the solving agent never saw them. git apply (plain, then 3-way for
# agent edits to neighbouring files) when git exists; otherwise fall back to
# patch(1), which patch_dockerfile injects into every task image — a slim/alpine
# base without git must not zero the reward. A hard failure means we cannot
# grade -> infra error, reward 0.
if [ -f /tests/tests.patch ]; then
  APPLIED=0
  if command -v git >/dev/null 2>&1; then
    # A verifier retry may see the exact evaluation patch from an earlier run.
    # Accept that state, but only when the complete patch reverses cleanly.
    if git apply --reverse --check /tests/tests.patch 2>>"$STDERR_LOG"; then
      APPLIED=1
    fi
  fi
  if [ "$APPLIED" != "1" ] && command -v patch >/dev/null 2>&1; then
    # --forward prevents patch(1) from silently ignoring -R and validating the
    # forward direction when a new-file destination is still absent.
    if patch -p1 --reverse --forward --dry-run --batch < /tests/tests.patch >>"$STDERR_LOG" 2>&1; then
      APPLIED=1
    fi
  fi
  if [ "$APPLIED" != "1" ]; then
    # This path is owned by the verifier patch. Remove an agent-created
    # collision before applying it, while retaining the exact retry case above.
    rm -f -- tests/test_sentinel_a8ab68f5.py
    if command -v git >/dev/null 2>&1 \
      && { git apply /tests/tests.patch 2>>"$STDERR_LOG" \
        || git apply --3way /tests/tests.patch 2>>"$STDERR_LOG"; }; then
      APPLIED=1
    fi
  fi
  if [ "$APPLIED" != "1" ] && command -v patch >/dev/null 2>&1; then
    # Dry-run first: patch(1) is otherwise non-transactional and can leave a
    # partially applied test suite that makes every subsequent retry fail.
    if patch -p1 --forward --dry-run --batch < /tests/tests.patch >>"$STDERR_LOG" 2>&1 \
      && patch -p1 --forward --batch < /tests/tests.patch >>"$STDERR_LOG" 2>&1; then
      APPLIED=1
    fi
  fi
  if [ "$APPLIED" != "1" ]; then
    echo "ERROR: failed to apply tests/tests.patch" | tee -a "$STDERR_LOG"
    echo '{"success": false, "infrastructure_error": "tests.patch did not apply", "reward": 0.0}' > "$REPORT"
    echo "0" > "$REWARD"
    exit 2
  fi
fi

# Execute a verifier-owned copy outside the solver-controlled repository's
# pytest configuration and plugin tree. Recreate the fixed directory on every
# run so neither an agent nor a previous verifier attempt can seed it.
RUNTIME_TEST_DIR=/tmp/sentinel-a8ab-verifier-tests
if [ -e "$RUNTIME_TEST_DIR" ] || [ -L "$RUNTIME_TEST_DIR" ]; then
  find "$RUNTIME_TEST_DIR" -depth -delete
fi
mkdir -p "$RUNTIME_TEST_DIR"
cp tests/test_sentinel_a8ab68f5.py "$RUNTIME_TEST_DIR/test_sentinel_a8ab68f5.py"
chmod 0444 "$RUNTIME_TEST_DIR/test_sentinel_a8ab68f5.py"
export SENTINEL_WORKSPACE="$WORKSPACE"

# Build the test command(s) from config (expands ${TEST_FILES}; language default
# from grading.parser.framework when execution.commands is empty).
python3 - <<'PY' > /tmp/run_tests.sh
import ast, json, shlex
cfg = json.load(open("/tests/config.json"))
execution = cfg.get("execution", {}) or {}

def parse_list(value):
    if isinstance(value, list):
        return value
    if isinstance(value, str) and value.strip():
        for p in (json.loads, ast.literal_eval):
            try:
                v = p(value)
                if isinstance(v, list):
                    return v
            except Exception:
                pass
    return []

test_files = parse_list(execution.get("selected_test_files_to_run") or [])
commands = execution.get("commands", [])
if isinstance(commands, str):
    commands = [commands]
if not commands:
    fw = ((cfg.get("grading") or {}).get("parser") or {}).get("framework", "").lower()
    # Output MUST be parseable by grade.py: pytest -v (per-test lines),
    # jest/go JSON modes. `pytest -q` prints no per-test lines -> reward 0.
    if fw == "pytest":
        commands = ["python -m pytest -v ${TEST_FILES}"]
    elif fw == "jest":
        commands = ["npx jest --json ${TEST_FILES}"]
    elif fw == "go-test":
        commands = ["go test -json ./..."]
    else:
        raise SystemExit("No execution.commands configured and no framework default")

files_arg = " ".join(shlex.quote(str(x)) for x in test_files)
for cmd in commands:
    print(cmd.replace("${TEST_FILES}", files_arg))
PY
chmod +x /tmp/run_tests.sh

# Wrap with timeout(1) if available + configured.
TIMEOUT_SEC="$(python3 -c "import json;print((json.load(open('/tests/config.json')).get('execution') or {}).get('timeout_sec',''))" 2>/dev/null || true)"
RUNNER=(bash /tmp/run_tests.sh)
if [ -n "${TIMEOUT_SEC:-}" ] && command -v timeout >/dev/null 2>&1; then
  RUNNER=(timeout "${TIMEOUT_SEC}" bash /tmp/run_tests.sh)
fi

set +e
rm -f "$RESULTS_XML"
"${RUNNER[@]}" > "$STDOUT_LOG" 2> "$STDERR_LOG"
TEST_EXIT_CODE=$?
set -e

# Grade via the embedded grader (grade.py inlined at the marker below; written to
# /tmp at runtime and invoked with the same CLI it has always used).
cat > /tmp/grade.py <<'GRADE_PY_EOF'
#!/usr/bin/env python3
"""Compact SWE-bench/Harborized verifier — parser + evaluator (`grade.py`).

This is a **generic, task-agnostic** grader and the single source of grading
truth (see ``agents/difflection`` TEST_DESIGN.md). It is NOT shipped as its own
``tests/`` file: ``config_builder.assemble_test_sh`` embeds this file's source
into the self-contained ``test.sh`` at materialize time. It does NOT run the
tests — ``test.sh`` runs them + captures logs; this grader only parses those logs
against ``config.json``'s required-test lists and writes the reward.

Division of responsibility (compact = config.json + tests.patch + test.sh):
    config.json = declarative {execution, grading, artifacts} metadata (per-task)
    tests.patch = the eval tests, applied by test.sh at verify time (per-task)
    test.sh     = self-contained verifier (runs tests + this grader, embedded)

CLI (called by test.sh)::

    python3 /tests/grade.py \
      --config /tests/config.json \
      --stdout /logs/verifier/test-stdout.txt \
      --stderr /logs/verifier/test-stderr.txt \
      --raw-exit-code <int> \
      --output /logs/verifier/output.json \
      --report /logs/verifier/report.json \
      --reward /logs/verifier/reward.txt

Exit codes: 0 = success (reward 1), 1 = grading failure (reward 0),
2 = infrastructure/parser error (reward 0). reward.txt is ALWAYS written.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
import xml.etree.ElementTree as ET
from typing import Any

# Normalized statuses; only exact PASSED counts as passed for grading.
PASSED, FAILED, ERROR, SKIPPED, UNKNOWN = (
    "PASSED",
    "FAILED",
    "ERROR",
    "SKIPPED",
    "UNKNOWN",
)


# ---------------------------------------------------------------------------
# Robust helpers
# ---------------------------------------------------------------------------
def parse_list(value: Any) -> list[str]:
    """Coerce a JSON array OR a string-encoded list into ``list[str]``.

    SWE-bench-style datasets often store list fields as strings, e.g.
    ``'["a", "b"]'`` or ``"['a', 'b']"``. All forms normalize to the same list.
    """
    if isinstance(value, list):
        return [str(x) for x in value]
    if isinstance(value, str):
        value = value.strip()
        if not value:
            return []
        for parser in (json.loads, ast.literal_eval):
            try:
                parsed = parser(value)
                if isinstance(parsed, list):
                    return [str(x) for x in parsed]
            except Exception:
                pass
    return []


def normalize_name(name: str) -> str:
    """Backslash→slash, collapse duplicate slashes, strip leading ./ and space."""
    n = name.strip().replace("\\", "/")
    n = re.sub(r"/+", "/", n)
    if n.startswith("./"):
        n = n[2:]
    return n


def _read(path: str | None) -> str:
    if not path:
        return ""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


# ---------------------------------------------------------------------------
# Framework parsers — text/JSON logs → [{name, status, raw_name, source}]
# ---------------------------------------------------------------------------
_PYTEST_RE = re.compile(
    r"^(?P<name>[\w./\-\[\]]+::[^\s]+)\s+(?P<status>PASSED|FAILED|ERROR|SKIPPED)",
    re.MULTILINE,
)
# unittest verbose: "test_name (module.TestClass) ... ok|FAIL|ERROR|skipped"
_UNITTEST_RE = re.compile(
    r"^(?P<test>\w+)\s+\((?P<cls>[\w.]+)\)\s+\.\.\.\s+"
    r"(?P<status>ok|FAIL|ERROR|skipped)",
    re.MULTILINE,
)
_STATUS_MAP = {
    "passed": PASSED,
    "pass": PASSED,
    "ok": PASSED,
    "failed": FAILED,
    "fail": FAILED,
    "error": ERROR,
    "skipped": SKIPPED,
    "skip": SKIPPED,
}


def _entry(name: str, status: str, source: str) -> dict[str, str]:
    return {
        "name": normalize_name(name),
        "status": status,
        "raw_name": name,
        "source": source,
    }


def parse_pytest(stdout: str, stderr: str) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for m in _PYTEST_RE.finditer(stdout + "\n" + stderr):
        out.append(_entry(m.group("name"), m.group("status").upper(), "pytest"))
    return out


def parse_pytest_junit(path: str | None) -> tuple[list[dict[str, str]], str | None]:
    if not path:
        return [], "pytest JUnit XML path was not configured"
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as exc:
        return [], f"could not read pytest JUnit XML: {exc}"
    out: list[dict[str, str]] = []
    for case in root.iter("testcase"):
        filename = normalize_name(case.attrib.get("file", ""))
        name = case.attrib.get("name", "")
        if not filename or not name:
            return [], "pytest JUnit XML contains a testcase without file/name"
        if case.find("failure") is not None:
            status = FAILED
        elif case.find("error") is not None:
            status = ERROR
        elif case.find("skipped") is not None:
            status = SKIPPED
        else:
            status = PASSED
        out.append(_entry(f"{filename}::{name}", status, "pytest-junit"))
    return out, None


def parse_unittest(stdout: str, stderr: str) -> list[dict[str, str]]:
    # unittest writes verbose results to stderr by default.
    out: list[dict[str, str]] = []
    for m in _UNITTEST_RE.finditer(stdout + "\n" + stderr):
        status = _STATUS_MAP.get(m.group("status").lower(), UNKNOWN)
        out.append(_entry(f"{m.group('cls')}.{m.group('test')}", status, "unittest"))
    return out


def _find_json(text: str) -> Any:
    """Best-effort: parse the largest JSON object/array embedded in *text*."""
    text = text.strip()
    try:
        return json.loads(text)
    except Exception:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        try:
            return json.loads(text[start : end + 1])
        except Exception:
            return None
    return None


def parse_jest(stdout: str, stderr: str) -> list[dict[str, str]]:
    data = _find_json(stdout) or _find_json(stderr)
    out: list[dict[str, str]] = []
    if not isinstance(data, dict):
        return out
    for suite in data.get("testResults", []):
        for a in suite.get("assertionResults", []):
            status = _STATUS_MAP.get(str(a.get("status", "")).lower(), UNKNOWN)
            title = a.get("fullName") or a.get("title") or ""
            out.append(_entry(title, status, "jest"))
    return out


def parse_mocha(stdout: str, stderr: str) -> list[dict[str, str]]:
    data = _find_json(stdout) or _find_json(stderr)
    out: list[dict[str, str]] = []
    if not isinstance(data, dict):
        return out
    for key, status in (("passes", PASSED), ("failures", FAILED), ("pending", SKIPPED)):
        for t in data.get(key, []):
            title = t.get("fullTitle") or t.get("title") or ""
            out.append(_entry(title, status, "mocha"))
    return out


def parse_go_test(stdout: str, stderr: str) -> list[dict[str, str]]:
    # `go test -json` emits one JSON object per line with Action/Test/Package.
    out: list[dict[str, str]] = []
    for line in (stdout + "\n" + stderr).splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        test = ev.get("Test")
        action = ev.get("Action")
        if not test or action not in ("pass", "fail", "skip"):
            continue
        status = {"pass": PASSED, "fail": FAILED, "skip": SKIPPED}[action]
        out.append(_entry(f"{ev.get('Package', '')}::{test}", status, "go-test"))
    return out


def parse_custom(stdout: str, stderr: str, parser_cfg: dict) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    text = stdout + "\n" + stderr
    pass_re = parser_cfg.get("pass_regex")
    fail_re = parser_cfg.get("fail_regex")
    for rx, status in ((pass_re, PASSED), (fail_re, FAILED)):
        if not rx:
            continue
        for m in re.finditer(rx, text, re.MULTILINE):
            name = m.groupdict().get("name") or (m.group(1) if m.groups() else "")
            if name:
                out.append(_entry(name, status, "custom"))
    return out


_PARSERS = {
    "pytest": parse_pytest,
    "unittest": parse_unittest,
    "jest": parse_jest,
    "mocha": parse_mocha,
    "go-test": parse_go_test,
}


def parse_results(
    framework: str, stdout: str, stderr: str, parser_cfg: dict
) -> list[dict[str, str]]:
    if framework == "custom":
        return parse_custom(stdout, stderr, parser_cfg)
    fn = _PARSERS.get(framework)
    return fn(stdout, stderr) if fn else []


# ---------------------------------------------------------------------------
# Matching: required name → parsed result (controlled, no broad fuzzy match)
# ---------------------------------------------------------------------------
def matched_passed(required: str, results: list[dict[str, str]]) -> bool:
    """True iff *required* maps to a parsed test whose status is exactly PASSED."""
    req = normalize_name(required)
    by_name: dict[str, str] = {}
    for r in results:
        # Last status wins; an exact PASSED is what we ultimately check.
        by_name[r["name"]] = r["status"]
    # 1) exact / whitespace / path-normalized (all folded into normalize_name).
    if req in by_name:
        return by_name[req] == PASSED
    # 2) unambiguous suffix match only.
    suffix_hits = [
        name
        for name in by_name
        if name.endswith("/" + req) or name.endswith("::" + req.split("::")[-1])
    ]
    if len(set(suffix_hits)) == 1:
        return by_name[suffix_hits[0]] == PASSED
    return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def _write(path: str, content: str) -> None:
    try:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
    except OSError as exc:  # pragma: no cover - disk failure
        sys.stderr.write(f"grade.py: could not write {path}: {exc}\n")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Compact verifier grader")
    ap.add_argument("--config", required=True)
    ap.add_argument("--stdout", default="")
    ap.add_argument("--stderr", default="")
    ap.add_argument("--results-xml", default="")
    ap.add_argument("--raw-exit-code", type=int, default=0)
    ap.add_argument("--output", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--reward", required=True)
    args = ap.parse_args(argv)

    def finish(reward: float, report: dict, exit_code: int) -> int:
        report.setdefault("reward", reward)
        _write(args.output, json.dumps({"tests": report.pop("_tests", [])}, indent=2))
        _write(args.report, json.dumps(report, indent=2))
        _write(args.reward, f"{1 if reward >= 1.0 else 0}\n")
        return exit_code

    # --- load config (infra error if unreadable) ---
    try:
        with open(args.config, encoding="utf-8") as fh:
            cfg = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        return finish(
            0.0,
            {
                "success": False,
                "infrastructure_error": f"could not read config.json: {exc}",
                "raw_exit_code": args.raw_exit_code,
            },
            2,
        )

    instance_id = (cfg.get("instance") or {}).get("instance_id", "")
    grading = cfg.get("grading") or {}
    parser_cfg = grading.get("parser") or {}
    framework = (parser_cfg.get("framework") or "").lower()
    result_source = (parser_cfg.get("result_source") or "").lower()

    # --- required tests: required_pass, else fail_to_pass ∪ pass_to_pass ---
    f2p = parse_list(grading.get("fail_to_pass"))
    p2p = parse_list(grading.get("pass_to_pass"))
    required_explicit = parse_list(grading.get("required_pass"))
    required = required_explicit if required_explicit else [*f2p, *p2p]
    # De-dup, preserve order.
    seen: set[str] = set()
    required = [r for r in required if not (r in seen or seen.add(r))]

    stdout, stderr = _read(args.stdout), _read(args.stderr)
    parse_error = None
    if framework == "pytest" and result_source == "junit_xml":
        results, parse_error = parse_pytest_junit(args.results_xml)
    else:
        results = parse_results(framework, stdout, stderr, parser_cfg)

    base_report: dict[str, Any] = {
        "instance_id": instance_id,
        "raw_exit_code": args.raw_exit_code,
        "parser_framework": framework or "unknown",
        "infrastructure_error": None,
        "_tests": results,
    }

    if parse_error:
        return finish(
            0.0,
            {
                **base_report,
                "success": False,
                "infrastructure_error": parse_error,
                "required_tests_count": len(required),
                "passed_tests_count": 0,
                "required_tests": required,
                "passed_required_tests": [],
                "missing_required_tests": required,
                "unexpected_failures": [],
                "duplicate_results": [],
                "unexpected_results": [],
            },
            2,
        )

    # Fail closed when no required tests are configured.
    if not required:
        return finish(
            0.0,
            {
                **base_report,
                "success": False,
                "infrastructure_error": "no required tests configured",
                "required_tests_count": 0,
                "passed_tests_count": 0,
                "required_tests": [],
                "passed_required_tests": [],
                "missing_required_tests": [],
                "unexpected_failures": [],
            },
            2,
        )

    passed_required = [r for r in required if matched_passed(r, results)]
    missing_required = [r for r in required if r not in passed_required]

    result_names = [normalize_name(r["name"]) for r in results]
    result_counts: dict[str, int] = {}
    for name in result_names:
        result_counts[name] = result_counts.get(name, 0) + 1
    duplicate_results = sorted(name for name, count in result_counts.items() if count != 1)
    required_names = {normalize_name(r) for r in required}
    unexpected_results = sorted(name for name in result_counts if name not in required_names)

    allow_extra = bool(grading.get("allow_extra_failures", True))
    unexpected: list[str] = []
    if not allow_extra:
        req_norm = {normalize_name(r) for r in required}
        unexpected = [
            r["name"]
            for r in results
            if r["status"] in (FAILED, ERROR) and r["name"] not in req_norm
        ]

    success = (
        args.raw_exit_code == 0
        and not missing_required
        and not unexpected
        and not duplicate_results
        and not unexpected_results
        and set(result_names) == required_names
    )
    reward = 1.0 if success else 0.0
    return finish(
        reward,
        {
            **base_report,
            "success": success,
            "required_tests_count": len(required),
            "passed_tests_count": len(passed_required),
            "required_tests": required,
            "passed_required_tests": passed_required,
            "missing_required_tests": missing_required,
            "unexpected_failures": unexpected,
            "duplicate_results": duplicate_results,
            "unexpected_results": unexpected_results,
        },
        0 if success else 1,
    )


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())

GRADE_PY_EOF

python3 /tmp/grade.py \
  --config "$CONFIG" \
  --stdout "$STDOUT_LOG" \
  --stderr "$STDERR_LOG" \
  --results-xml "$RESULTS_XML" \
  --raw-exit-code "$TEST_EXIT_CODE" \
  --output "$OUTPUT" \
  --report "$REPORT" \
  --reward "$REWARD"
GRADE_EXIT_CODE=$?

write_zero_reward_if_missing
exit "$GRADE_EXIT_CODE"
