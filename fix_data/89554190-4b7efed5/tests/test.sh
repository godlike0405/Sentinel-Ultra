#!/usr/bin/env bash
# Harbor verifier safety net — fires on ANY exit (including set -e).
# Each writer only fires if its artifact is absent (never overwrites richer logic).
_dflt_reward() { if [ ! -f /logs/verifier/reward.txt ]; then if [ "$1" -eq 0 ]; then echo 1 > /logs/verifier/reward.txt; else echo 0 > /logs/verifier/reward.txt; fi; fi; }
_dflt_test_results() { if [ ! -f /logs/verifier/test_results.json ]; then local r=0; [ -f /logs/verifier/reward.txt ] && r=$(cat /logs/verifier/reward.txt 2>/dev/null || echo 0); if [ "$r" = "1" ]; then s=passed; else s=failed; fi; printf '{"tests": [{"name": "suite", "status": "%s"}], "reward": %s}\n' "$s" "$r" > /logs/verifier/test_results.json; fi; }
_dflt_verifier_exit() { local rc=$?; mkdir -p /logs/verifier; _dflt_reward "$rc"; _dflt_test_results; }
trap _dflt_verifier_exit EXIT
set -e
cd /app
mkdir -p /logs/verifier

# Inject the canonical fail-to-pass Buienradar spec. Agents commonly write their own
# companion spec at this path (every other provider ships one), so force the official
# spec to win: discard any file the agent left at that path, then apply. `git apply`
# does not need repo discovery.
git config --global --add safe.directory /app 2>/dev/null || true
rm -f tests/unit/modules/default/weather/providers/buienradar_spec.js
git apply --whitespace=nowarn /tests/tests.patch

# NO installs here — the container has no network (allow_internet=false).
# vitest and msw are installed at docker build time via `npm ci`.

set +e

# Run the Buienradar fail-to-pass suite and an existing-provider regression suite,
# emitting one JSON report for grading.
./node_modules/.bin/vitest run \
  tests/unit/modules/default/weather/providers/buienradar_spec.js \
  tests/unit/modules/default/weather/providers/openmeteo_spec.js \
  --project unit \
  --reporter=json \
  --outputFile=/logs/verifier/vitest-results.json
VITEST_EXIT=$?

# Grade from the JSON report (authoritative: every fail_to_pass test must pass).
python3 /tests/grade.py /logs/verifier/vitest-results.json > /logs/verifier/reward.txt 2>/logs/verifier/grade.log

# Fallback to the raw vitest exit code if grading produced nothing usable.
if [ ! -s /logs/verifier/reward.txt ]; then
  if [ "$VITEST_EXIT" -eq 0 ]; then echo 1 > /logs/verifier/reward.txt; else echo 0 > /logs/verifier/reward.txt; fi
fi

REWARD=$(cat /logs/verifier/reward.txt 2>/dev/null || echo 0)
case "$REWARD" in
  1|1.0) exit 0 ;;
  *) exit 1 ;;
esac
