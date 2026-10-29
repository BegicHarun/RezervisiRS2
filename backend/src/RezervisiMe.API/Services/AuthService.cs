using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> RegisterAsync(RegisterRequest request);
    Task LogoutAsync(int userId);
}

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ITokenService _tokenService;
    private readonly JwtSettings _jwt;
    private readonly ApplicationDbContext _db;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        ITokenService tokenService,
        JwtSettings jwt,
        ApplicationDbContext db)
    {
        _userManager = userManager;
        _tokenService = tokenService;
        _jwt = jwt;
        _db = db;
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var user = await _userManager.FindByNameAsync(request.Username);
        if (user is null || !await _userManager.CheckPasswordAsync(user, request.Password))
            throw new BusinessException("Pogresno korisnicko ime ili lozinka.");

        if (!user.IsActive)
            throw new ForbiddenException("Nalog je deaktiviran.");

        return await BuildResponseAsync(user);
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        if (await _userManager.FindByNameAsync(request.Username) is not null)
            throw new ConflictException("Korisnicko ime je vec zauzeto.");

        if (await _userManager.FindByEmailAsync(request.Email) is not null)
            throw new ConflictException("Email je vec registrovan.");

        var user = new ApplicationUser
        {
            UserName = request.Username,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            CityId = request.CityId,
            EmailConfirmed = true
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => e.Description));

        // Klijent NE moze sam sebi dodijeliti privilegije - uvijek rola Klijent (upute 5).
        await _userManager.AddToRoleAsync(user, Roles.Klijent);

        return await BuildResponseAsync(user);
    }

    /// <summary>
    /// Server-side odjava (uputa 5): mijenja SecurityStamp korisnika. Time svi ranije
    /// izdati JWT tokeni tog korisnika postaju nevazeci (OnTokenValidated poredi stamp).
    /// </summary>
    public async Task LogoutAsync(int userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user is null) return; // vec nepostojeci/odjavljen - nista za raditi
        await _userManager.UpdateSecurityStampAsync(user);
    }

    private async Task<AuthResponse> BuildResponseAsync(ApplicationUser user)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var token = _tokenService.CreateToken(user, roles);

        string? cityName = null;
        if (user.CityId is not null)
            cityName = await _db.Cities.Where(c => c.Id == user.CityId)
                .Select(c => c.Name).FirstOrDefaultAsync();

        return new AuthResponse
        {
            Token = token,
            ExpiresAt = DateTime.UtcNow.AddMinutes(_jwt.ExpiryMinutes),
            User = new UserDto
            {
                Id = user.Id,
                Username = user.UserName!,
                Email = user.Email!,
                FirstName = user.FirstName,
                LastName = user.LastName,
                ImageUrl = user.ImageUrl,
                CityName = cityName,
                Roles = roles.ToList()
            }
        };
    }
}
