using System.ComponentModel.DataAnnotations;

namespace RezervisiMe.API.DTOs;

public class UserDto
{
    public int Id { get; set; }
    public string Username { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string? ImageUrl { get; set; }
    public string? CityName { get; set; }
    public IReadOnlyList<string> Roles { get; set; } = new List<string>();
}

public class UpdateProfileRequest
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    public string LastName { get; set; } = null!;

    public int? CityId { get; set; }
    public string? ImageUrl { get; set; }
}

public class ChangePasswordRequest
{
    [Required(ErrorMessage = "Trenutna lozinka je obavezna.")]
    public string CurrentPassword { get; set; } = null!;

    [Required(ErrorMessage = "Nova lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Nova lozinka mora imati najmanje 6 karaktera.")]
    public string NewPassword { get; set; } = null!;
}

// ---- Referentni podaci ----

public class CityDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Region { get; set; } = null!;
}

public class CityUpsertRequest
{
    [Required(ErrorMessage = "Naziv grada je obavezan.")]
    public string Name { get; set; } = null!;

    [Required(ErrorMessage = "Regija je obavezna.")]
    public string Region { get; set; } = null!;
}

public class ServiceCategoryDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? IconName { get; set; }
}

public class ServiceCategoryUpsertRequest
{
    [Required(ErrorMessage = "Naziv kategorije je obavezan.")]
    public string Name { get; set; } = null!;

    public string? IconName { get; set; }
}

public class TagDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
}
