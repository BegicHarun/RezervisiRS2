using RezervisiMe.API.Common;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Frizerski/beauty salon. Glavna tabela.
/// </summary>
public class Salon
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    /// <summary>Grad - FK prema referentnoj tabeli.</summary>
    public int CityId { get; set; }
    public City City { get; set; } = null!;

    /// <summary>Status verifikacije od strane administratora.</summary>
    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;
    public string? RejectionReason { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Soft delete
    public bool IsDeleted { get; set; }

    public ICollection<Hairdresser> Hairdressers { get; set; } = new List<Hairdresser>();
    public ICollection<Service> Services { get; set; } = new List<Service>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<SalonImage> Images { get; set; } = new List<SalonImage>();
}

/// <summary>
/// Frizer koji radi u salonu. Vezan za korisnika (ApplicationUser) i za salon. Glavna tabela.
/// </summary>
public class Hairdresser
{
    public int Id { get; set; }

    /// <summary>FK prema korisniku (frizer ima nalog u sistemu).</summary>
    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int SalonId { get; set; }
    public Salon Salon { get; set; } = null!;

    public string Specialization { get; set; } = null!;

    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;
    public string? RejectionReason { get; set; }

    public bool IsDeleted { get; set; }

    public ICollection<WorkingHour> WorkingHours { get; set; } = new List<WorkingHour>();
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<HairdresserService> HairdresserServices { get; set; } = new List<HairdresserService>();
}
