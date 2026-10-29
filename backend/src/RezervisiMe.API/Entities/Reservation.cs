using RezervisiMe.API.Common;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Rezervacija termina - centralna poslovna logika sistema. Glavna tabela.
/// Status se mijenja kroz state machine, nikada hard delete umjesto promjene statusa.
/// </summary>
public class Reservation
{
    public int Id { get; set; }

    /// <summary>Klijent koji rezervise - FK prema korisniku.</summary>
    public int ClientId { get; set; }
    public ApplicationUser Client { get; set; } = null!;

    public int HairdresserId { get; set; }
    public Hairdresser Hairdresser { get; set; } = null!;

    public int ServiceId { get; set; }
    public Service Service { get; set; } = null!;

    /// <summary>Pocetak termina (UTC).</summary>
    public DateTime StartTime { get; set; }

    /// <summary>Kraj termina (UTC) - racuna se iz StartTime + trajanje usluge.</summary>
    public DateTime EndTime { get; set; }

    /// <summary>Cijena zabiljezena u trenutku rezervacije (server odredjuje, ne klijent).</summary>
    public decimal Price { get; set; }

    public ReservationStatus Status { get; set; } = ReservationStatus.Pending;

    /// <summary>Razlog odbijanja/otkazivanja (obavezan kod odbijanja).</summary>
    public string? StatusReason { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<AuditLog> AuditLogs { get; set; } = new List<AuditLog>();
    public Review? Review { get; set; }
    public Payment? Payment { get; set; }
}
