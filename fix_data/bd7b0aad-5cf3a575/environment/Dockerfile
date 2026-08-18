FROM python:3.11-slim@sha256:9c900dea9e8fb7e16277c179b555cc72d29a352dbc33cff48ad5a0412fd5bfc7

# Runtime tools required by the Harbor/Terminus harness for session recording.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git tmux asciinema patch \
    && rm -rf /var/lib/apt/lists/* \
    && command -v git && command -v tmux && command -v asciinema && command -v patch

WORKDIR /app
COPY repo/ .

COPY frozen-requirements.txt /tmp/frozen-requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/frozen-requirements.txt

# The lock file already contains the project and verifier dependencies. Avoid a
# second dependency-resolution pass while installing the local checkout.
RUN python -m pip install --no-cache-dir --no-deps --no-build-isolation -e .

RUN mkdir -p /installed-agent

CMD ["sh", "-c", "python -m pytest"]
