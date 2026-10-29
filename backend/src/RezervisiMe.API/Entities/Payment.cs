using RezervisiMe.API.Common;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Placanje rezervacije preko PayPal-a. Jedna rezervacija ima najvise jedno placanje.
/// Iznos i status se potvrdjuju na serveru (capture preko PayPal API-ja), nikad se ne
/// vjeruje klijentu da je placanje uspjesno.
/// </summary>
public class Payment
{
    public int Id { get; set; }

    public int ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;

    /// <summary>Iznos (preuzet sa servera iz cijene rezervacije, ne iz klijenta).</summary>
    public decimal Amount { get; set; }

    public string Currency { get; set; } = "USD";

    /// <summary>Provajder placanja (za sada "PayPal").</summary>
    public string Provider { get; set; } = "PayPal";

    /// <summary>ID narudzbe (order) kod PayPal-a - veza prema stvarnoj transakciji.</summary>
    public string? ProviderOrderId { get; set; }

    /// <summary>ID capture-a kod PayPal-a (potreban za refund).</summary>
    public string? ProviderCaptureId { get; set; }

    public PaymentStatus Status { get; set; } = PaymentStatus.Created;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public DateTime? RefundedAt { get; set; }
}
