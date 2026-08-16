#!/usr/bin/env bash
set -e
cd /app
git apply -p1 --check --whitespace=nowarn /solution/golden.patch
git apply -p1 --whitespace=nowarn /solution/golden.patch
