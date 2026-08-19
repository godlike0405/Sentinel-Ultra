FROM devkitpro/devkitppc:20220821
ENV DEBIAN_FRONTEND=noninteractive

# Harbor installs each coding agent's system prerequisites after the task image
# is built. Keep that runtime apt transaction usable even though Buster's live
# mirrors have been retired, while retaining the base image's devkitPro source.
RUN printf '%s\n' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20220821T000000Z buster main' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20220821T000000Z buster/updates main' \
      > /etc/apt/sources.list && \
    printf '%s\n' \
      'Acquire::Check-Valid-Until "false";' \
      'Acquire::Retries "3";' \
      > /etc/apt/apt.conf.d/99sentinel-snapshot && \
    rm -f /etc/apt/sources.list.d/buster-backports.list

# Keep the devkitPPC/newlib ABI contemporary with this 2022 source tree. Its
# Debian Buster package repositories are retired, so verifier dependencies are
# bundled with the task instead of being resolved from the network at build time.
COPY debs/ /tmp/sentinel-debs/
RUN cd /tmp/sentinel-debs && \
    sha256sum -c SHA256SUMS && \
    dpkg --unpack ./*.deb && \
    dpkg --configure -a && \
    cd / && rm -rf /tmp/sentinel-debs && \
    command -v tmux && command -v asciinema && \
    command -v gcc && command -v git && command -v patch && \
    python3 -c "import pytest"

WORKDIR /app
COPY repo/ .

CMD ["sh", "-c", "python3 -m pytest -v tests"]
RUN mkdir -p /installed-agent
            
