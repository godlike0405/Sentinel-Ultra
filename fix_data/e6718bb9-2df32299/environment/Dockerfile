FROM golang:1.25.7@sha256:5a79b94c34c299ac0361fbb7c7fca6dc552e166b42341050323fa3ab137d7be9

ENV GOTOOLCHAIN=local \
    GOPROXY=https://proxy.golang.org

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        asciinema \
        ca-certificates \
        git \
        patch \
        tmux \
    && rm -rf /var/lib/apt/lists/* \
    && command -v asciinema \
    && command -v patch \
    && command -v tmux

WORKDIR /app
COPY repo/ .

# The upstream repository tracks a VS Code workspace file. It is excluded from
# the image context; preserve a clean pinned checkout for the coding agent.
RUN git update-index --skip-worktree sif.code-workspace \
    && test -z "$(git status --porcelain)"

# Keep a slow or broken module connection from consuming the entire image-build
# budget. Successful downloads are retained in the module cache across retries.
RUN set -eu; \
    attempt=1; \
    while ! timeout --signal=TERM --kill-after=10s 300s go mod download; do \
        if [ "$attempt" -ge 3 ]; then \
            echo "dependency install failed after $attempt attempts" >&2; \
            exit 1; \
        fi; \
        echo "dependency install failed (attempt $attempt/3), retrying…" >&2; \
        sleep $((attempt * 10)); \
        attempt=$((attempt + 1)); \
    done

# Module sources are now available offline. Leave compilation to the agent and
# verifier, and keep their large Go/C temporary files on the image filesystem
# rather than a potentially small host-provided /tmp mount.
RUN mkdir -p /go/tmp /installed-agent
ENV GOTMPDIR=/go/tmp \
    TMPDIR=/go/tmp

CMD ["sh", "-c", "go test ./..."]
