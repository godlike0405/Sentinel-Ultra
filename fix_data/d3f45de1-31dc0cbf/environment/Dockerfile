FROM node:22-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436
RUN command -v git >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*)
WORKDIR /app
COPY repo/ .
RUN n=0; until npm ci; do n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; echo "dependency install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); done
# The oracle adds this browser runtime to the workspace manifest after the image
# is built. Preinstall the exact package without changing the pristine checkout
# so solved-task verification remains fully offline.
RUN mkdir -p /opt/onnxruntime-web && n=0; until npm install --prefix /opt/onnxruntime-web --no-save --package-lock=false onnxruntime-web@1.27.0; do n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; echo "browser runtime install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); done; ln -s /opt/onnxruntime-web/node_modules/onnxruntime-web /app/node_modules/onnxruntime-web
# Coverage tool for the verifier's oracle coverage report (Cobertura XML). No
# network at test runtime, so install it during the build.
RUN n=0; until npm install -g c8@10; do n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; echo "c8 install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); done
CMD ["sh", "-c", "npm test"]
RUN mkdir -p /installed-agent
RUN command -v patch >/dev/null 2>&1 || ( (apt-get update && apt-get install -y --no-install-recommends patch && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache patch 2>/dev/null || yum install -y patch 2>/dev/null || true )
RUN (command -v tmux >/dev/null 2>&1 && command -v asciinema >/dev/null 2>&1) || ( (apt-get update && apt-get install -y --no-install-recommends tmux asciinema && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache tmux asciinema 2>/dev/null || dnf install -y tmux asciinema 2>/dev/null || yum install -y tmux asciinema 2>/dev/null || true )
