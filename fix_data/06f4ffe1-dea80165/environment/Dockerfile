FROM python:3.11-slim@sha256:90744cff8f32887f075c47d747a173ff333e9e98801667af93c357fa9f5e28ff

# Harbor/Terminus runtime tools (needed for terminal session recording) + git.
# Placed early so it is cached across rebuilds.
RUN apt-get update && \
    apt-get install -y --no-install-recommends asciinema git patch tmux && \
    rm -rf /var/lib/apt/lists/* && \
    command -v tmux && command -v asciinema

WORKDIR /app
COPY repo/ .

COPY frozen-requirements.txt /tmp/frozen-requirements.txt
RUN pip install --no-cache-dir -r /tmp/frozen-requirements.txt && \
    pip install --no-cache-dir --no-build-isolation -e .

CMD ["sh", "-c", "python -m pytest"]
RUN mkdir -p /installed-agent
COPY test-requirements.txt /tmp/test-requirements.txt
RUN pip install --no-cache-dir -r /tmp/test-requirements.txt
