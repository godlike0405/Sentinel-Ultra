FROM node:22.23.2-bookworm-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436 AS dashboard-deps

WORKDIR /build/dashboard
COPY repo/dashboard/package.json repo/dashboard/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund

FROM python:3.13.14-slim-bookworm@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8

RUN rm -f /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260801T000000Z bookworm main' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260801T000000Z bookworm-updates main' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20260801T000000Z bookworm-security main' \
      > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        asciinema \
        ca-certificates \
        git \
        patch \
        tmux \
    && rm -rf /var/lib/apt/lists/* \
    && command -v git \
    && command -v patch \
    && command -v tmux \
    && command -v asciinema

COPY frozen-requirements.txt /tmp/frozen-requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/frozen-requirements.txt \
    && python -m pytest --version

WORKDIR /app
COPY repo/ .
COPY --from=dashboard-deps /usr/local/bin/node /usr/local/bin/node
COPY --from=dashboard-deps /build/dashboard/node_modules /app/dashboard/node_modules

ENV PYTHONPATH=/app/src
ENV EXO_DASHBOARD_DIR=/app/dashboard

RUN node --version \
    && test -d /app/dashboard/node_modules/vite \
    && mkdir -p /installed-agent

CMD ["python", "-m", "pytest", "src/exo/shared/tests/test_state_serialization.py"]
