FROM rust:1.97@sha256:b1b3c9c0d921d7fa0a6d1f9ec7e4eab87f8c8ec97644c3d791450f131dec813f

# Freeze the Debian package view used by the digest-pinned Trixie base.
RUN sed -i \
        -e 's|http://deb.debian.org/debian-security|https://snapshot.debian.org/archive/debian-security/20260803T000000Z|g' \
        -e 's|http://deb.debian.org/debian|https://snapshot.debian.org/archive/debian/20260803T000000Z|g' \
        /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends python3 nodejs node-typescript tmux asciinema \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY repo/ /app/

# Preload every locked crate while image construction still has network access.
RUN cargo fetch --locked \
    && command -v cargo \
    && command -v git \
    && command -v patch \
    && command -v python3 \
    && command -v node \
    && command -v tsc \
    && command -v tmux \
    && command -v asciinema

ENV CARGO_NET_OFFLINE=true
RUN mkdir -p /installed-agent
CMD ["cargo", "test", "--locked"]
