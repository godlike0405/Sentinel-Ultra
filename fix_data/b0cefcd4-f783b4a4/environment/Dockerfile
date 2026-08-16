FROM mcr.microsoft.com/dotnet/sdk:10.0.302

# Harbor/Terminus runtime tools (tmux + asciinema) and git.
# Placed early so the layer is cached across rebuilds.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git tmux asciinema patch curl \
    && rm -rf /var/lib/apt/lists/* \
    && command -v tmux && command -v asciinema

# Disable .NET diagnostics so the build does not leave named pipes
# (/tmp/clr-debug-pipe-*) in the image layer. The host/Daytona storage
# drivers (vfs) cannot recreate FIFO special files, which otherwise makes
# `docker run` fail with "Error response from daemon: invalid argument".
ENV DOTNET_EnableDiagnostics=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH="/root/.dotnet/tools:${PATH}" \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off

# The base sdk:10.0 image only carries the .NET 10 shared runtime, but
# PowerShell 7.4.6 is a .NET 8 app and its apphost won't roll forward onto a
# newer major on its own, so `pwsh` aborts with app-launch-failed. Install the
# matching 8.0 runtime here (build has network) so pwsh runs on the framework
# it was built against; the layer persists into the airgapped test container.
RUN n=0; until curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh; do \
        n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; \
        echo "dotnet-install download failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); \
    done \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --version 8.0.29 --runtime dotnet --install-dir /usr/share/dotnet --no-path \
    && rm /tmp/dotnet-install.sh

WORKDIR /app
COPY repo/ .

# --- Install PowerShell 7 (as a .NET global tool) and Pester 4.x offline ---
# Both are fetched at *build* time (build has network); at test time the
# container runs with --network=none, so nothing here may be deferred to
# runtime. Pester 4.x is required because the project's harness imports
# Pester with `-Max 4.99` and uses Pester-4 invocation syntax.
RUN n=0; until dotnet tool install --global PowerShell --version 7.4.6; do \
        n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; \
        echo "pwsh install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); \
    done \
    && /root/.dotnet/tools/pwsh --version

RUN /root/.dotnet/tools/pwsh -NoProfile -Command \
      "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
       Install-Module -Name Pester -RequiredVersion 4.10.1 -Scope AllUsers -Force -SkipPublisherCheck; \
       Get-Module -ListAvailable Pester | Select-Object Name,Version"

# coverlet.console instruments the compiled module DLL while pwsh drives the
# Pester tests, so the oracle solution's line coverage can be reported as
# Cobertura XML. Installed at build time (no network at test time).
RUN n=0; until dotnet tool install --global coverlet.console --version 6.0.2; do \
        n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; \
        echo "coverlet install failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); \
    done \
    && /root/.dotnet/tools/coverlet --help >/dev/null 2>&1 || true

# --- Restore + build the module at build time to warm the NuGet cache ---
# (net462 reference assemblies + Markdig + YamlDotNet are pulled here so the
# test-time rebuild from the agent's edited src can run with --no-restore and
# no network.) The staged module lives at /app/out/platyPS.
RUN n=0; until dotnet restore src/Microsoft.PowerShell.PlatyPS.csproj; do \
        n=$((n+1)); if [ $n -ge 3 ]; then exit 1; fi; \
        echo "dependency restore failed (attempt $n/3), retrying…" >&2; sleep $((n*15)); \
    done \
    && dotnet build src/Microsoft.PowerShell.PlatyPS.csproj --no-restore --configuration Debug \
    && BIN=src/bin/Debug/net462 \
    && mkdir -p out/platyPS/Dependencies \
    && cp "$BIN/Microsoft.PowerShell.PlatyPS.dll" "$BIN/Microsoft.PowerShell.PlatyPS.pdb" src/platyPS.psd1 out/platyPS/ \
    && cp "$BIN/Markdig.Signed.dll" "$BIN/YamlDotNet.dll" out/platyPS/Dependencies/ \
    && rm -rf /tmp/* /root/.dotnet/TelemetryStorageService

RUN mkdir -p /installed-agent
