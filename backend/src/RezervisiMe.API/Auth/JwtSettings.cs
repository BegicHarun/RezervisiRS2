namespace RezervisiMe.API.Auth;

/// <summary>
/// JWT konfiguracija. Vrijednosti se citaju iz .env-a (upute 3.3),
/// nikad hardkodirane u kodu ili appsettings.json.
/// </summary>
public class JwtSettings
{
    public string Key { get; init; } = null!;
    public string Issuer { get; init; } = null!;
    public string Audience { get; init; } = null!;
    public int ExpiryMinutes { get; init; } = 120;

    public static JwtSettings FromEnvironment()
    {
        string Req(string name) =>
            Environment.GetEnvironmentVariable(name)
            ?? throw new InvalidOperationException($"{name} nije postavljen u .env fajlu.");

        return new JwtSettings
        {
            Key = Req("JWT_KEY"),
            Issuer = Req("JWT_ISSUER"),
            Audience = Req("JWT_AUDIENCE"),
            ExpiryMinutes = int.TryParse(Environment.GetEnvironmentVariable("JWT_EXPIRY_MINUTES"), out var m) ? m : 120
        };
    }
}
