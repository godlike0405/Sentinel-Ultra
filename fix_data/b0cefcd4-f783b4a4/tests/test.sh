#!/usr/bin/env bash
# Task-specific, fail-closed verifier. Test outcomes are graded only from a
# verifier-owned JSON file populated from Pester's TestResult objects; build or
# module stdout/stderr is diagnostic only and cannot create passing records.
set -uo pipefail

CONFIG=/tests/config.json
TEST_PATCH=/tests/tests.patch
LOG_DIR=/logs/verifier
STDOUT_LOG="$LOG_DIR/test-stdout.txt"
STDERR_LOG="$LOG_DIR/test-stderr.txt"
RESULTS_JSON="$LOG_DIR/pester-results.json"
OUTPUT="$LOG_DIR/output.json"
REPORT="$LOG_DIR/report.json"
REWARD="$LOG_DIR/reward.txt"
BASE_COMMIT=f8fcfb14dbcddbf9b9f11a555f8971bc1379fe93

mkdir -p "$LOG_DIR"
: > "$STDOUT_LOG"
: > "$STDERR_LOG"
rm -f "$RESULTS_JSON" "$OUTPUT" "$REPORT" "$REWARD"

write_zero_reward_if_missing() {
    if [ ! -f "$REWARD" ]; then
        echo 0 > "$REWARD"
    fi
}
trap write_zero_reward_if_missing EXIT

infrastructure_error() {
    local message=$1
    python3 - "$message" "$REPORT" "$OUTPUT" <<'PY'
import json, sys
message, report_path, output_path = sys.argv[1:]
with open(report_path, "w", encoding="utf-8") as fh:
    json.dump({"success": False, "infrastructure_error": message, "reward": 0.0}, fh, indent=2)
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump({"tests": []}, fh, indent=2)
PY
    echo 0 > "$REWARD"
    echo "ERROR: $message" | tee -a "$STDERR_LOG" >&2
    exit 2
}

[ -f "$CONFIG" ] || infrastructure_error "missing config.json"
[ -f "$TEST_PATCH" ] || infrastructure_error "missing tests.patch"

WORKSPACE=
for candidate in /app /testbed /workspace; do
    if [ -d "$candidate" ]; then
        WORKSPACE=$candidate
        break
    fi
done
[ -n "$WORKSPACE" ] || infrastructure_error "could not resolve workspace"

PWSH_BIN=/root/.dotnet/tools/pwsh
if [ ! -x "$PWSH_BIN" ]; then
    PWSH_BIN=$(command -v pwsh 2>/dev/null || true)
fi
[ -n "$PWSH_BIN" ] && [ -x "$PWSH_BIN" ] || infrastructure_error "could not resolve pwsh"

# Build before materializing the verifier-owned test file. This prevents an
# agent-controlled build target from replacing the tests after they are added.
BUILD_COMMAND=$(python3 - <<'PY'
import json
with open("/tests/config.json", encoding="utf-8") as fh:
    commands = (json.load(fh).get("execution") or {}).get("commands") or []
if not isinstance(commands, list) or not commands or not isinstance(commands[0], str):
    raise SystemExit("missing build command")
print(commands[0])
PY
) || infrastructure_error "invalid build command configuration"

TIMEOUT_SEC=$(python3 - <<'PY'
import json
with open("/tests/config.json", encoding="utf-8") as fh:
    print((json.load(fh).get("execution") or {}).get("timeout_sec", 1800))
PY
) || infrastructure_error "invalid timeout configuration"

set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" bash -c "$BUILD_COMMAND" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
else
    bash -c "$BUILD_COMMAND" >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
fi
BUILD_EXIT=$?
set -e
[ "$BUILD_EXIT" -eq 0 ] || infrastructure_error "project build failed with exit code $BUILD_EXIT"

cd "$WORKSPACE" || infrastructure_error "could not enter workspace"
rm -f "$WORKSPACE/test/Pester/SchemaMigration.Tests.ps1"
GIT=(git -c "safe.directory=$WORKSPACE")
APPLIED=0
if command -v git >/dev/null 2>&1; then
    if "${GIT[@]}" apply "$TEST_PATCH" 2>>"$STDERR_LOG" \
        || "${GIT[@]}" apply --3way "$TEST_PATCH" 2>>"$STDERR_LOG"; then
        APPLIED=1
    fi
fi
if [ "$APPLIED" != 1 ] && command -v patch >/dev/null 2>&1; then
    if patch -p1 --forward < "$TEST_PATCH" >>"$STDERR_LOG" 2>&1; then
        APPLIED=1
    fi
fi
[ "$APPLIED" = 1 ] || infrastructure_error "tests.patch did not apply"

# Restore verifier-owned byte snapshots of the selected upstream regression
# files from BASE_COMMIT. This remains reliable when the runtime image omits or
# restricts access to the workspace's Git object database.
if ! python3 - "$WORKSPACE" <<'PY'
import base64
import hashlib
import os
from pathlib import Path
import sys

workspace = Path(sys.argv[1])
snapshots = {
    "test/Pester/Model.Tests.ps1": (
        "3ca1a6d673df5d54d819ca58c162b87a1215270c936cb0bc89ea76a861d53931",
        "IyBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4KIyBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuCgpEZXNjcmliZSAiTW9kZWwgdHlwZSB0ZXN0cyIgewogICAgQmVmb3JlQWxsIHsKICAgICAgICAkY21kSW5mbyA9IGdldC1jb21tYW5kIG5ldy1tYXJrZG93bmhlbHAKICAgICAgICAkY29tbWFuZEhlbHBUeXBlID0gJGNtZEluZm8uSW1wbGVtZW50aW5nVHlwZS5Bc3NlbWJseS5HZXRUeXBlKCJNaWNyb3NvZnQuUG93ZXJTaGVsbC5QbGF0eVBTLk1vZGVsLkNvbW1hbmRIZWxwIikgICAgIAogICAgICAgICRPYmplY3RQcm9wZXJ0aWVzID0gQCgKICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uR2xvYmFsaXphdGlvbi5DdWx0dXJlSW5mbyc7IE51bGxhYmxlID0gJGZhbHNlOyBOYW1lID0gIkxvY2FsZSIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5OdWxsYWJsZWAxW1N5c3RlbS5HdWlkXSc7IE51bGxhYmxlID0gJHRydWU7IE5hbWUgPSAiTW9kdWxlR3VpZCIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5TdHJpbmcnOyBOdWxsYWJsZSA9ICR0cnVlOyAgTmFtZSA9ICJFeHRlcm5hbEhlbHBGaWxlIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLlN0cmluZyc7IE51bGxhYmxlID0gJHRydWU7ICBOYW1lID0gIk9ubGluZVZlcnNpb25VcmwiIH0KICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uU3RyaW5nJzsgTnVsbGFibGUgPSAkdHJ1ZTsgIE5hbWUgPSAiU2NoZW1hVmVyc2lvbiIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5TdHJpbmcnOyBOdWxsYWJsZSA9ICRmYWxzZTsgTmFtZSA9ICJNb2R1bGVOYW1lIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLlN0cmluZyc7IE51bGxhYmxlID0gJGZhbHNlOyBOYW1lID0gIlRpdGxlIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLlN0cmluZyc7IE51bGxhYmxlID0gJGZhbHNlOyBOYW1lID0gIlN5bm9wc2lzIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdGAxW01pY3Jvc29mdC5Qb3dlclNoZWxsLlBsYXR5UFMuTW9kZWwuU3ludGF4SXRlbV0nOyBOdWxsYWJsZSA9ICRmYWxzZTsgTmFtZSA9ICJTeW50YXgiIH0KICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0YDFbU3lzdGVtLlN0cmluZ10nOyBOdWxsYWJsZSA9ICR0cnVlOyBOYW1lID0gIkFsaWFzZXMiIH0KICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uU3RyaW5nJzsgTnVsbGFibGUgPSAkdHJ1ZTsgTmFtZSA9ICJEZXNjcmlwdGlvbiIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3RgMVtNaWNyb3NvZnQuUG93ZXJTaGVsbC5QbGF0eVBTLk1vZGVsLkV4YW1wbGVdJzsgTnVsbGFibGUgPSAkdHJ1ZTsgTmFtZSA9ICJFeGFtcGxlcyIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3RgMVtNaWNyb3NvZnQuUG93ZXJTaGVsbC5QbGF0eVBTLk1vZGVsLlBhcmFtZXRlcl0nOyBOdWxsYWJsZSA9ICRmYWxzZTsgTmFtZSA9ICJQYXJhbWV0ZXJzIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdGAxW01pY3Jvc29mdC5Qb3dlclNoZWxsLlBsYXR5UFMuTW9kZWwuSW5wdXRPdXRwdXRdJzsgTnVsbGFibGUgPSAkdHJ1ZTsgTmFtZSA9ICJJbnB1dHMiIH0KICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0YDFbTWljcm9zb2Z0LlBvd2VyU2hlbGwuUGxhdHlQUy5Nb2RlbC5JbnB1dE91dHB1dF0nOyBOdWxsYWJsZSA9ICR0cnVlOyBOYW1lID0gIk91dHB1dHMiIH0KICAgICAgICAgICAgQHsgdHlwZSA9ICdTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5MaXN0YDFbTWljcm9zb2Z0LlBvd2VyU2hlbGwuUGxhdHlQUy5Nb2RlbC5MaW5rc10nOyBOdWxsYWJsZSA9ICR0cnVlOyBOYW1lID0gIlJlbGF0ZWRMaW5rcyIgfQogICAgICAgICAgICBAeyB0eXBlID0gJ1N5c3RlbS5Cb29sZWFuJzsgTmFtZSA9ICJIYXNDbWRsZXRCaW5kaW5nIiB9CiAgICAgICAgICAgIEB7IHR5cGUgPSAnU3lzdGVtLlN0cmluZyc7IE51bGxhYmxlID0gJHRydWU7ICBOYW1lID0gIk5vdGVzIiB9CiAgICAgICAgKQogICAgICAgICRCaW5kaW5nRmxhZ3MgPSBbU3lzdGVtLlJlZmxlY3Rpb24uQmluZGluZ0ZsYWdzXSJJbnN0YW5jZSxOb25QdWJsaWMsUHVibGljIgogICAgfQoKICAgIEl0ICJDb21tYW5kSGVscCBoYXMgdGhlIGNvcnJlY3QgdHlwZSBpbmZvcm1hdGlvbiBmb3IgJzxuYW1lPiciIC1UZXN0Q2FzZXMgJE9iamVjdFByb3BlcnRpZXMgewogICAgICAgIHBhcmFtICggJG5hbWUsICR0eXBlLCAkbnVsbGFibGUpCiAgICAgICAgJHByb3BlcnR5ID0gJGNvbW1hbmRIZWxwVHlwZS5HZXRQcm9wZXJ0eSgkbmFtZSwgJEJpbmRpbmdGbGFncykKICAgICAgICAkcHJvcGVydHkuUHJvcGVydHlUeXBlLlRvU3RyaW5nKCkgfCBTaG91bGQgLUJlRXhhY3RseSAkdHlwZQogICAgfQogICAgCiAgICAKfQo=",
    ),
    "test/Pester/Equatable.Tests.ps1": (
        "3a13a9fb39d0a127e46c0d40277f9979f5ac8c71aecea1fe6940b3c4ff2d9d9f",
        "IyBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4KIyBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuCgpEZXNjcmliZSAiVGVzdCBJRXF1YXRhYmxlIiB7CiAgICBCZWZvcmVBbGwgewogICAgICAgICRhc3NldERpciA9IEpvaW4tUGF0aCAkUFNTY3JpcHRSb290ICdhc3NldHMnCiAgICAgICAgJG1hcmtkb3duUGF0aDEgPSBKb2luLVBhdGggJGFzc2V0RGlyICdnZXQtZGF0ZS5tZCcKICAgICAgICAkbWFya2Rvd25QYXRoMiA9IEpvaW4tUGF0aCAkYXNzZXREaXIgJ091dC1OdWxsLm1kJwogICAgICAgICRDb21tYW5kSGVscE9iamVjdDEgPSBJbXBvcnQtTWFya2Rvd25Db21tYW5kSGVscCAtUGF0aCAkbWFya2Rvd25QYXRoMQogICAgICAgICRDb21tYW5kSGVscE9iamVjdDIgPSBJbXBvcnQtTWFya2Rvd25Db21tYW5kSGVscCAtUGF0aCAkbWFya2Rvd25QYXRoMQogICAgICAgICRDb21tYW5kSGVscE9iamVjdDMgPSBJbXBvcnQtTWFya2Rvd25Db21tYW5kSGVscCAtUGF0aCAkbWFya2Rvd25QYXRoMgogICAgfQoKICAgIEl0ICJTaG91bGQgYmUgZXF1YWwgdG8gaXRzZWxmIiB7CiAgICAgICAgJENvbW1hbmRIZWxwT2JqZWN0MSAtZXEgJENvbW1hbmRIZWxwT2JqZWN0MSB8IFNob3VsZCAtQmUgJHRydWUKICAgIH0KCiAgICBJdCAiU2hvdWxkIGJlIGVxdWFsIHRvIGEgZGlmZmVyZW50IGluc3RhbmNlIGdlbmVyYXRlZCBmcm9tIHRoZSBzYW1lIG9iamVjdCIgewogICAgICAgICRDb21tYW5kSGVscE9iamVjdDEgLWVxICRDb21tYW5kSGVscE9iamVjdDIgfCBTaG91bGQgLUJlICR0cnVlCiAgICB9CgogICAgSXQgIlNob3VsZCBiZSBmYWxzZSBmb3IgZGlmZmVyZW50IGZpbGVzIiB7CiAgICAgICAgJENvbW1hbmRIZWxwT2JqZWN0MiAtZXEgJENvbW1hbmRIZWxwT2JqZWN0MyB8IFNob3VsZCAtQmUgJGZhbHNlCiAgICB9CgogICAgSXQgIlNtYWxsIGNoYW5nZXMgaW4gbWFya2Rvd24gZmlsZSAnPEZpbGVOYW1lPicgc2hvdWxkIHJlc3VsdCBpbiBpbmVxdWFsaXR5IiAtVGVzdENhc2VzIEAoCiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MDEubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDAyLm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQwMy5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MDQubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDA1Lm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQwNi5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MDcubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDA4Lm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQwOS5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MTAubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDExLm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQxMi5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MTMubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDE0Lm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQxNS5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MTYubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDE3Lm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQxOC5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MTkubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDIwLm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQyMS5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICRmYWxzZSB9CiAgICAgICAgQHsgRmlsZU5hbWUgPSAiZ2V0LWRhdGUuYWx0MjIubWQiIDsgZXhwZWN0ZWRSZXN1bHQgPSAkZmFsc2UgfQogICAgICAgIEB7IEZpbGVOYW1lID0gImdldC1kYXRlLmFsdDIzLm1kIiA7IGV4cGVjdGVkUmVzdWx0ID0gJGZhbHNlIH0KICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQyNC5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICR0cnVlIH0gIyBleHRyYSBsaW5lcyBiZWZvcmUgb3IgYWZ0ZXIgaGVhZGVyIGRvZXMgbm90IGNhdXNlIGluZXF1YWxpdHkKICAgICAgICBAeyBGaWxlTmFtZSA9ICJnZXQtZGF0ZS5hbHQyNS5tZCIgOyBleHBlY3RlZFJlc3VsdCA9ICR0cnVlIH0gIyBleHRyYSB3aGl0ZXNwYWNlIGFmdGVyIGhlYWRlciB0ZXh0IGRvZXMgbm90IGNhdXNlIGluZXF1YWxpdHkKICAgICkgewogICAgICAgIHBhcmFtICgkRmlsZU5hbWUsICRleHBlY3RlZFJlc3VsdCkKICAgICAgICAkYmFkTWFya2Rvd24gPSBJbXBvcnQtTWFya2Rvd25Db21tYW5kSGVscCAtUGF0aCAoSm9pbi1QYXRoICRhc3NldERpciAkRmlsZU5hbWUpCiAgICAgICAgJENvbW1hbmRIZWxwT2JqZWN0MSAtZXEgJGJhZE1hcmtkb3duIHwgU2hvdWxkIC1CZSAkZXhwZWN0ZWRSZXN1bHQKICAgIH0KCgogICAgQ29udGV4dCAiUmVmbGVjdGlvbiBiYXNlZCB0ZXN0aW5nIGZvciBpbmRpdmlkdWFsIHByb3BlcnRpZXMgYmVjYXVzZSBDb21tYW5kSGVscCBvYmplY3QgaXMgbm90IHB1YmxpYyIgewogICAgCiAgICAgICAgSXQgIlNob3VsZCBoYXZlIHRoZSBzYW1lIFN5bm9wc2lzIiB7CiAgICAgICAgICAgICRDb21tYW5kSGVscE9iamVjdDEuU3lub3BzaXMgLWVxICRDb21tYW5kSGVscE9iamVjdDIuU3lub3BzaXMgfCBTaG91bGQgLUJlICR0cnVlCiAgICAgICAgfQoKICAgICAgICBJdCAiU2hvdWxkIGhhdmUgdGhlIHNhbWUgU3ludGF4IiB7CiAgICAgICAgICAgICRzeW50YXgxID0gJENvbW1hbmRIZWxwT2JqZWN0MS5TeW50YXgKICAgICAgICAgICAgJHN5bnRheDIgPSAkQ29tbWFuZEhlbHBPYmplY3QyLlN5bnRheAogICAgICAgICAgICAkc3ludGF4MS5Db3VudCB8IFNob3VsZCAtQmUgJHN5bnRheDIuQ291bnQKICAgICAgICAgICAgZm9yKCRpID0gMDsgJGkgLWx0ICRzeW50YXgxLkNvdW50OyAkaSsrKSB7CiAgICAgICAgICAgICAgICAkc3ludGF4MVskaV0gLWVxICRzeW50YXgyWyRpXSB8IFNob3VsZCAtQmUgJHRydWUKICAgICAgICAgICAgfQogICAgICAgIH0KCiAgICAgICAgSXQgIlNob3VsZCBoYXZlIHRoZSBzYW1lIEFsaWFzZXMiIHsKICAgICAgICAgICAgJGFsaWFzMSA9ICRDb21tYW5kSGVscE9iamVjdDEuQWxpYXNlcwogICAgICAgICAgICAkYWxpYXMyID0gJENvbW1hbmRIZWxwT2JqZWN0Mi5BbGlhc2VzCiAgICAgICAgICAgICRhbGlhczEuQ291bnQgfCBTaG91bGQgLUJlICRhbGlhczIuQ291bnQKICAgICAgICAgICAgZm9yKCRpID0gMDsgJGkgLWx0ICRhbGlhczEuQ291bnQ7ICRpKyspIHsKICAgICAgICAgICAgICAgICRhbGlhczFbJGldIC1lcSAkYWxpYXMyWyRpXSB8IFNob3VsZCAtQmUgJHRydWUKICAgICAgICAgICAgfQogICAgICAgIH0KCiAgICAgICAgSXQgIlNob3VsZCBoYXZlIHRoZSBzYW1lIERlc2NyaXB0aW9uIiB7CiAgICAgICAgICAgICRDb21tYW5kSGVscE9iamVjdDEuRGVzY3JpcHRpb24gfCBTaG91bGQgLUJlICRDb21tYW5kSGVscE9iamVjdDIuRGVzY3JpcHRpb24KICAgICAgICB9CgogICAgICAgIEl0ICJTaG91bGQgaGF2ZSB0aGUgc2FtZSBFeGFtcGxlcyIgewogICAgICAgICAgICAkZXhhbXBsZTEgPSAkQ29tbWFuZEhlbHBPYmplY3QxLkV4YW1wbGVzCiAgICAgICAgICAgICRleGFtcGxlMiA9ICRDb21tYW5kSGVscE9iamVjdDIuRXhhbXBsZXMKICAgICAgICAgICAgJGV4YW1wbGUxLkNvdW50IHwgU2hvdWxkIC1CZSAkZXhhbXBsZTIuQ291bnQKICAgICAgICAgICAgZm9yKCRpID0gMDsgJGkgLWx0ICRleGFtcGxlMS5Db3VudDsgJGkrKykgewogICAgICAgICAgICAgICAgJGV4YW1wbGUxWyRpXSAtZXEgJGV4YW1wbGUyWyRpXSB8IFNob3VsZCAtQmUgJHRydWUKICAgICAgICAgICAgfQogICAgICAgIH0KCiAgICAgICAgSXQgIlNob3VsZCBoYXZlIHRoZSBzYW1lIFBhcmFtZXRlcnMiIHsKICAgICAgICAgICAgJHBhcmFtZXRlcjEgPSAkQ29tbWFuZEhlbHBPYmplY3QxLlBhcmFtZXRlcnMKICAgICAgICAgICAgJHBhcmFtZXRlcjIgPSAkQ29tbWFuZEhlbHBPYmplY3QyLlBhcmFtZXRlcnMKICAgICAgICAgICAgJHBhcmFtZXRlcjEuQ291bnQgfCBTaG91bGQgLUJlICRwYXJhbWV0ZXIyLkNvdW50CiAgICAgICAgICAgIGZvcigkaSA9IDA7ICRpIC1sdCAkcGFyYW1ldGVyMS5Db3VudDsgJGkrKykgewogICAgICAgICAgICAgICAgJHBhcmFtZXRlcjFbJGldIC1lcSAkcGFyYW1ldGVyMlskaV0gfCBTaG91bGQgLUJlICR0cnVlCiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgIEl0ICJTaG91bGQgaGF2ZSB0aGUgc2FtZSBJbnB1dHMiIHsKICAgICAgICAgICAgJGlucHV0MSA9ICRDb21tYW5kSGVscE9iamVjdDEuSW5wdXRzCiAgICAgICAgICAgICRpbnB1dDIgPSAkQ29tbWFuZEhlbHBPYmplY3QyLklucHV0cwogICAgICAgICAgICAkaW5wdXQxLkNvdW50IHwgU2hvdWxkIC1CZSAkaW5wdXQyLkNvdW50CiAgICAgICAgICAgIGZvcigkaSA9IDA7ICRpIC1sdCAkaW5wdXQxLkNvdW50OyAkaSsrKSB7CiAgICAgICAgICAgICAgICAkaW5wdXQxWyRpXSAtZXEgJGlucHV0MlskaV0gfCBTaG91bGQgLUJlICR0cnVlCiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgIEl0ICJTaG91bGQgaGF2ZSB0aGUgc2FtZSBPdXRwdXRzIiB7CiAgICAgICAgICAgICRvdXRwdXQxID0gJENvbW1hbmRIZWxwT2JqZWN0MS5PdXRwdXRzCiAgICAgICAgICAgICRvdXRwdXQyID0gJENvbW1hbmRIZWxwT2JqZWN0Mi5PdXRwdXRzCiAgICAgICAgICAgICRvdXRwdXQxLkNvdW50IHwgU2hvdWxkIC1CZSAkb3V0cHV0Mi5Db3VudAogICAgICAgICAgICBmb3IoJGkgPSAwOyAkaSAtbHQgJG91dHB1dDEuQ291bnQ7ICRpKyspIHsKICAgICAgICAgICAgICAgICRvdXRwdXQxWyRpXSAtZXEgJG91dHB1dDJbJGldIHwgU2hvdWxkIC1CZSAkdHJ1ZQogICAgICAgICAgICB9CiAgICAgICAgfQoKICAgICAgICBJdCAiU2hvdWxkIGhhdmUgdGhlIHNhbWUgTm90ZXMiIHsKICAgICAgICAgICAgJENvbW1hbmRIZWxwT2JqZWN0MS5Ob3RlcyB8IFNob3VsZCAtQmVFeGFjdGx5ICRDb21tYW5kSGVscE9iamVjdDIuTm90ZXMKICAgICAgICB9CgogICAgICAgIEl0ICJTaG91bGQgaGF2ZSB0aGUgc2FtZSByZWxhdGVkIGxpbmtzIiB7CiAgICAgICAgICAgICRsaW5rMSA9ICRDb21tYW5kSGVscE9iamVjdDEuUmVsYXRlZExpbmtzCiAgICAgICAgICAgICRsaW5rMiA9ICRDb21tYW5kSGVscE9iamVjdDIuUmVsYXRlZExpbmtzCiAgICAgICAgICAgICRsaW5rMS5Db3VudCB8IFNob3VsZCAtQmUgJGxpbmsyLkNvdW50CiAgICAgICAgICAgIGZvcigkaSA9IDA7ICRpIC1sdCAkbGluazEuQ291bnQ7ICRpKyspIHsKICAgICAgICAgICAgICAgICRsaW5rMVskaV0gLWVxICRsaW5rMlskaV0gfCBTaG91bGQgLUJlICR0cnVlCiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgIEl0ICJBbHRlcmluZyB0aGUgZGVzY3JpcHRpb24gaW4gYSBwYXJhbWV0ZXIgd2lsbCBjYXVzZSB0aGUgb2JqZWN0cyB0byBiZSBkaWZmZXJlbnQiIHsKICAgICAgICAgICAgJHBhcmFtZXRlcjEgPSAkQ29tbWFuZEhlbHBPYmplY3QxLlBhcmFtZXRlcnMKICAgICAgICAgICAgJHBhcmFtZXRlcjIgPSAkQ29tbWFuZEhlbHBPYmplY3QyLlBhcmFtZXRlcnMKICAgICAgICAgICAgJHBhcmFtZXRlcjJbMF0uRGVzY3JpcHRpb24gPSAiTmV3IERlc2NyaXB0aW9uIgogICAgICAgICAgICAkcGFyYW1ldGVyMVswXSB8IFNob3VsZCAtTm90IC1CZSAkcGFyYW1ldGVyMlswXQogICAgICAgICAgICAkQ29tbWFuZEhlbHBPYmplY3QxIHwgU2hvdWxkIC1Ob3QgLUJlICRDb21tYW5kSGVscE9iamVjdDIKICAgICAgICB9CiAgICB9Cn0K",
    ),
    "test/Pester/ImportMarkdownCommandHelp.Tests.ps1": (
        "f46d643579c01c9646cada87566a7f00bad09f6b41b963e96a2d4a28dac4abe4",
        "IyBDb3B5cmlnaHQgKGMpIE1pY3Jvc29mdCBDb3Jwb3JhdGlvbi4KIyBMaWNlbnNlZCB1bmRlciB0aGUgTUlUIExpY2Vuc2UuCgpEZXNjcmliZSAnSW1wb3J0LU1hcmtkb3duQ29tbWFuZEhlbHAgVGVzdHMnIHsKICAgIEJlZm9yZUFsbCB7CiAgICAgICAgJGFzc2V0RGlyID0gSm9pbi1QYXRoICRQU1NjcmlwdFJvb3QgJ2Fzc2V0cycKICAgICAgICAkYmFkTWFya2Rvd25QYXRoID0gSm9pbi1QYXRoICRhc3NldERpciAnYmFkLWNvbW1hbmRoZWxwLm1kJwogICAgICAgICRnb29kTWFya2Rvd25QYXRoID0gSm9pbi1QYXRoICRhc3NldERpciAnZ2V0LWRhdGUubWQnCiAgICB9CgogICAgSXQgJ1Nob3VsZCBpbXBvcnQgYSB2YWxpZCBtYXJrZG93biBmaWxlJyB7CiAgICAgICAgJHJlc3VsdCA9IEltcG9ydC1NYXJrZG93bkNvbW1hbmRIZWxwIC1QYXRoICRnb29kTWFya2Rvd25QYXRoCiAgICAgICAgJHJlc3VsdCB8IFNob3VsZCAtTm90IC1CZU51bGxPckVtcHR5CiAgICAgICAgJHJlc3VsdC5Ub1N0cmluZygpIHwgU2hvdWxkIC1CZSAiR2V0LURhdGUiCiAgICB9CgoKICAgIEl0ICdTaG91bGQgdGhyb3cgYW4gZXJyb3IgZm9yIGFuIGludmFsaWQgbWFya2Rvd24gZmlsZScgewogICAgICAgIEltcG9ydC1NYXJrZG93bkNvbW1hbmRIZWxwIC1FcnJvclZhcmlhYmxlIEJhZE1hcmtkb3duIC1QYXRoICRiYWRNYXJrZG93blBhdGggLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgICAkYmFkTWFya2Rvd24gfCBTaG91bGQgLUJlT2ZUeXBlIFtTeXN0ZW0uTWFuYWdlbWVudC5BdXRvbWF0aW9uLkVycm9yUmVjb3JkXQogICAgICAgICRiYWRNYXJrZG93bi5GdWxseVF1YWxpZmllZEVycm9ySWQgfCBTaG91bGQgLUJlICJGYWlsZWRUb0ltcG9ydE1hcmtkb3duLE1pY3Jvc29mdC5Qb3dlclNoZWxsLlBsYXR5UFMuSW1wb3J0TWFya2Rvd25IZWxwQ29tbWFuZCIKICAgIH0KCiAgICBDb250ZXh0ICdWYWxpZGF0ZSBlbGVtZW50cyBvZiB0aGUgaW1wb3J0ZWQgY29tbWFuZGhlbHAgb2JqZWN0JyB7CiAgICAgICAgQmVmb3JlQWxsIHsKICAgICAgICAgICAgJHJlc3VsdCA9IEltcG9ydC1NYXJrZG93bkNvbW1hbmRIZWxwIC1QYXRoICRnb29kTWFya2Rvd25QYXRoCiAgICAgICAgICAgICRtZXRhZGF0YSA9ICRyZXN1bHQuR2V0VHlwZSgpLkdldFByb3BlcnR5KCdNZXRhZGF0YScsIFtTeXN0ZW0uUmVmbGVjdGlvbi5CaW5kaW5nRmxhZ3NdJ1B1YmxpYyxOb25QdWJsaWMsSW5zdGFuY2UnKS5HZXRWYWx1ZSgkcmVzdWx0LCAkbnVsbCkKICAgICAgICB9CgogICAgICAgIEl0ICdTaG91bGQgYmUgYSB2YWxpZCBDb21tYW5kSGVscCBvYmplY3QnIHsKICAgICAgICAgICAgJHJlc3VsdC5HZXRUeXBlKCkuRnVsbE5hbWUgfCBTaG91bGQgLUJlICJNaWNyb3NvZnQuUG93ZXJTaGVsbC5QbGF0eVBTLk1vZGVsLkNvbW1hbmRIZWxwIgogICAgICAgIH0KCiAgICAgICAgSXQgIlNob3VsZCBoYXZlIHRoZSBjb3JyZWN0IG1ldGFkYXRhIHZhbHVlIGZvciAnPG5hbWU+JyIgLVRlc3RDYXNlcyBAKAogICAgICAgICAgICBAeyBuYW1lID0gImV4dGVybmFsIGhlbHAgZmlsZSI7IGV4cGVjdGVkVmFsdWUgPSAiTWljcm9zb2Z0LlBvd2VyU2hlbGwuQ29tbWFuZHMuVXRpbGl0eS5kbGwtSGVscC54bWwiIH0KICAgICAgICAgICAgQHsgbmFtZSA9ICJMb2NhbGUiOyBleHBlY3RlZFZhbHVlID0gImVuLVVTIiB9CiAgICAgICAgICAgIEB7IG5hbWUgPSAiTW9kdWxlIE5hbWUiOyBleHBlY3RlZFZhbHVlID0gIk1pY3Jvc29mdC5Qb3dlclNoZWxsLlV0aWxpdHkiIH0KICAgICAgICAgICAgQHsgbmFtZSA9ICJtcy5kYXRlIjsgZXhwZWN0ZWRWYWx1ZSA9ICIxMi8xMi8yMDIyIiB9CiAgICAgICAgICAgIEB7IG5hbWUgPSAib25saW5lIHZlcnNpb24iOyBleHBlY3RlZFZhbHVlID0gImh0dHBzOi8vbGVhcm4ubWljcm9zb2Z0LmNvbS9wb3dlcnNoZWxsL21vZHVsZS9taWNyb3NvZnQucG93ZXJzaGVsbC51dGlsaXR5L2dldC1kYXRlP3ZpZXc9cG93ZXJzaGVsbC03LjQmV1QubWNfaWQ9cHMtZ2V0aGVscCIgfQogICAgICAgICAgICBAeyBuYW1lID0gInNjaGVtYSI7IGV4cGVjdGVkVmFsdWUgPSAiMi4wLjAiIH0KICAgICAgICAgICAgQHsgbmFtZSA9ICJ0aXRsZSI7IGV4cGVjdGVkVmFsdWUgPSAiR2V0LURhdGUiIH0KICAgICAgICApIHsKICAgICAgICAgICAgcGFyYW0gKCRuYW1lLCAkZXhwZWN0ZWRWYWx1ZSkKICAgICAgICAgICAgJG1ldGFkYXRhWyRuYW1lXSB8IFNob3VsZCAtQmUgJGV4cGVjdGVkVmFsdWUKCiAgICAgICAgfQogICAgfQp9Cg==",
    ),
}

for relative_path, (expected_sha256, encoded) in snapshots.items():
    data = base64.b64decode(encoded, validate=True)
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise SystemExit(f"invalid verifier snapshot for {relative_path}")
    destination = workspace / relative_path
    temporary = destination.with_name(destination.name + ".verifier-tmp")
    temporary.write_bytes(data)
    os.chmod(temporary, 0o644)
    os.replace(temporary, destination)
    if hashlib.sha256(destination.read_bytes()).hexdigest() != expected_sha256:
        raise SystemExit(f"restored snapshot differs for {relative_path}")
PY
then
    infrastructure_error "could not restore verifier-owned upstream regression tests"
fi

# This script is created only after the agent-controlled build completes. It
# emits no grading markers to stdout; it atomically writes structured records.
rm -f "$RESULTS_JSON" "$RESULTS_JSON.tmp"
RUNNER=/tmp/run-schema-migration-tests.ps1
cat > "$RUNNER" <<'PSEOF'
param(
    [Parameter(Mandatory)][string] $ResultsPath,
    [Parameter(Mandatory)][string] $ModulePath,
    [Parameter(Mandatory)][string] $Workspace
)

$ErrorActionPreference = 'Stop'
Import-Module -Max 4.99 Pester
$invokePester = Get-Command Invoke-Pester -Module Pester -ErrorAction Stop
Import-Module -Name $ModulePath -Force
$testPaths = @(
    (Join-Path $Workspace 'test/Pester/SchemaMigration.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/Model.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/Equatable.Tests.ps1')
    (Join-Path $Workspace 'test/Pester/ImportMarkdownCommandHelp.Tests.ps1')
)
$result = & $invokePester -Path $testPaths -PassThru -Show None

$records = @($result.TestResult | ForEach-Object {
    $nameParts = @($_.Describe, $_.Context, $_.Name) | Where-Object { -not [string]::IsNullOrEmpty($_) }
    [pscustomobject][ordered]@{
        name = $nameParts -join '.'
        status = [string]$_.Result
    }
})
$json = Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $records -Depth 4 -Compress
$temporaryPath = "$ResultsPath.tmp"
[System.IO.File]::WriteAllText(
    $temporaryPath,
    $json,
    [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::Move($temporaryPath, $ResultsPath, $true)

if ($result.FailedCount -gt 0 -or $result.SkippedCount -gt 0 -or $records.Count -eq 0) {
    exit 1
}
exit 0
PSEOF

set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" "$PWSH_BIN" -NoProfile -File "$RUNNER" \
        -ResultsPath "$RESULTS_JSON" \
        -ModulePath "$WORKSPACE/out/platyPS" \
        -Workspace "$WORKSPACE" \
        >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
else
    "$PWSH_BIN" -NoProfile -File "$RUNNER" \
        -ResultsPath "$RESULTS_JSON" \
        -ModulePath "$WORKSPACE/out/platyPS" \
        -Workspace "$WORKSPACE" \
        >>"$STDOUT_LOG" 2>>"$STDERR_LOG"
fi
PESTER_EXIT=$?
set -e

# Grade only the dedicated JSON artifact. Exact set equality makes missing,
# duplicate, renamed, extra, skipped, and stdout-only results fail.
set +e
python3 - "$CONFIG" "$RESULTS_JSON" "$OUTPUT" "$REPORT" "$REWARD" "$PESTER_EXIT" <<'PY'
import json
import sys

config_path, results_path, output_path, report_path, reward_path, raw_exit = sys.argv[1:]

def write(payload, report, reward):
    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    with open(report_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
    with open(reward_path, "w", encoding="utf-8") as fh:
        fh.write("1\n" if reward else "0\n")

try:
    with open(config_path, encoding="utf-8") as fh:
        config = json.load(fh)
    with open(results_path, encoding="utf-8") as fh:
        records = json.load(fh)
    if not isinstance(records, list):
        raise ValueError("Pester results must be a JSON array")

    grading = config.get("grading") or {}
    required = list(grading.get("fail_to_pass") or []) + list(grading.get("pass_to_pass") or [])
    if not required or len(required) != len(set(required)):
        raise ValueError("required test IDs are empty or duplicated")

    names = []
    normalized = []
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("name"), str):
            raise ValueError("malformed Pester test record")
        names.append(record["name"])
        normalized.append({"name": record["name"], "status": str(record.get("status", "Unknown")).upper()})

    duplicates = sorted({name for name in names if names.count(name) > 1})
    missing = sorted(set(required) - set(names))
    unexpected = sorted(set(names) - set(required))
    nonpassing = sorted(record["name"] for record in normalized if record["status"] != "PASSED")
    success = (
        int(raw_exit) == 0
        and not duplicates
        and not missing
        and not unexpected
        and not nonpassing
        and len(normalized) == len(required)
    )
    report = {
        "success": success,
        "infrastructure_error": None,
        "raw_exit_code": int(raw_exit),
        "parser_framework": "pester-json",
        "required_tests_count": len(required),
        "passed_tests_count": sum(record["status"] == "PASSED" for record in normalized),
        "missing_required_tests": missing,
        "unexpected_tests": unexpected,
        "duplicate_tests": duplicates,
        "nonpassing_tests": nonpassing,
        "reward": 1.0 if success else 0.0,
    }
    write({"tests": normalized}, report, success)
    raise SystemExit(0 if success else 1)
except (OSError, ValueError, TypeError, json.JSONDecodeError) as error:
    report = {
        "success": False,
        "infrastructure_error": f"could not validate structured Pester results: {error}",
        "raw_exit_code": int(raw_exit),
        "reward": 0.0,
    }
    write({"tests": []}, report, False)
    raise SystemExit(2)
PY
GRADE_EXIT=$?
set -e

write_zero_reward_if_missing
exit "$GRADE_EXIT"
