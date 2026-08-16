FROM devkitpro/devkitppc:20220821
ENV DEBIAN_FRONTEND=noninteractive

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
            