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
    Task RequestPasswordResetAsync(PasswordResetRequest request);
    Task ResetPasswordAsync(PasswordResetConfirmation request);
}

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ITokenService _tokenService;
    private readonly JwtSettings _jwt;
    private readonly ApplicationDbContext _db;
    private readonly NotificationOutbox _outbox;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        ITokenService tokenService,
        JwtSettings jwt,
        ApplicationDbContext db, NotificationOutbox outbox)
    {
        _userManager = userManager;
        _tokenService = tokenService;
        _jwt = jwt;
        _db = db;
        _outbox = outbox;
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

        await using var transaction = await _db.Database.BeginTransactionAsync();
        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => e.Description));

        // Klijent NE moze sam sebi dodijeliti privilegije - uvijek rola Klijent (upute 5).
        var role = await _userManager.AddToRoleAsync(user, Roles.Klijent);
        if (!role.Succeeded) throw new ValidationException(role.Errors.Select(e => e.Description));
        await transaction.CommitAsync();

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
        var result = await _userManager.UpdateSecurityStampAsync(user);
        if (!result.Succeeded) throw new ConflictException("Odjava nije uspjela. Pokusajte ponovo.");
    }

    public async Task RequestPasswordResetAsync(PasswordResetRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email.Trim());
        if (user is not { IsActive: true, Email: not null }) return;

        var token = await _userManager.GeneratePasswordResetTokenAsync(user);
        _outbox.Enqueue(new NotificationMessage(user.Id, user.Email,
            "RezervisiMe - reset lozinke",
            $"Kod za reset lozinke vrijedi 30 minuta. Unesite ga u aplikaciju: {token}"), TimeSpan.FromMinutes(30));
        await _db.SaveChangesAsync();
    }

    public async Task ResetPasswordAsync(PasswordResetConfirmation request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email.Trim());
        if (user is not { IsActive: true })
            throw new ValidationException("Kod je nevazeci ili je istekao.");

        var result = await _userManager.ResetPasswordAsync(user, request.Token.Trim(), request.NewPassword);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => e.Description));
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
