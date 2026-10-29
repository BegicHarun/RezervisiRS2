using System.ComponentModel.DataAnnotations;

namespace RezervisiMe.API.DTOs;

public class LoginRequest
{
    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    public string Password { get; set; } = null!;
}

public class RegisterRequest
{
    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "Korisnicko ime mora imati 3-50 karaktera.")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Email je obavezan.")]
    [EmailAddress(ErrorMessage = "Unesite ispravan email u formatu ime@domena.com.")]
    public string Email { get; set; } = null!;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Lozinka mora imati najmanje 6 karaktera.")]
    public string Password { get; set; } = null!;

    [Required(ErrorMessage = "Ime je obavezno.")]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    public string LastName { get; set; } = null!;

    public int? CityId { get; set; }

    // NAPOMENA: role/isAdmin se NAMJERNO ne prima od klijenta (upute 5).
    // Svaki registrovani korisnik dobija rolu Klijent na serveru.
}

public class AuthResponse
{
    public string Token { get; set; } = null!;
    public DateTime ExpiresAt { get; set; }
    public UserDto User { get; set; } = null!;
}
