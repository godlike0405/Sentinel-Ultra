FROM golang:1.26-alpine3.23@sha256:e57c41c1d5864341031181b0db34b9a537bb5773eb6428e4e5bdaea0f9135406 AS go-toolchain

FROM node:20.19.5-bookworm-slim@sha256:9e70124bd00f47dd023e349cd587132ae61892acc0e47ed641416c3e18f401c3

COPY --from=go-toolchain /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOTOOLCHAIN=local

# Freeze Debian package resolution to an immutable snapshot. The final image
# contains every runtime/build dependency needed by the air-gapped verifier.
RUN rm -f /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
      'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260801T000000Z bookworm main' \
      'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260801T000000Z bookworm-updates main' \
      'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20260801T000000Z bookworm-security main' \
      > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends asciinema ca-certificates chromium git patch python3 tmux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY repo/ .

RUN n=0; until go mod download; do \
      n=$((n+1)); \
      if [ "$n" -ge 3 ]; then exit 1; fi; \
      echo "Go dependency install failed (attempt $n/3), retrying" >&2; \
      sleep $((n * 10)); \
    done \
    && go build -buildvcs=false -o /tmp/crit-build-warm ./cmd/crit \
    && find /tmp/crit-build-warm -maxdepth 0 -type f -delete

# Preload the exact lockfile-selected frontend packages. Agents can regenerate
# the vendored browser bundles without network access, while pristine copies
# remain available for verifier-owned byte-parity checks.
RUN n=0; until npm ci --ignore-scripts --no-audit --no-fund; do \
      n=$((n+1)); \
      if [ "$n" -ge 3 ]; then exit 1; fi; \
      echo "Node dependency install failed (attempt $n/3), retrying" >&2; \
      sleep $((n * 10)); \
    done \
    && install -Dm0644 node_modules/markdown-it/dist/markdown-it.min.js /opt/crit-deps/markdown-it.min.js \
    && install -Dm0644 node_modules/mermaid/dist/mermaid.min.js /opt/crit-deps/mermaid.min.js \
    && printf '%s  %s\n' \
      '70fe17bd06c7fa819f03a1ed10957904318103624198845dc893b309bf495e28' '/opt/crit-deps/markdown-it.min.js' \
      '74d7c46dabca328c2294733910a8aa1ed0c37451776e8d5295da38a2b758fb9b' '/opt/crit-deps/mermaid.min.js' \
      | sha256sum -c -

# Install the lockfile-pinned browser test runner. Chromium comes from the
# immutable distribution snapshot above, avoiding a second dependency install
# and an architecture-specific browser CDN during the image build.
RUN cd test/e2e \
    && n=0 \
    && until npm ci --ignore-scripts --no-audit --no-fund; do \
      n=$((n+1)); \
      if [ "$n" -ge 3 ]; then exit 1; fi; \
      echo "Browser dependency install failed (attempt $n/3), retrying" >&2; \
      sleep $((n * 10)); \
    done \
    && mkdir -p /opt/crit-e2e \
    && cp -a node_modules /opt/crit-e2e/node_modules \
    && test -f /opt/crit-e2e/node_modules/@playwright/test/cli.js

ENV GOPROXY=off
ENV SENTINEL_CHROMIUM_PATH=/usr/bin/chromium
RUN command -v go && command -v node && command -v git \
    && command -v patch && command -v python3 && command -v tmux && command -v asciinema \
    && test -x "$SENTINEL_CHROMIUM_PATH" \
    && "$SENTINEL_CHROMIUM_PATH" --version

CMD ["sh", "-c", "go test ./..."]
