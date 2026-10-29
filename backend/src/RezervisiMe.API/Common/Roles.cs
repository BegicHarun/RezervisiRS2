namespace RezervisiMe.API.Common;

/// <summary>
/// Nazivi rola - magic stringovi za role smjesteni u staticku klasu (upute 3.4).
/// Ovi nazivi moraju odgovarati nazivima u seed podacima i u [Authorize(Roles=...)] atributima.
/// </summary>
public static class Roles
{
    public const string Administrator = "Administrator";
    public const string Frizer = "Frizer";
    public const string Klijent = "Klijent";

    public static readonly string[] All = { Administrator, Frizer, Klijent };
}
