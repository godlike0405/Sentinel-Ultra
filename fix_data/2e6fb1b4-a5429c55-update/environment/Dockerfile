FROM golang:1.26
RUN apt-get update && apt-get install -y --no-install-recommends git tmux asciinema && rm -rf /var/lib/apt/lists/*
RUN command -v tmux && command -v asciinema
WORKDIR /app
COPY repo/ .
RUN n=0; until go mod download; do n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; echo "dependency install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); done
CMD ["sh", "-c", "go test ./..."]
# The evaluation tests for this task are JavaScript (node:test). Install a
# Node.js runtime plus the c8 coverage tool at build time so the verifier can
# run them and emit a Cobertura coverage report with no network at runtime.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
RUN npm install -g c8@10
RUN node --version && c8 --version
RUN mkdir -p /installed-agent
RUN command -v patch >/dev/null 2>&1 || ( (apt-get update && apt-get install -y --no-install-recommends patch && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache patch 2>/dev/null || yum install -y patch 2>/dev/null || true )
