#!/usr/bin/env bash
set -uo pipefail

CONFIG=${SENTINEL_CONFIG:-/tests/config.json}
PATCH=${SENTINEL_TEST_PATCH:-/tests/tests.patch}
LOG_DIR=${SENTINEL_LOG_DIR:-/logs/verifier}
REWARD="$LOG_DIR/reward.txt"
REPORT="$LOG_DIR/report.json"
OUTPUT="$LOG_DIR/output.json"
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
BASE_SHA=2b64673acb2d3db65dfc5cc2f988454bfd46000c
NODE_REL=web/__tests__/sentinel-story-navigation.test.js
P2P_REL=web/__tests__/crit-renderer.test.js
E2E_SPEC_REL=test/e2e/tests/sentinel-story-navigation.spec.ts
E2E_CONFIG_REL=test/e2e/sentinel.playwright.config.ts
MARKDOWN_REF=${SENTINEL_MARKDOWN_REF:-/opt/crit-deps/markdown-it.min.js}
MERMAID_REF=${SENTINEL_MERMAID_REF:-/opt/crit-deps/mermaid.min.js}
MARKDOWN_SHA=70fe17bd06c7fa819f03a1ed10957904318103624198845dc893b309bf495e28
MERMAID_SHA=74d7c46dabca328c2294733910a8aa1ed0c37451776e8d5295da38a2b758fb9b

mkdir -p "$LOG_DIR"
find "$LOG_DIR" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true
printf '0\n' > "$REWARD"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"

infra_fail() {
  local message=$1
  printf 'ERROR: %s\n' "$message" | tee -a "$STDERR_LOG" >&2
  python3 - "$message" "$REPORT" "$OUTPUT" <<'PY'
import json, sys
message, report_path, output_path = sys.argv[1:]
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump({"tests": []}, fh, indent=2)
with open(report_path, "w", encoding="utf-8") as fh:
    json.dump({"success": False, "reward": 0.0, "infrastructure_error": message}, fh, indent=2)
PY
  exit 2
}

[ -r "$CONFIG" ] || infra_fail "missing config.json"
[ -r "$PATCH" ] || infra_fail "missing tests.patch"
command -v node >/dev/null 2>&1 || infra_fail "node runtime is unavailable"
command -v python3 >/dev/null 2>&1 || infra_fail "python3 runtime is unavailable"
command -v go >/dev/null 2>&1 || infra_fail "Go runtime is unavailable"

WORKSPACE=${SENTINEL_WORKSPACE:-}
if [ -z "$WORKSPACE" ]; then
  for candidate in /testbed /workspace /app; do
    if [ -f "$candidate/package.json" ] && [ -f "$candidate/web/app.js" ]; then
      WORKSPACE=$candidate
      break
    fi
  done
fi
[ -n "$WORKSPACE" ] || infra_fail "could not locate the mounted crit workspace"

if [ -d "$WORKSPACE/.git" ] && command -v git >/dev/null 2>&1; then
  actual_head=$(git -c safe.directory="$WORKSPACE" -C "$WORKSPACE" rev-parse HEAD 2>>"$STDERR_LOG") \
    || infra_fail "workspace Git metadata is unusable"
  [ "$actual_head" = "$BASE_SHA" ] || infra_fail "workspace HEAD does not match the declared base"
fi

# The browser suite uses genuine upstream fixture helpers. Fail closed if a
# candidate changes any helper or dependency lock that controls the harness.
printf '%s  %s\n' \
  '7ee929c0852f412e6d08e0a195e196b42fc9d98754cde5eb329a2dbb155378ff' "$WORKSPACE/test/e2e/setup-fixtures.sh" \
  'c74d90e1d55ac22e791570f217a838c9cb3203f26b847394e9a4038c642463ac' "$WORKSPACE/test/e2e/lib.sh" \
  'a6e2834463f0d0ac99536ec846d967157bd74c12563031eb32282105f94c8e09' "$WORKSPACE/test/e2e/tests/helpers.ts" \
  'c6d267962f4515e57816dad217dc35813062d92845c80a84bed13774c24db5ab' "$WORKSPACE/test/e2e/tests/state-file.ts" \
  '4dd440c0b5639eec1723b35feaaeb11f4bf8e8a52827d5d9d4c32127d5d8c549' "$WORKSPACE/test/e2e/package.json" \
  '12f273a1137de6d318f635ac80dd7e0480ad46eb5a907fc789308c6302570b49' "$WORKSPACE/test/e2e/package-lock.json" \
  | sha256sum -c - >>"$STDERR_LOG" 2>&1 \
  || infra_fail "upstream browser fixture infrastructure was modified"

# Restore the genuine upstream renderer regression file from a verifier-owned
# snapshot so candidate edits cannot weaken pass-to-pass protection.
P2P_GZ_B64='H4sIAAAAAAACA6VUTWvcMBC951cM9CAvuF5yyGVDCiFtaaGhoeRWyqKVp7ZaWUqk2YZi9r939OHNZndTUnqwjfXevDd6I1s5GwhGaDEor1dYgybYwAV4vF9rj5WwrsUFYSAxOz9RiS5DQE8HpLw8D+S1SuxC92hb9Oh3C5pmzn70esKaHyFVTH1U4gksaqhmcPEGxhPgDivhsdOBWFPaFtTaM5GekACy+eDUTzbOSwCs7oy5dZdW9c4vSsGNd4MO2HgMzvzCalYXeq+73vBFL+Qrg9J/mIom+riZcGcvrXUkSTv70RI3PXH2mR3SdQy1ACJNYAfMDd3+vnukGG2xUDbn6bFNd4qrinHMMpjH1eRxvbtfS1Nt+SVR3hjsVGzheC+C/yZm18akik0c9t4oqffuIXBGwOEGbTsYkHrX7s21WGV2lZHDjY4btptfuRTyl+kEFuH5fg8ypfmex3rlhoEr4EFTDzFRyNjRwyXTkS7WBxrVCN+1weWdpH4BQjadY5VA0tMyKi/gtAauLi9nqaGdHWKKUTbEQ67LeI8zos0Nu9TF5TgrOX9ilRpOjzO4mYyfvTCgt5+v/yuf1g1LWT6tEWJQVg6chZizngphGdCgogiLVyuyvEqyW6pearuAr2K1JnJWfONf1t/DY6NnUplM62j6THClibo0sQ0nXn8AJfdHVUIFAAA='
python3 - "$WORKSPACE/$P2P_REL" "$P2P_GZ_B64" <<'PY' || infra_fail "could not restore upstream regression test"
import base64, gzip, os, sys, tempfile
target, encoded = sys.argv[1:]
data = gzip.decompress(base64.b64decode(encoded))
os.makedirs(os.path.dirname(target), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target))
try:
    with os.fdopen(fd, "wb") as fh:
        fh.write(data)
    os.replace(tmp, target)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY

actual_p2p=$(sha256sum "$WORKSPACE/$P2P_REL" | awk '{print $1}')
[ "$actual_p2p" = 63a73ae7b60d08c341626d1ef19cc6565956a0e177d02481d800b379f6ab71bb ] \
  || infra_fail "upstream regression snapshot failed integrity validation"

# Remove only the verifier-owned paths before applying the hidden patch.
for rel in "$NODE_REL" "$E2E_SPEC_REL" "$E2E_CONFIG_REL"; do
  target="$WORKSPACE/$rel"
  if [ -L "$target" ]; then
    unlink "$target" || infra_fail "could not remove a verifier path symlink"
  elif [ -f "$target" ]; then
    find "$target" -maxdepth 0 -type f -delete || infra_fail "could not remove a verifier path collision"
  elif [ -e "$target" ]; then
    infra_fail "verifier path collision is not a regular file"
  fi
done

if command -v git >/dev/null 2>&1 && [ -d "$WORKSPACE/.git" ]; then
  git -c safe.directory="$WORKSPACE" -C "$WORKSPACE" apply --check "$PATCH" 2>>"$STDERR_LOG" \
    || infra_fail "tests.patch does not apply cleanly"
  git -c safe.directory="$WORKSPACE" -C "$WORKSPACE" apply "$PATCH" 2>>"$STDERR_LOG" \
    || infra_fail "tests.patch application failed"
elif command -v patch >/dev/null 2>&1; then
  (cd "$WORKSPACE" && patch -p1 --forward < "$PATCH") >>"$STDERR_LOG" 2>&1 \
    || infra_fail "tests.patch application failed without Git metadata"
else
  infra_fail "neither git nor patch is available"
fi

printf '%s  %s\n' "$MARKDOWN_SHA" "$MARKDOWN_REF" | sha256sum -c - >>"$STDERR_LOG" 2>&1 \
  || infra_fail "pinned Markdown reference is missing or corrupt"
printf '%s  %s\n' "$MERMAID_SHA" "$MERMAID_REF" | sha256sum -c - >>"$STDERR_LOG" 2>&1 \
  || infra_fail "pinned diagram reference is missing or corrupt"

TRUSTED_E2E=${SENTINEL_E2E_NODE_MODULES:-/opt/crit-e2e/node_modules}
[ -f "$TRUSTED_E2E/@playwright/test/cli.js" ] || infra_fail "trusted Playwright runtime is unavailable"
workspace_modules="$WORKSPACE/test/e2e/node_modules"
if [ -L "$workspace_modules" ]; then
  unlink "$workspace_modules" || infra_fail "could not replace browser dependencies"
elif [ -d "$workspace_modules" ]; then
  find "$workspace_modules" -depth -delete || infra_fail "could not replace browser dependencies"
elif [ -e "$workspace_modules" ]; then
  infra_fail "browser dependency path is not a directory"
fi
ln -s "$TRUSTED_E2E" "$workspace_modules" || infra_fail "could not mount trusted browser dependencies"

export SENTINEL_WORKSPACE="$WORKSPACE"
export SENTINEL_MARKDOWN_EXPECTED="$MARKDOWN_REF"
export SENTINEL_MERMAID_EXPECTED="$MERMAID_REF"
export SENTINEL_PLAYWRIGHT_CLI="$TRUSTED_E2E/@playwright/test/cli.js"

python3 - "$CONFIG" "$WORKSPACE/$NODE_REL" "$WORKSPACE/$P2P_REL" \
  "$WORKSPACE/$E2E_SPEC_REL" "$WORKSPACE/$E2E_CONFIG_REL" \
  "$OUTPUT" "$REPORT" "$REWARD" "$STDOUT_LOG" "$STDERR_LOG" <<'PY'
import json
import os
import re
import secrets
import socket
import subprocess
import sys
import tempfile

(config_path, node_file, p2p_file, e2e_file, e2e_config,
 output_path, report_path, reward_path, stdout_path, stderr_path) = sys.argv[1:]
with open(config_path, encoding="utf-8") as fh:
    config = json.load(fh)
grading = config.get("grading") or {}
f2p = grading.get("fail_to_pass") or []
p2p = grading.get("pass_to_pass") or []
declared = [*f2p, *p2p]

node_f2p = {
    "line comment anchor preserves side and scope",
    "file comment anchor preserves scope without a side",
    "npm and Bun lockfiles select markdown-it 14.3.0 and mermaid 11.16.0",
    "embedded markdown runtime matches markdown-it 14.3.0",
    "embedded diagram runtime matches mermaid 11.16.0",
}
node_p2p = {
    "register and current",
    "register throws on missing method",
    "anchorFromComment with line anchor",
    "anchorFromComment with DOM anchor",
}

def infrastructure(message):
    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump({"tests": []}, fh, indent=2)
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump({"success": False, "reward": 0.0, "infrastructure_error": message}, fh, indent=2)
    with open(reward_path, "w", encoding="utf-8") as fh:
        fh.write("0\n")
    raise SystemExit(2)

if not isinstance(f2p, list) or not isinstance(p2p, list):
    infrastructure("graded test lists must be JSON arrays")
if not 10 <= len(f2p) <= 20:
    infrastructure("fail_to_pass count must be between 10 and 20")
if len(set(declared)) != len(declared):
    infrastructure("graded test IDs must be unique")
if grading.get("allow_extra_failures") is not False:
    infrastructure("allow_extra_failures must be false")
if not node_f2p.issubset(set(f2p)) or not node_p2p.issubset(set(p2p)):
    infrastructure("graded Node inventory does not match the verifier")

browser_f2p = [name for name in f2p if name not in node_f2p]
browser_p2p = [name for name in p2p if name not in node_p2p]
browser_declared = [*browser_f2p, *browser_p2p]
if not browser_declared:
    infrastructure("browser test inventory is empty")

result_map = {}
all_stdout = []
all_stderr = []
completion_dir = tempfile.mkdtemp(prefix="sentinel-completions-", dir=os.path.dirname(output_path))

def invoke_node(name, test_file, env_extra, pattern=None):
    token = secrets.token_hex(32)
    completion = os.path.join(completion_dir, secrets.token_hex(16))
    env = os.environ.copy()
    env.update(env_extra)
    env["SENTINEL_COMPLETION_FILE"] = completion
    env["SENTINEL_COMPLETION_TOKEN"] = token
    cmd = ["node", "--test", "--test-reporter=tap"]
    if pattern is not None:
        cmd.append(f"--test-name-pattern=^{re.escape(pattern)}$")
    cmd.append(test_file)
    try:
        proc = subprocess.run(cmd, env=env, text=True, capture_output=True, timeout=15)
        completed = False
        try:
            with open(completion, encoding="utf-8") as fh:
                completed = secrets.compare_digest(fh.read(), token)
        except OSError:
            pass
        passed = proc.returncode == 0 and completed
        all_stdout.append(f"===== {name} =====\n{proc.stdout}")
        all_stderr.append(f"===== {name} =====\n{proc.stderr}")
        result_map[name] = {"name": name, "status": "PASSED" if passed else "FAILED", "exit_code": proc.returncode, "completed": completed}
    except subprocess.TimeoutExpired as exc:
        all_stdout.append(f"===== {name} =====\n{exc.stdout or ''}")
        all_stderr.append(f"===== {name} =====\nTIMEOUT\n{exc.stderr or ''}")
        result_map[name] = {"name": name, "status": "FAILED", "exit_code": 124, "completed": False}

for name in f2p:
    if name in node_f2p:
        invoke_node(name, node_file, {"SENTINEL_CASE": name})

wrapper = os.path.join(completion_dir, "p2p-wrapper.js")
with open(wrapper, "w", encoding="utf-8") as fh:
    fh.write("const { after } = require('node:test');\n")
    fh.write("const fs = require('node:fs');\n")
    fh.write("after(() => fs.writeFileSync(process.env.SENTINEL_COMPLETION_FILE, process.env.SENTINEL_COMPLETION_TOKEN));\n")
    fh.write("require(process.env.SENTINEL_P2P_FILE);\n")
for name in p2p:
    if name in node_p2p:
        invoke_node(name, wrapper, {"SENTINEL_P2P_FILE": p2p_file}, pattern=name)

def run_browser(names, label):
    if not names:
        return 0, {}, True
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = str(sock.getsockname()[1])
    env = os.environ.copy()
    env["CRIT_TEST_PORT"] = port
    title_filter = "|".join(re.escape(name) for name in names)
    cmd = [
        "node", os.environ["SENTINEL_PLAYWRIGHT_CLI"], "test",
        os.path.basename(e2e_file), "--config", os.path.basename(e2e_config),
        "--reporter=json", "--grep", title_filter,
    ]
    status = 1
    stdout = ""
    stderr = ""
    try:
        proc = subprocess.run(
            cmd, cwd=os.path.dirname(e2e_config), env=env, text=True,
            capture_output=True, timeout=150,
        )
        status = proc.returncode
        stdout = proc.stdout
        stderr = proc.stderr
    except subprocess.TimeoutExpired as exc:
        status = 124
        stdout = exc.stdout or ""
        stderr = f"TIMEOUT\n{exc.stderr or ''}"
    all_stdout.append(f"===== browser {label} =====\n{stdout}")
    all_stderr.append(f"===== browser {label} =====\n{stderr}")
    observed = {}
    try:
        payload = json.loads(stdout)
        def visit(suite):
            for spec in suite.get("specs", []):
                tests = spec.get("tests", [])
                runs = [run for test in tests for run in test.get("results", [])]
                passed = bool(spec.get("ok")) and bool(runs) and all(run.get("status") == "passed" for run in runs)
                observed[spec.get("title", "")] = passed
            for child in suite.get("suites", []):
                visit(child)
        for suite in payload.get("suites", []):
            visit(suite)
    except (json.JSONDecodeError, TypeError, AttributeError):
        pass
    return status, observed, set(observed) == set(names)

# Run genuine regressions first in a fresh fixture server. Expected F2P
# failures cannot contaminate their browser pages or daemon state.
p2p_browser_status, p2p_browser_observed, p2p_browser_inventory_ok = run_browser(browser_p2p, "pass-to-pass")
f2p_browser_status, f2p_browser_observed, f2p_browser_inventory_ok = run_browser(browser_f2p, "fail-to-pass")
browser_observed = {**f2p_browser_observed, **p2p_browser_observed}
browser_inventory_ok = p2p_browser_inventory_ok and f2p_browser_inventory_ok
browser_status = {
    **{name: f2p_browser_status for name in browser_f2p},
    **{name: p2p_browser_status for name in browser_p2p},
}
for name in browser_declared:
    passed = browser_inventory_ok and browser_observed.get(name, False)
    result_map[name] = {
        "name": name,
        "status": "PASSED" if passed else "FAILED",
        "exit_code": browser_status[name],
        "completed": name in browser_observed,
    }

with open(stdout_path, "a", encoding="utf-8") as fh:
    fh.write("\n".join(all_stdout))
with open(stderr_path, "a", encoding="utf-8") as fh:
    fh.write("\n".join(all_stderr))

results = [result_map.get(name, {"name": name, "status": "FAILED", "exit_code": 125, "completed": False}) for name in declared]
inventory_ok = set(result_map) == set(declared) and browser_inventory_ok
browser_raw_ok = p2p_browser_status == 0 and f2p_browser_status == 0
success = inventory_ok and browser_raw_ok and all(item["status"] == "PASSED" for item in results)
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump({"tests": results}, fh, indent=2)
with open(report_path, "w", encoding="utf-8") as fh:
    json.dump({
        "success": success,
        "reward": 1.0 if success else 0.0,
        "infrastructure_error": None,
        "required_tests_count": len(declared),
        "observed_tests_count": len(result_map),
        "inventory_exact": inventory_ok,
        "failed_tests": [item["name"] for item in results if item["status"] != "PASSED"],
    }, fh, indent=2)
with open(reward_path, "w", encoding="utf-8") as fh:
    fh.write("1\n" if success else "0\n")
raise SystemExit(0 if success else 1)
PY
