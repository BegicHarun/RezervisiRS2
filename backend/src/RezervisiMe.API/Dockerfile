# ==========================================================
# Dockerfile za glavni API servis.
# Build iz ROOT foldera repozitorija:
#   docker build -f src/RezervisiMe.API/Dockerfile -t rezervisime-api .
# ==========================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/RezervisiMe.API/RezervisiMe.API.csproj src/RezervisiMe.API/
RUN dotnet restore src/RezervisiMe.API/RezervisiMe.API.csproj

COPY src/RezervisiMe.API/ src/RezervisiMe.API/
RUN dotnet publish src/RezervisiMe.API/RezervisiMe.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "RezervisiMe.API.dll"]
