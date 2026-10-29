using RezervisiMe.API.Common;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Recenzija klijenta nakon zavrsenog termina. Glavna tabela.
/// Vezana za konkretnu rezervaciju - jedna rezervacija = najvise jedna recenzija.
/// </summary>
public class Review
{
    public int Id { get; set; }

    public int ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;

    public int ClientId { get; set; }
    public ApplicationUser Client { get; set; } = null!;

    public int SalonId { get; set; }
    public Salon Salon { get; set; } = null!;

    /// <summary>Ocjena 1-5.</summary>
    public int Rating { get; set; }

    public string? Comment { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<ReviewTag> ReviewTags { get; set; } = new List<ReviewTag>();
}

/// <summary>
/// Sistemska notifikacija za korisnika. Glavna tabela.
/// </summary>
public class Notification
{
    public int Id { get; set; }

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;

    public bool IsRead { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Historija pretrage klijenta - signal za recommender. Glavna tabela.
/// Stvarno se upisuje pri svakoj pretrazi (ne fake podatak).
/// </summary>
public class SearchHistory
{
    public int Id { get; set; }

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string? SearchTerm { get; set; }

    /// <summary>Kategorija po kojoj je filtrirano (ako je bilo) - FK.</summary>
    public int? ServiceCategoryId { get; set; }
    public ServiceCategory? ServiceCategory { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Audit trag - ko je i kada kreirao/odobrio/odbio rezervaciju. Glavna tabela.
/// </summary>
public class AuditLog
{
    public int Id { get; set; }

    public int ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;

    /// <summary>Korisnik koji je izvrsio akciju.</summary>
    public int PerformedByUserId { get; set; }
    public ApplicationUser PerformedByUser { get; set; } = null!;

    public AuditAction Action { get; set; }

    public string? Description { get; set; }

    public DateTime PerformedAt { get; set; } = DateTime.UtcNow;
}
