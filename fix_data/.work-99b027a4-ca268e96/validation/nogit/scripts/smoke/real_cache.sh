#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY is required}"
echo "[smoke/real_cache] RUN_REAL_SMOKE=1 go test ./internal/agent -run TestRealDeepSeekCacheMetricsSmoke -v"
RUN_REAL_SMOKE=1 go test ./internal/agent -run TestRealDeepSeekCacheMetricsSmoke -v
