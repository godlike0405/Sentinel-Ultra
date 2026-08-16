FROM node:22-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436

# Harbor/Terminus runtime tools for terminal recording (cached early).
ARG DEBIAN_SNAPSHOT=20260803T000000Z
RUN sed -i \
      -e "s|http://deb.debian.org/debian-security|http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|" \
      -e "s|http://deb.debian.org/debian|http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}|" \
      /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends git tmux asciinema curl ca-certificates patch \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux && command -v asciinema

# .NET SDK to build and run the C# verification harness. Globalization is pinned
# to invariant mode so the runtime needs no ICU package on this slim base, and
# only ordinal string comparisons are used anyway.
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH=/usr/share/dotnet:$PATH
ARG DOTNET_SDK_VERSION=8.0.423
ARG DOTNET_SDK_SHA512=e94513dfe42271a85f01e87bd4272aa80b4ec13556f4531754802542225667775242c5e281a94837dae6cc65f7bcc457d2f663f240c0e2b7573fd909e786b1a5
RUN curl -fsSL "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" -o /tmp/dotnet-sdk.tar.gz \
    && echo "${DOTNET_SDK_SHA512}  /tmp/dotnet-sdk.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && rm -f /tmp/dotnet-sdk.tar.gz \
    && test "$(dotnet --version)" = "${DOTNET_SDK_VERSION}"

WORKDIR /app
COPY repo/ .

CMD ["sh", "-c", "npm test"]
RUN mkdir -p /installed-agent
