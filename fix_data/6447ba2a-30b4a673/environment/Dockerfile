# ---- build stage: restore + build the whole solution (incl. test projects) ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app
COPY repo/ .
# Restore + build in a single layer; retry restore for transient network hiccups.
# NuGetAudit is disabled: the modern SDK flags the repo's pinned 2018-era packages
# (NU1903) and the project builds with TreatWarningsAsErrors, so the audit would
# otherwise break the build. It also needs network the airgapped test run lacks.
RUN n=0; until dotnet restore -p:NuGetAudit=false; do n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; echo "dependency install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); done \
    && dotnet build --no-restore -p:NuGetAudit=false

# ---- final stage: flattened image that runs the tests fully offline ----
FROM mcr.microsoft.com/dotnet/sdk:10.0
# Harbor/Terminus runtime tools + git (early so they cache across rebuilds)
RUN apt-get update \
    && apt-get install -y --no-install-recommends git tmux asciinema \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux && command -v asciinema
WORKDIR /app
# Bring across the built solution and the warmed NuGet cache so `dotnet test`
# (and `dotnet test --list-tests`) work with no network access.
COPY --from=build /app /app
COPY --from=build /root/.nuget /root/.nuget
CMD ["sh", "-c", "dotnet test -p:NuGetAudit=false"]
COPY repo/ /app
RUN mkdir -p /installed-agent
RUN command -v patch >/dev/null 2>&1 || ( (apt-get update && apt-get install -y --no-install-recommends patch && rm -rf /var/lib/apt/lists/*) 2>/dev/null || apk add --no-cache patch 2>/dev/null || yum install -y patch 2>/dev/null || true )
