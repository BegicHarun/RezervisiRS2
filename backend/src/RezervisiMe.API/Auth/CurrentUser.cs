using System.Security.Claims;
using RezervisiMe.API.Common;

namespace RezervisiMe.API.Auth;

public interface ICurrentUser
{
    int Id { get; }
    bool IsAdmin { get; }
    bool IsInRole(string role);
}

/// <summary>
/// Cita identitet trenutnog korisnika iz JWT tokena preko IHttpContextAccessor-a (upute 3.4, 5).
/// userId se NIKADA ne prima iz rute ili body-ja.
/// </summary>
public class CurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentUser(IHttpContextAccessor accessor) => _accessor = accessor;

    private ClaimsPrincipal? Principal => _accessor.HttpContext?.User;

    public int Id
    {
        get
        {
            var raw = Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
            if (int.TryParse(raw, out var id)) return id;
            throw new ForbiddenException("Korisnik nije autentifikovan.");
        }
    }

    public bool IsAdmin => IsInRole(Roles.Administrator);

    public bool IsInRole(string role) => Principal?.IsInRole(role) ?? false;
}
