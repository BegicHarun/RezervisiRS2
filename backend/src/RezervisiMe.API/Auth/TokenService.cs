using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Auth;

public interface ITokenService
{
    string CreateToken(ApplicationUser user, IEnumerable<string> roles);
}

public class TokenService : ITokenService
{
    private readonly JwtSettings _settings;

    /// <summary>
    /// Naziv claim-a koji nosi Identity SecurityStamp. Logout na serveru mijenja stamp
    /// korisnika (UpdateSecurityStampAsync), pa svi ranije izdati tokeni postaju nevazeci
    /// jer se stamp iz tokena vise ne slaze sa stampom u bazi (uputa 5).
    /// </summary>
    public const string SecurityStampClaim = "security_stamp";

    public TokenService(JwtSettings settings) => _settings = settings;

    public string CreateToken(ApplicationUser user, IEnumerable<string> roles)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(ClaimTypes.Name, user.UserName ?? string.Empty),
            new(ClaimTypes.Email, user.Email ?? string.Empty),
            new(SecurityStampClaim, user.SecurityStamp ?? string.Empty)
        };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_settings.ExpiryMinutes),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
