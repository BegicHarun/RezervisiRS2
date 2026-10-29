using System.ComponentModel.DataAnnotations;

namespace RezervisiMe.API.DTOs;

public class ReservationDto
{
    public int Id { get; set; }
    public int ClientId { get; set; }
    public string ClientName { get; set; } = null!;
    public int HairdresserId { get; set; }
    public string HairdresserName { get; set; } = null!;
    public int ServiceId { get; set; }
    public string ServiceName { get; set; } = null!;
    public string SalonName { get; set; } = null!;
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public decimal Price { get; set; }
    public string Status { get; set; } = null!;
    public string? StatusReason { get; set; }
    public bool CanReview { get; set; }

    /// <summary>Ime osobe koja je zadnja mijenjala status (audit trag, upute 7.2).</summary>
    public string? LastActionBy { get; set; }

    /// <summary>Citljiv sazetak audita za kolonu "Odobrio / razlog" (npr. "Odobrio: Amela H.").</summary>
    public string? AuditSummary { get; set; }

    /// <summary>Kada je rezervacija kreirana.</summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>Da li je rezervacija placena (PayPal capture uspjesan).</summary>
    public bool IsPaid { get; set; }
}

public class CreateReservationRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Odaberite frizera.")]
    public int HairdresserId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Odaberite uslugu.")]
    public int ServiceId { get; set; }

    [Required(ErrorMessage = "Odaberite termin.")]
    public DateTime StartTime { get; set; }
    // ClientId se NE prima - uzima se iz JWT tokena (upute 5).
    // Price se NE prima - server sam odredjuje iz kataloga usluga (upute 7.1).
}

public class ChangeStatusRequest
{
    /// <summary>Novi status: Confirmed, Cancelled ili Completed.</summary>
    [Required(ErrorMessage = "Status je obavezan.")]
    public string Status { get; set; } = null!;

    /// <summary>Razlog - obavezan kod otkazivanja/odbijanja.</summary>
    public string? Reason { get; set; }
}

/// <summary>Slobodan termin koji backend racuna iz radnog vremena i postojecih rezervacija.</summary>
public class AvailableSlotDto
{
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
}

// ---- Review ----

public class ReviewDto
{
    public int Id { get; set; }
    public int ReservationId { get; set; }
    public int SalonId { get; set; }
    public string ClientName { get; set; } = null!;
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAt { get; set; }
    public IReadOnlyList<string> Tags { get; set; } = new List<string>();
}

public class CreateReviewRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Nedostaje rezervacija.")]
    public int ReservationId { get; set; }

    [Range(1, 5, ErrorMessage = "Ocjena mora biti izmedju 1 i 5.")]
    public int Rating { get; set; }

    [StringLength(1000)]
    public string? Comment { get; set; }

    public List<int> TagIds { get; set; } = new();
}

// ---- Notification ----

public class NotificationDto
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
}
