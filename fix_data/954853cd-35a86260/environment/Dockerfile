FROM mcr.microsoft.com/dotnet/sdk@sha256:493fca072aac81307027cbb7b7c9a82b6e87d222af315504d05dc6530e69b519

WORKDIR /app
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

COPY repo/ .

RUN apt-get update \
    && apt-get install -y --no-install-recommends tmux util-linux patch asciinema \
    && rm -rf /var/lib/apt/lists/*

# Bake NuGet restore into the image so verifier execution does not need network access.
RUN dotnet restore test/WebJobs.Script.Tests/WebJobs.Script.Tests.csproj

CMD ["bash"]
