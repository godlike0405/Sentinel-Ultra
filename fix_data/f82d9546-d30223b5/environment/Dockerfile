FROM node:22.23.2-bookworm-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436 AS node-deps

WORKDIR /build/dashboard
COPY repo/dashboard/package.json repo/dashboard/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

WORKDIR /build/node-harness
COPY node-harness/package.json node-harness/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

FROM python:3.13.14-slim-bookworm@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8 AS python-deps

COPY frozen-requirements.txt /tmp/frozen-requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/frozen-requirements.txt \
    && python -m pytest --version

FROM swift:6.2.3-noble@sha256:6dd90eb2359663a2cde8f03e9951f488b23134b3b8fce20e9dcb6cada75dd803

RUN rm -f /etc/apt/sources.list.d/ubuntu.sources \
    && printf '%s\n' \
      'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260801T000000Z noble main universe' \
      'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260801T000000Z noble-updates main universe' \
      'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260801T000000Z noble-security main universe' \
      > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        asciinema \
        ca-certificates \
        git \
        libbz2-1.0 \
        libexpat1 \
        libffi8 \
        liblzma5 \
        libsqlite3-0 \
        libssl3t64 \
        libuuid1 \
        patch \
        tmux \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && command -v git \
    && command -v patch \
    && command -v tmux \
    && command -v asciinema

COPY --from=python-deps /usr/local /usr/local

WORKDIR /app
COPY repo/ .
COPY --from=node-deps /usr/local/bin/node /usr/local/bin/node
COPY --from=node-deps /build/dashboard/node_modules /app/dashboard/node_modules
COPY --from=node-deps /build/node-harness /opt/sentinel-node-harness

ENV PYTHONPATH=/app/src
ENV EXO_DASHBOARD_DIR=/app/dashboard
ENV SENTINEL_NODE_HARNESS=/opt/sentinel-node-harness

RUN python --version \
    && python -m pytest --version \
    && node --version \
    && swiftc --version \
    && test -d /app/dashboard/node_modules/vite \
    && test -d /opt/sentinel-node-harness/node_modules/happy-dom \
    && mkdir -p /installed-agent

CMD ["python", "-m", "pytest", "src/exo/shared/tests/test_state_serialization.py"]
