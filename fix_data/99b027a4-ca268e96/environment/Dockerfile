FROM golang:1.26.2@sha256:b54cbf583d390341599d7bcbc062425c081105cc5ef6d170ced98ef9d047c716

ENV GOTOOLCHAIN=local

# Freeze Debian package resolution to a snapshot contemporaneous with the
# digest-pinned base image.
RUN set -eux; \
    for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do \
      if [ -f "$source_file" ]; then \
        sed -i \
          -e 's|https\?://deb.debian.org/debian-security|https://snapshot.debian.org/archive/debian-security/20260422T000000Z|g' \
          -e 's|https\?://deb.debian.org/debian|https://snapshot.debian.org/archive/debian/20260422T000000Z|g' \
          "$source_file"; \
      fi; \
    done; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99snapshot; \
    apt-get update; \
    apt-get install -y --no-install-recommends asciinema patch python3 tmux; \
    rm -rf /var/lib/apt/lists/*; \
    command -v asciinema; \
    command -v patch; \
    command -v python3; \
    command -v tmux

# The shell tooling under test runs commands via /bin/sh -lc. Preserve PATH
# entries prepended by callers and verifier-owned fixtures.
RUN sed -i \
      -e 's#PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"#PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"#' \
      -e 's#PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"#PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games${PATH:+:$PATH}"#' \
      /etc/profile

WORKDIR /app
COPY repo/ .
RUN go mod download

RUN mkdir -p /installed-agent
CMD ["bash"]
