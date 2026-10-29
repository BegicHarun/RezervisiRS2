# ==========================================================
# Dockerfile za Worker / Notifier mikroservis (upute 3.2 / 4).
# Zaseban kontejner, odvojen od glavnog API-ja.
# Build iz ROOT foldera repozitorija:
#   docker build -f src/RezervisiMe.Worker/Dockerfile -t rezervisime-worker .
# ==========================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/RezervisiMe.Worker/RezervisiMe.Worker.csproj src/RezervisiMe.Worker/
RUN dotnet restore src/RezervisiMe.Worker/RezervisiMe.Worker.csproj

COPY src/RezervisiMe.Worker/ src/RezervisiMe.Worker/
RUN dotnet publish src/RezervisiMe.Worker/RezervisiMe.Worker.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "RezervisiMe.Worker.dll"]
