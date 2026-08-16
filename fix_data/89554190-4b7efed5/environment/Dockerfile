FROM node:22-bookworm

# ---------------------------------------------------------------------------
# Harbor/Terminus runtime tools + git + a virtual display for Electron tests.
# Placed early so this layer is cached across rebuilds.
#   - git: required by package.json "postinstall" (`git clean ...`)
#   - tmux + asciinema: required by the agent harness to record sessions
#   - xvfb + dbus-x11: provide an X11 display so the Electron test suite can
#     launch real windows fully offline (no Wayland compositor needed)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        ripgrep \
        tmux \
        asciinema \
        xvfb \
        xauth \
        dbus-x11 \
        ca-certificates \
        libgtk-3-0 \
        libnotify4 \
        libnss3 \
        libxss1 \
        libxtst6 \
        libatspi2.0-0 \
        libdrm2 \
        libgbm1 \
        libasound2 \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux \
    && command -v asciinema

# Preinstall Codex and its setup dependencies in the image so Harbor does not
# spend the agent setup window downloading them for every trial.
RUN npm install -g @openai/codex@latest \
    && codex --version

# Preinstall Claude Code so Harbor does not need to download it during the
# timed agent setup phase.
RUN curl -fsSL https://downloads.claude.ai/claude-code-releases/bootstrap.sh \
    | bash -s --
ENV PATH="/root/.local/bin:${PATH}"
RUN claude --version

WORKDIR /app
COPY repo/ .

# The pinned base commit contains a platform-stripped lock entry for optional
# Electron. Rehydrate that one entry at its declared minimum version before the
# clean install, then restore the tracked manifests so the agent starts from a
# clean base checkout. Dependencies are installed at build time for offline use.
RUN npm pkg set optionalDependencies.electron=42.2.0 \
    && npm install --package-lock-only --ignore-scripts \
    && npm ci \
    && git restore package.json package-lock.json

# Install the Playwright Chromium browser AND its system dependencies (libnss3,
# libasound2, gtk, etc. — which Electron also needs) at build time, so the e2e
# and electron suites can run with --network=none.
RUN npx playwright install --with-deps chromium

# Electron, when run as root, needs the chrome-sandbox helper to be setuid-root
# (mirrors the project's CI setup). Make it robust if the path is absent.
RUN if [ -f ./node_modules/electron/dist/chrome-sandbox ]; then \
        chown root:root ./node_modules/electron/dist/chrome-sandbox && \
        chmod 4755 ./node_modules/electron/dist/chrome-sandbox; \
    fi

# The e2e helper reads/writes config/custom.css (CI does `touch config/custom.css`).
RUN touch config/custom.css

# Run the full test suite under a virtual X display so Electron windows can open
# offline. WAYLAND_DISPLAY is intentionally unset so Electron uses the X11 server
# provided by xvfb-run.
CMD ["sh", "-c", "xvfb-run -a --server-args='-screen 0 1280x1024x24' npm test"]
RUN mkdir -p /installed-agent
RUN command -v patch >/dev/null 2>&1 || ( (apt-get update && apt-get install -y --no-install-recommends patch && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache patch 2>/dev/null || yum install -y patch 2>/dev/null || true )
