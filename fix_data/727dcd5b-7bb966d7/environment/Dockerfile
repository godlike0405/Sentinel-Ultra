FROM ubuntu:24.04@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      asciinema \
      build-essential \
      ca-certificates \
      cmake \
      git \
      libgmp-dev \
      libmpfr-dev \
      libssl-dev \
      patch \
      python3 \
      tmux \
    && rm -rf /var/lib/apt/lists/* \
    && command -v asciinema \
    && command -v cmake \
    && command -v python3 \
    && command -v tmux

WORKDIR /app
COPY repo/ .
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local 2>&1 | tee /tmp/cmake_configure.log \
    && test -f build/Makefile
CMD ["sh", "-c", "cmake --build build && ctest --test-dir build --output-on-failure"]
RUN mkdir -p /installed-agent
