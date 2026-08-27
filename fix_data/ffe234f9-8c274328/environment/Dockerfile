FROM maven:3.9-eclipse-temurin-21@sha256:c07f7ccfb8ca6c9fa29ee523f00afa7d2ca6132c92f8652c4aebb5ee3491f502

# Harbor/Terminus runtime tools for session recording (installed early for caching)
RUN apt-get update && \
    apt-get install -y --no-install-recommends asciinema git patch tmux && \
    rm -rf /var/lib/apt/lists/* && \
    command -v tmux && command -v asciinema && command -v git

WORKDIR /app
COPY repo/ .

# Warm the local Maven repository so `mvn test` works fully offline (--network=none).
# Running the actual test lifecycle here resolves every plugin (enforcer, rat,
# build-plan, surefire, etc.) and every test dependency into ~/.m2, which
# `dependency:go-offline` alone does not reliably do. No output masking so any
# resolution failure fails the build instead of being hidden.
RUN mvn -B test
RUN find target -depth -delete

RUN mkdir -p /installed-agent
