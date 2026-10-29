using System.ComponentModel.DataAnnotations;

namespace RezervisiMe.API.DTOs;

public class SalonDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public int CityId { get; set; }
    public string CityName { get; set; } = null!;
    public string VerificationStatus { get; set; } = null!;
    public double AverageRating { get; set; }
    public int ReviewCount { get; set; }
    public IReadOnlyList<string> ImageUrls { get; set; } = new List<string>();
}

public class SalonUpsertRequest
{
    [Required(ErrorMessage = "Naziv salona je obavezan.")]
    [StringLength(150)]
    public string Name { get; set; } = null!;

    [Required(ErrorMessage = "Adresa je obavezna.")]
    public string Address { get; set; } = null!;

    public string? Description { get; set; }
    public string? ImageUrl { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite grad.")]
    public int CityId { get; set; }
}

public class SalonVerifyRequest
{
    public bool Approve { get; set; }

    /// <summary>Obavezan kod odbijanja.</summary>
    public string? RejectionReason { get; set; }
}

// ---- Service ----

public class ServiceDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int DurationMinutes { get; set; }
    public int SalonId { get; set; }
    public string SalonName { get; set; } = null!;
    public int ServiceCategoryId { get; set; }
    public string ServiceCategoryName { get; set; } = null!;
    public bool IsActive { get; set; }
}

public class ServiceUpsertRequest
{
    [Required(ErrorMessage = "Naziv usluge je obavezan.")]
    public string Name { get; set; } = null!;

    public string? Description { get; set; }

    [Range(0.01, 100000, ErrorMessage = "Cijena mora biti veca od 0.")]
    public decimal Price { get; set; }

    [Range(5, 600, ErrorMessage = "Trajanje mora biti izmedju 5 i 600 minuta.")]
    public int DurationMinutes { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite salon.")]
    public int SalonId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite kategoriju.")]
    public int ServiceCategoryId { get; set; }

    public bool IsActive { get; set; } = true;
}

// ---- Hairdresser ----

public class HairdresserDto
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string FullName { get; set; } = null!;
    public string Specialization { get; set; } = null!;
    public int SalonId { get; set; }
    public string SalonName { get; set; } = null!;
    public string VerificationStatus { get; set; } = null!;
}

public class HairdresserUpsertRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Odaberite korisnika.")]
    public int UserId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite salon.")]
    public int SalonId { get; set; }

    [Required(ErrorMessage = "Specijalizacija je obavezna.")]
    public string Specialization { get; set; } = null!;
}

// ---- Radno vrijeme (7.5) ----

public class WorkingHourDto
{
    public int Id { get; set; }
    public int DayOfWeek { get; set; } // 0=nedjelja ... 6=subota
    public string DayName { get; set; } = null!;
    public string StartTime { get; set; } = null!; // "09:00"
    public string EndTime { get; set; } = null!;    // "17:00"
    public bool IsDayOff { get; set; }
}

public class WorkingHourUpsertRequest
{
    [Range(0, 6)]
    public int DayOfWeek { get; set; }

    /// <summary>Format "HH:mm" (npr. "09:00").</summary>
    public string StartTime { get; set; } = "09:00";
    public string EndTime { get; set; } = "17:00";
    public bool IsDayOff { get; set; }
}

// ---- Verifikacija frizera (7.6) ----

public class HairdresserVerifyRequest
{
    public bool Approve { get; set; }
    public string? RejectionReason { get; set; }
}

/// <summary>Admin kreira frizera SA nalogom (kredencijali za prijavu) i veze ga za salon.</summary>
public class HairdresserAccountRequest
{
    [Required(ErrorMessage = "Ime je obavezno.")]
    public string FirstName { get; set; } = null!;

    [Required(ErrorMessage = "Prezime je obavezno.")]
    public string LastName { get; set; } = null!;

    [Required(ErrorMessage = "Korisnicko ime je obavezno.")]
    [StringLength(50, MinimumLength = 3)]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Email je obavezan.")]
    [EmailAddress(ErrorMessage = "Neispravan email.")]
    public string Email { get; set; } = null!;

    [Required(ErrorMessage = "Lozinka je obavezna.")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Lozinka mora imati najmanje 6 karaktera.")]
    public string Password { get; set; } = null!;

    [Required(ErrorMessage = "Specijalizacija je obavezna.")]
    public string Specialization { get; set; } = null!;

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite salon.")]
    public int SalonId { get; set; }
}
