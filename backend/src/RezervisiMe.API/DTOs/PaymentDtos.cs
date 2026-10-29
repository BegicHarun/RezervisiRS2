namespace RezervisiMe.API.DTOs;

public class PaymentDto
{
    public int Id { get; set; }
    public int ReservationId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = null!;
    public string Provider { get; set; } = null!;
    public string Status { get; set; } = null!;
    public string? ProviderOrderId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}

/// <summary>Odgovor nakon kreiranja PayPal narudzbe - klijent otvara approveUrl.</summary>
public class CreatePaymentResponse
{
    public int PaymentId { get; set; }
    public string OrderId { get; set; } = null!;
    public string? ApproveUrl { get; set; }
}

public class CapturePaymentRequest
{
    public string OrderId { get; set; } = null!;
}
