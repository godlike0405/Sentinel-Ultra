#!/usr/bin/env bash
set -euo pipefail

readonly RESULTS_DIR=/logs/verifier
readonly TEST_PROJECT=test/WebJobs.Script.Tests/WebJobs.Script.Tests.csproj
readonly TEST_FILE=test/WebJobs.Script.Tests/WaitForBlobAndGetStringAsyncTests.cs
readonly TRX_FILE="$RESULTS_DIR/sentinel-results.trx"
readonly RAW_EXIT_FILE="$RESULTS_DIR/raw_test_exit_code.txt"

mkdir -p "$RESULTS_DIR"

fail_closed() {
  local status=$?
  if [ ! -f "$RESULTS_DIR/reward.txt" ]; then
    printf '0\n' > "$RESULTS_DIR/reward.txt"
  fi
  if [ ! -f "$RESULTS_DIR/test_results.json" ]; then
    printf '%s\n' '{"reason":"verifier setup or execution failed before grading","reward":0,"tests":[]}' > "$RESULTS_DIR/test_results.json"
  fi
  exit "$status"
}

trap fail_closed ERR

cd /app

# Fail closed if the submitted implementation does not build before verifier-owned
# tests are materialized. Remove stale artifacts that could forge a later result.
rm -f "$TRX_FILE" "$RAW_EXIT_FILE" "$RESULTS_DIR/test_results.json" "$RESULTS_DIR/reward.txt"
dotnet build "$TEST_PROJECT" --no-restore --nologo

# Recreate the verifier-owned test path and apply the exact patch. A solver-created
# collision must not suppress or alter the tests.
rm -f "$TRX_FILE" "$RAW_EXIT_FILE" "$RESULTS_DIR/test_results.json" "$RESULTS_DIR/reward.txt"
rm -f "$TEST_FILE"
git apply --check /tests/tests.patch
git apply /tests/tests.patch

set +e
dotnet test "$TEST_PROJECT" \
  --no-restore \
  --filter "FullyQualifiedName~Microsoft.Azure.WebJobs.Script.Tests.TestHelpersTests.WaitForBlobAndGetStringAsyncTests|FullyQualifiedName=Microsoft.Azure.WebJobs.Script.Tests.UtilityTests.RemoveUTF8ByteOrderMark_RemovesBOM|FullyQualifiedName=Microsoft.Azure.WebJobs.Script.Tests.UtilityTests.RemoveUTF8ByteOrderMark_WithNoBOM_ReturnsOriginalString" \
  --logger "trx;LogFileName=$(basename "$TRX_FILE")" \
  --results-directory "$RESULTS_DIR" \
  --nologo
EXIT_CODE=$?
set -e

printf '%s\n' "$EXIT_CODE" > "$RAW_EXIT_FILE"

python3 /tests/grade.py
