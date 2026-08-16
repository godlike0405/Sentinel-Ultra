#!/usr/bin/env bash
set -e
cd /app
patch -p1 < /solution/golden.patch
