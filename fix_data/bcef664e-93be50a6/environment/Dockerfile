# Keep the legacy toolchain in a digest-pinned image stage. Copying it from a
# base image avoids a separate build-time download from dl.google.com, which
# is not guaranteed to be reachable from the image builder.
FROM golang:1.13.15-buster@sha256:66a3f6817c129f48c9cc9b96816a1c0b6dcb399393196e3581d9367b55ab29f2 AS go-toolchain

FROM ubuntu:24.04@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea
ENV DEBIAN_FRONTEND=noninteractive

# Resolve the pinned package versions from an immutable Ubuntu snapshot rather
# than from rolling archive/security mirrors.
RUN sed -ri 's#http://(archive|security)\.ubuntu\.com/ubuntu/#http://snapshot.ubuntu.com/ubuntu/20260801T000000Z/#g' \
        /etc/apt/sources.list.d/ubuntu.sources \
    && printf '%s\n' 'Acquire::Check-Valid-Until "false";' \
        > /etc/apt/apt.conf.d/99snapshot \
    && printf '%s\n' 'Acquire::https::Verify-Peer "false";' \
        > /etc/apt/apt.conf.d/98snapshot-bootstrap

# The minimal Ubuntu rootfs has no trust store. Bootstrap only the pinned CA
# bundle with repository-signature verification, then require normal TLS for
# every remaining package and download.
RUN apt-get -o Acquire::Retries=5 update \
    && apt-get install -y --no-install-recommends ca-certificates=20260601~24.04.1 \
    && rm /etc/apt/apt.conf.d/98snapshot-bootstrap \
    && rm -rf /var/lib/apt/lists/*

# --- Harbor/Terminus runtime tools + build/system dependencies ---
# tmux & asciinema are required by the agent harness for session recording.
# Placed early so the layer is cached across rebuilds.
RUN apt-get -o Acquire::Retries=5 update && apt-get install -y --no-install-recommends \
        tmux=3.4-1ubuntu0.1 \
        asciinema=2.4.0-1 \
        curl=8.5.0-2ubuntu10.11 \
        wget=1.21.4-1ubuntu4.4 \
        git=1:2.43.0-1ubuntu7.3 \
        make=4.3-4.1build2 \
        gcc=4:13.2.0-7ubuntu1 \
        g++=4:13.2.0-7ubuntu1 \
        libc6-dev=2.39-0ubuntu8.8 \
        pkg-config=1.8.1-2build1 \
        bash=5.2.21-2ubuntu4 \
        patch=2.7.6-7build3 \
        python3=3.12.3-0ubuntu2.1 \
        rsync=3.2.7-1ubuntu1.5 \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux && command -v asciinema

# --- Go toolchain (pinned) ---
# PouchContainer uses classic GOPATH-style vendoring (vendor/ + vendor.json, no
# go.mod). Its .travis.yml pins Go 1.12.6, but the source uses fmt error-wrapping
# (`%w`, added in Go 1.13), which `go test`'s built-in vet rejects under 1.12.
# Go 1.13.15 is the minimal toolchain that compiles the sources unchanged; it
# still honors GOPATH/vendor mode when GO111MODULE=off (set below).
COPY --from=go-toolchain /usr/local/go /usr/local/go

# GOPATH layout. GO111MODULE=off keeps the build in classic GOPATH/vendor mode.
ENV GOPATH=/go
ENV GO111MODULE=off
ENV PATH=/go/bin:/usr/local/go/bin:$PATH
RUN mkdir -p /go/bin /go/src/github.com/alibaba
RUN /usr/local/go/bin/go version

# Place the source at its canonical import path so vendor resolution works.
COPY repo/ /go/src/github.com/alibaba/pouch
# The verifier and oracle resolve the workspace from /app|/testbed|/workspace.
# Expose the GOPATH source tree there via a symlink; `go test ./...` follows it
# back into GOPATH (EvalSymlinks) so import paths still resolve in vendor mode.
RUN ln -s /go/src/github.com/alibaba/pouch /app
WORKDIR /go/src/github.com/alibaba/pouch

CMD ["sh", "-c", "make test"]
RUN mkdir -p /installed-agent
