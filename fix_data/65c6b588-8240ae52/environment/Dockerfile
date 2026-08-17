# Pinned by immutable digest as well as a readable tag: the `3.11-slim` tag is
# mutable and re-pointed on every upstream patch release, so the tag alone is
# not reproducible pinning.
FROM python:3.11-slim@sha256:a630a63cdb314e2d138a2fca3e375e319e8568346ffafac5b980f888630ac4f1

# Harbor/Terminus runtime tools + git (early so it is cached across rebuilds)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        procps \
        tmux \
        asciinema \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux && command -v asciinema

WORKDIR /app

# Build backend for the project (hatchling), installed explicitly so the
# editable install works on a fresh builder without build-isolation surprises.
RUN pip install --no-cache-dir hatchling

COPY repo/ .

COPY frozen-requirements.txt /tmp/frozen-requirements.txt
RUN pip install --no-cache-dir -r /tmp/frozen-requirements.txt
# Install the project plus its dev/test extra. The test dependencies
# (pytest, pytest-cov, anyio[trio]) live in the [dev] optional-dependencies
# group of pyproject.toml, so that extra must be installed for the offline
# test run and the coverage-based oracle build.
RUN pip install --no-cache-dir -e ".[dev]"

RUN mkdir -p /installed-agent
RUN command -v patch >/dev/null 2>&1 || ( (apt-get update && apt-get install -y --no-install-recommends patch && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache patch 2>/dev/null || yum install -y patch 2>/dev/null || true )
COPY test-requirements.txt /tmp/test-requirements.txt
RUN pip install --no-cache-dir -r /tmp/test-requirements.txt
