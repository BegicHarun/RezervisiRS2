using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Auth;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly ICurrentUser _currentUser;
    public AuthController(IAuthService auth, ICurrentUser currentUser)
    {
        _auth = auth;
        _currentUser = currentUser;
    }

    /// <summary>Prijava korisnika. Kredencijali se salju u body-ju (nikad query string).</summary>
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
        => Ok(await _auth.LoginAsync(request));

    /// <summary>Registracija novog korisnika (uvijek rola Klijent).</summary>
    [AllowAnonymous]
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register([FromBody] RegisterRequest request)
        => Ok(await _auth.RegisterAsync(request));

    /// <summary>
    /// Odjava. Invalidira token NA SERVERU (mijenja SecurityStamp), ne samo lokalno (uputa 5).
    /// Nakon ovoga svaki ranije izdati token tog korisnika prestaje vrijediti.
    /// </summary>
    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        await _auth.LogoutAsync(_currentUser.Id);
        return NoContent();
    }
}
