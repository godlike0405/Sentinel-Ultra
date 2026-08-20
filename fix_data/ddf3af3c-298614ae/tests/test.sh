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
RAW_STDOUT_LOG="$LOG_DIR/test-raw-stdout.txt"
REPORT="$LOG_DIR/report.json"
OUTPUT="$LOG_DIR/output.json"
REWARD="$LOG_DIR/reward.txt"
VERIFIER_ROOT=""
RESULTS_JSON=""

mkdir -p "$LOG_DIR"

# Safety net: if we crash before the grader writes the reward, write 0.
cleanup_verifier() {
  if [ ! -f "$REWARD" ]; then echo "0" > "$REWARD"; fi
  if [ -n "$VERIFIER_ROOT" ] && [ -d "$VERIFIER_ROOT" ]; then
    case "$VERIFIER_ROOT" in
      /tmp/unity-object-verifier.*) rm -rf -- "$VERIFIER_ROOT" ;;
    esac
  fi
}
trap cleanup_verifier EXIT

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

AGENT_WORKSPACE="$WORKSPACE"
VERIFIER_ROOT="$(mktemp -d /tmp/unity-object-verifier.XXXXXX)" || exit 2
cp -a "$AGENT_WORKSPACE" "$VERIFIER_ROOT/app" || exit 2
mkdir -p "$VERIFIER_ROOT/harness" || exit 2
cat > "$VERIFIER_ROOT/harness/Harness.csproj" <<'HARNESS_CSPROJ_EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
    <UseAppHost>false</UseAppHost>
    <AssemblyName>Harness</AssemblyName>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems>
    <InvariantGlobalization>true</InvariantGlobalization>
    <DefineConstants>UNITY_EDITOR</DefineConstants>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="Shims.cs" />
    <Compile Include="Runner.cs" />
    <Compile Include="../app/Runtime/Utils/UnityObjectNameComparer.cs" />
    <Compile Include="../app/Runtime/Core/Extension/IListExtensions.cs" />
    <Compile Include="../injected/Tests/VerifierOnly/UnityObjectNameComparerNaturalSortTests.cs" />
  </ItemGroup>
  <Import Project="SubmissionSources.props" />
</Project>
HARNESS_CSPROJ_EOF
cat > "$VERIFIER_ROOT/harness/Runner.cs" <<'HARNESS_RUNNER_EOF'
using System;
using System.Linq;
using System.Reflection;
using NUnit.Framework;

internal static class Runner
{
    private static int Main(string[] args)
    {
        if (args.Length != 1 || string.IsNullOrWhiteSpace(args[0]))
        {
            Console.Error.WriteLine("Exactly one fully-qualified test name is required");
            return 2;
        }

        string requestedName = args[0];
        var candidates = (
            from fixture in Assembly.GetExecutingAssembly().GetTypes()
            where fixture.GetCustomAttribute<TestFixtureAttribute>() != null
            from test in fixture.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            where test.GetCustomAttribute<TestAttribute>() != null
            let name = fixture.FullName + "." + test.Name
            where string.Equals(name, requestedName, StringComparison.Ordinal)
            select new { Fixture = fixture, Test = test }
        ).ToArray();

        if (candidates.Length != 1)
        {
            Console.Error.WriteLine(
                $"{requestedName}: expected exactly one matching test, found {candidates.Length}"
            );
            return 2;
        }

        Type fixtureType = candidates[0].Fixture;
        MethodInfo testMethod = candidates[0].Test;
        MethodInfo[] methods = fixtureType.GetMethods(BindingFlags.Public | BindingFlags.Instance);
        MethodInfo[] setUps = methods
            .Where(method => method.GetCustomAttribute<SetUpAttribute>() != null)
            .ToArray();
        MethodInfo[] tearDowns = methods
            .Where(method => method.GetCustomAttribute<TearDownAttribute>() != null)
            .ToArray();
        object instance = Activator.CreateInstance(fixtureType);
        bool passed = true;

        try
        {
            foreach (MethodInfo setUp in setUps)
            {
                setUp.Invoke(instance, null);
            }
            testMethod.Invoke(instance, null);
        }
        catch (Exception ex)
        {
            Exception cause = (ex as TargetInvocationException)?.InnerException ?? ex;
            Console.Error.WriteLine(
                $"{requestedName}: {cause.GetType().Name}: {cause.Message}"
            );
            passed = false;
        }
        finally
        {
            foreach (MethodInfo tearDown in tearDowns)
            {
                try
                {
                    tearDown.Invoke(instance, null);
                }
                catch (Exception ex)
                {
                    Exception cause = (ex as TargetInvocationException)?.InnerException ?? ex;
                    Console.Error.WriteLine(
                        $"{requestedName}: teardown {cause.GetType().Name}: {cause.Message}"
                    );
                    passed = false;
                }
            }
        }

        if (!passed)
        {
            return 1;
        }

        // The controlling verifier sends its unpredictable challenge only after
        // this marker, which is emitted strictly after the test and teardown return.
        Console.WriteLine("VERIFIER_READY");
        Console.Out.Flush();
        string challenge = Console.ReadLine();
        if (string.IsNullOrEmpty(challenge))
        {
            return 2;
        }
        Console.WriteLine("VERIFIER_COMPLETE " + challenge);
        Console.Out.Flush();
        return 0;
    }
}
HARNESS_RUNNER_EOF
cat > "$VERIFIER_ROOT/harness/RunSelectedTests.py" <<'HARNESS_CONTROLLER_EOF'
#!/usr/bin/env python3
import json
import os
import secrets
import select
import subprocess
import sys
import time

if len(sys.argv) != 4:
    raise SystemExit("usage: RunSelectedTests.py HARNESS RESULTS CONFIG")

harness, result_path, config_path = sys.argv[1:]
with open(config_path, encoding="utf-8") as stream:
    grading = (json.load(stream).get("grading") or {})

required = []
for key in ("fail_to_pass", "pass_to_pass"):
    for name in grading.get(key, []):
        if name not in required:
            required.append(name)


def read_line(stream, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return None
    readable, _, _ = select.select([stream], [], [], remaining)
    return stream.readline() if readable else None


results = []
failed = False
for name in required:
    process = subprocess.Popen(
        ["dotnet", harness, name],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env={key: value for key, value in os.environ.items() if key != "VERIFIER_RESULTS_PATH"},
    )
    deadline = time.monotonic() + 30
    ready = read_line(process.stdout, deadline)
    completed = False
    challenge = secrets.token_hex(32)
    if ready == "VERIFIER_READY\n":
        try:
            process.stdin.write(challenge + "\n")
            process.stdin.flush()
            response = read_line(process.stdout, deadline)
            completed = response == "VERIFIER_COMPLETE " + challenge + "\n"
        except (BrokenPipeError, OSError):
            completed = False

    try:
        exit_code = process.wait(timeout=max(0.1, deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        process.kill()
        exit_code = process.wait()
    diagnostics = process.stderr.read()
    passed = completed and exit_code == 0
    results.append({"Name": name, "Status": "PASSED" if passed else "FAILED"})
    if not passed:
        failed = True
        detail = diagnostics.strip() or "missing verifier-owned completion handshake"
        observed = "" if ready is None else ready.rstrip("\n")
        print(name + ": " + detail + "; first stdout line=" + repr(observed), file=sys.stderr)

temporary_path = result_path + ".tmp"
with open(temporary_path, "w", encoding="utf-8") as stream:
    json.dump(results, stream)
os.replace(temporary_path, result_path)
raise SystemExit(1 if failed else 0)
HARNESS_CONTROLLER_EOF
cat > "$VERIFIER_ROOT/harness/Shims.cs" <<'HARNESS_SHIMS_EOF'
using System;
using System.Collections.Generic;

namespace UnityEngine
{
    public static class Mathf
    {
        public static int Min(int left, int right) => left < right ? left : right;
    }

    public class Object
    {
        private static int _nextId = 1000;
        private readonly int _instanceId;

        public Object()
        {
            _instanceId = ++_nextId;
        }

        public string name { get; set; }

        public int GetInstanceID() => _instanceId;

        public static void DestroyImmediate(Object obj) { }
    }

    public class GameObject : Object
    {
        public GameObject() { }

        public GameObject(string name)
        {
            this.name = name;
        }
    }
}

namespace WallstopStudios.UnityHelpers.Core.Helper
{
    public static class MathShim
    {
        public static int PositiveMod(this int value, int modulus)
        {
            int result = value % modulus;
            return result < 0 ? result + modulus : result;
        }
    }
}

namespace WallstopStudios.UnityHelpers.Core.Serialization
{
    public static class Serializer
    {
        public static string JsonStringify<T>(T value) => string.Empty;
    }
}

namespace UnityEditor
{
    public static class AssetDatabase
    {
        private static readonly Dictionary<UnityEngine.Object, string> Paths = new();

        public static string GetAssetOrScenePath(UnityEngine.Object value)
        {
            return value != null && Paths.TryGetValue(value, out string path)
                ? path
                : string.Empty;
        }

        public static void SetAssetOrScenePath(UnityEngine.Object value, string path)
        {
            Paths[value] = path;
        }
    }
}

namespace WallstopStudios.UnityHelpers.Core.Random
{
    public interface IRandom
    {
        int Next(int minimum, int maximum);
    }

    public sealed class PRNG : IRandom
    {
        public static readonly PRNG Instance = new();

        private PRNG() { }

        public int Next(int minimum, int maximum) => minimum;
    }
}

namespace NUnit.Framework
{
    [AttributeUsage(AttributeTargets.Class)]
    public sealed class TestFixtureAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Method)]
    public sealed class TestAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Method)]
    public sealed class SetUpAttribute : Attribute { }

    [AttributeUsage(AttributeTargets.Method)]
    public sealed class TearDownAttribute : Attribute { }

    public class AssertionException : Exception
    {
        public AssertionException(string message)
            : base(message) { }
    }

    public static class Assert
    {
        public static void Less(int actual, int expected)
        {
            if (!(actual < expected))
            {
                throw new AssertionException($"Expected {actual} to be less than {expected}");
            }
        }

        public static void Greater(int actual, int expected)
        {
            if (!(actual > expected))
            {
                throw new AssertionException(
                    $"Expected {actual} to be greater than {expected}"
                );
            }
        }

        public static void AreSame(object expected, object actual)
        {
            if (!ReferenceEquals(expected, actual))
            {
                throw new AssertionException("Expected both references to identify the same object");
            }
        }
    }
}
HARNESS_SHIMS_EOF

# Compile production sources added or changed by the solution as well as the
# established comparer and collection entry points above. This permits normal
# helper extraction without pulling the entire Unity package (which requires a
# Unity compiler and assemblies unavailable in this standalone verifier).
python3 - "$VERIFIER_ROOT/app" "$VERIFIER_ROOT/harness/SubmissionSources.props" <<'PY'
import html
import pathlib
import subprocess
import sys

workspace = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2])
base_commit = "17f447af072e1a9f85d646139d2179933fc39001"


def git_paths(*args):
    completed = subprocess.run(
        ["git", "-C", str(workspace), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return completed.stdout.splitlines()


paths = set(
    git_paths("diff", "--name-only", "--diff-filter=ACMR", base_commit, "--", "*.cs")
)
paths.update(git_paths("ls-files", "--others", "--exclude-standard", "--", "*.cs"))

always_compiled = {
    "Runtime/Utils/UnityObjectNameComparer.cs",
    "Runtime/Core/Extension/IListExtensions.cs",
}
compile_items = []
for relative in sorted(paths - always_compiled):
    candidate = pathlib.PurePosixPath(relative)
    if candidate.is_absolute() or ".." in candidate.parts or "Tests" in candidate.parts:
        continue
    source = workspace.joinpath(*candidate.parts)
    if source.is_file() and not source.is_symlink():
        compile_items.append(source)

lines = ["<Project>", "  <ItemGroup>"]
for source in compile_items:
    escaped = html.escape(str(source), quote=True)
    lines.append(f'    <Compile Include="{escaped}" />')
lines.extend(["  </ItemGroup>", "</Project>", ""])
output.write_text("\n".join(lines), encoding="utf-8")
PY
mkdir -p "$VERIFIER_ROOT/injected" || exit 2

WORKSPACE="$VERIFIER_ROOT/app"
export VERIFIER_HARNESS_DIR="$VERIFIER_ROOT/harness"
RESULTS_JSON="$VERIFIER_ROOT/harness/test-results.json"
cp -- "$CONFIG" "$VERIFIER_ROOT/harness/config.json" || exit 2
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

# Materialize the eval tests into a fresh verifier-owned directory. Neither the
# harness nor its injected sources exist in the solver-visible image.
if [ -f /tests/tests.patch ]; then
  if ! command -v patch >/dev/null 2>&1; then
    echo "ERROR: patch command is unavailable" | tee -a "$STDERR_LOG"
    echo '{"success": false, "infrastructure_error": "missing patch command", "reward": 0.0}' > "$REPORT"
    echo "0" > "$REWARD"
    exit 2
  fi

  rm -rf -- "$VERIFIER_ROOT/injected"
  mkdir -p "$VERIFIER_ROOT/injected"
  if ! patch -d "$VERIFIER_ROOT/injected" -p1 --forward \
      < /tests/tests.patch >>"$STDERR_LOG" 2>&1; then
    echo "ERROR: failed to apply tests/tests.patch" | tee -a "$STDERR_LOG"
    echo '{"success": false, "infrastructure_error": "tests.patch did not apply", "reward": 0.0}' > "$REPORT"
    echo "0" > "$REWARD"
    exit 2
  fi
fi

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
rm -f -- "$RESULTS_JSON" "$RESULTS_JSON.tmp"
"${RUNNER[@]}" > "$RAW_STDOUT_LOG" 2> "$STDERR_LOG"
TEST_EXIT_CODE=$?
set -e

if [ -f "$RESULTS_JSON" ]; then
  cp -- "$RESULTS_JSON" "$STDOUT_LOG"
else
  : > "$STDOUT_LOG"
fi

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


def parse_verifier_json(stdout: str, stderr: str) -> list[dict[str, str]]:
    data = _find_json(stdout)
    out: list[dict[str, str]] = []
    if not isinstance(data, list):
        return out
    for result in data:
        if not isinstance(result, dict):
            continue
        name = result.get("Name") or result.get("name") or ""
        status = str(result.get("Status") or result.get("status") or "").upper()
        if name:
            out.append(
                _entry(
                    str(name),
                    status if status in (PASSED, FAILED, ERROR, SKIPPED) else UNKNOWN,
                    "verifier-json",
                )
            )
    return out


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
    "verifier-json": parse_verifier_json,
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

    # --- required tests: required_pass, else fail_to_pass ∪ pass_to_pass ---
    f2p = parse_list(grading.get("fail_to_pass"))
    p2p = parse_list(grading.get("pass_to_pass"))
    required_explicit = parse_list(grading.get("required_pass"))
    required = required_explicit if required_explicit else [*f2p, *p2p]
    # De-dup, preserve order.
    seen: set[str] = set()
    required = [r for r in required if not (r in seen or seen.add(r))]

    stdout, stderr = _read(args.stdout), _read(args.stderr)
    results = parse_results(framework, stdout, stderr, parser_cfg)

    base_report: dict[str, Any] = {
        "instance_id": instance_id,
        "raw_exit_code": args.raw_exit_code,
        "parser_framework": framework or "unknown",
        "infrastructure_error": None,
        "_tests": results,
    }

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

    allow_extra = bool(grading.get("allow_extra_failures", True))
    unexpected: list[str] = []
    unexpected_results: list[str] = []
    duplicate_results: list[str] = []
    if not allow_extra:
        req_norm = {normalize_name(r) for r in required}
        unexpected = [
            r["name"]
            for r in results
            if r["status"] in (FAILED, ERROR) and r["name"] not in req_norm
        ]
        observed_names = [normalize_name(r["name"]) for r in results]
        unexpected_results = [name for name in observed_names if name not in req_norm]
        duplicate_results = sorted(
            {name for name in observed_names if observed_names.count(name) > 1}
        )

    success = (
        args.raw_exit_code == 0
        and not missing_required
        and not unexpected
        and not unexpected_results
        and not duplicate_results
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
            "unexpected_results": unexpected_results,
            "duplicate_results": duplicate_results,
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
  --raw-exit-code "$TEST_EXIT_CODE" \
  --output "$OUTPUT" \
  --report "$REPORT" \
  --reward "$REWARD"
GRADE_EXIT_CODE=$?

cleanup_verifier
VERIFIER_ROOT=""
exit "$GRADE_EXIT_CODE"
