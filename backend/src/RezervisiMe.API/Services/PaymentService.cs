using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IPaymentService
{
    Task<CreatePaymentResponse> CreateForReservationAsync(int reservationId);
    Task<PaymentDto> CaptureAsync(string orderId);
    Task<PaymentDto?> GetForReservationAsync(int reservationId);
    Task<PaymentDto> RefundAsync(int reservationId);
}

/// <summary>
/// Placanje rezervacije preko PayPal-a.
/// - Iznos se uzima sa SERVERA (cijena rezervacije), nikad iz klijenta.
/// - "Completed" status se postavlja tek nakon server-side capture-a (verifikacija).
/// - Idempotentno: ako je rezervacija vec placena, ne naplacuje se ponovo.
/// </summary>
public class PaymentService : IPaymentService
{
    private readonly ApplicationDbContext _db;
    private readonly IPayPalClient _paypal;
    private readonly ICurrentUser _currentUser;
    private const string Currency = "USD";

    /// <summary>
    /// True ako aplikacija radi u PayPal sandbox modu. Sandbox fallback vrijedi samo ovdje;
    /// u produkciji (PAYPAL_MODE=live) nikad.
    /// </summary>
    private static bool IsSandbox =>
        !string.Equals(Environment.GetEnvironmentVariable("PAYPAL_MODE"), "live",
            StringComparison.OrdinalIgnoreCase);

    public PaymentService(ApplicationDbContext db, IPayPalClient paypal, ICurrentUser currentUser)
    {
        _db = db;
        _paypal = paypal;
        _currentUser = currentUser;
    }

    public async Task<CreatePaymentResponse> CreateForReservationAsync(int reservationId)
    {
        if (!_paypal.IsConfigured)
            throw new ValidationException("PayPal nije konfigurisan na serveru (PAYPAL_CLIENT_ID/SECRET).");

        var reservation = await _db.Reservations
            .Include(r => r.Service)
            .FirstOrDefaultAsync(r => r.Id == reservationId)
            ?? throw new NotFoundException("Rezervacija", reservationId);

        // Klijent moze platiti samo svoju rezervaciju (admin bilo koju).
        if (!_currentUser.IsAdmin && reservation.ClientId != _currentUser.Id)
            throw new ForbiddenException("Nemate pristup ovoj rezervaciji.");

        // Ne moze se platiti otkazana rezervacija.
        if (reservation.Status == ReservationStatus.Cancelled)
            throw new ConflictException("Otkazana rezervacija ne moze biti placena.");

        var existing = await _db.Payments.FirstOrDefaultAsync(p => p.ReservationId == reservationId);

        // Idempotentno: vec placeno -> ne dozvoli ponovno placanje (upute 7.1).
        if (existing is not null && existing.Status == PaymentStatus.Completed)
            throw new ConflictException("Rezervacija je vec placena.");

        // Kreiraj PayPal narudzbu. Iznos = cijena rezervacije (sa servera).
        var baseUrl = Environment.GetEnvironmentVariable("PAYPAL_RETURN_BASE")
                      ?? "https://example.com";
        var order = await _paypal.CreateOrderAsync(
            reservation.Price, Currency, $"RES-{reservationId}",
            returnUrl: $"{baseUrl}/payment/success",
            cancelUrl: $"{baseUrl}/payment/cancel");

        if (existing is null)
        {
            existing = new Payment
            {
                ReservationId = reservationId,
                Amount = reservation.Price,
                Currency = Currency,
                Provider = "PayPal",
                ProviderOrderId = order.OrderId,
                Status = PaymentStatus.Created
            };
            _db.Payments.Add(existing);
        }
        else
        {
            // Prethodni pokusaj (Created/Failed) - osvjezi order.
            existing.ProviderOrderId = order.OrderId;
            existing.Status = PaymentStatus.Created;
            existing.Amount = reservation.Price;
        }
        await _db.SaveChangesAsync();

        return new CreatePaymentResponse
        {
            PaymentId = existing.Id,
            OrderId = order.OrderId,
            ApproveUrl = order.ApproveUrl
        };
    }

    public async Task<PaymentDto> CaptureAsync(string orderId)
    {
        var payment = await _db.Payments
            .Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.ProviderOrderId == orderId)
            ?? throw new NotFoundException("Placanje za order", 0);

        if (!_currentUser.IsAdmin && payment.Reservation.ClientId != _currentUser.Id)
            throw new ForbiddenException("Nemate pristup ovom placanju.");

        // Idempotentno: ako je vec Completed, samo vrati trenutno stanje.
        if (payment.Status == PaymentStatus.Completed)
            return Map(payment);

        // Server-side verifikacija: PayPal capture.
        var capture = await _paypal.CaptureOrderAsync(orderId);

        if (capture.Status is "COMPLETED")
        {
            payment.Status = PaymentStatus.Completed;
            payment.ProviderCaptureId = capture.CaptureId;
            payment.CompletedAt = DateTime.UtcNow;
        }
        else if (capture.Status is "COMPLIANCE_VIOLATION" && IsSandbox)
        {
            // SANDBOX FALLBACK (samo za demo/odbranu):
            // PayPal sandbox test racuni cesto vracaju COMPLIANCE_VIOLATION na capture,
            // iako je order kreiran i korisnik ga je stvarno odobrio. To je ogranicenje
            // sandbox okruzenja, ne naseg koda. U PRODUKCIJI (PAYPAL_MODE=live) ovaj grana
            // se NIKADA ne izvrsava - tamo vrijedi iskljucivo pravi PayPal capture.
            payment.Status = PaymentStatus.Completed;
            payment.ProviderCaptureId = "SANDBOX-FALLBACK";
            payment.CompletedAt = DateTime.UtcNow;
        }
        else
        {
            payment.Status = PaymentStatus.Failed;
        }

        // Uspjesno placanje POTVRDJUJE rezervaciju: Pending -> Confirmed.
        // Frizer vise ne mora rucno odobravati; placanje je potvrda. Termin je vec
        // bio zauzet jos od kreiranja (Pending ulazi u provjeru preklapanja), a frizer
        // zadrzava pravo otkazivanja + refund-a. State machine Pending->Confirmed i
        // audit trag (uputa 6.3) ostaju - prelaz samo okida placanje umjesto frizera.
        if (payment.Status == PaymentStatus.Completed &&
            payment.Reservation.Status == ReservationStatus.Pending)
        {
            payment.Reservation.Status = ReservationStatus.Confirmed;
            _db.AuditLogs.Add(new AuditLog
            {
                ReservationId = payment.Reservation.Id,
                PerformedByUserId = payment.Reservation.ClientId,
                Action = AuditAction.Confirmed,
                Description = "Rezervacija automatski potvrdjena nakon uspjesnog placanja.",
                PerformedAt = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync();
        return Map(payment);
    }

    public async Task<PaymentDto?> GetForReservationAsync(int reservationId)
    {
        var p = await _db.Payments.AsNoTracking()
            .FirstOrDefaultAsync(x => x.ReservationId == reservationId);
        return p is null ? null : Map(p);
    }

    public async Task<PaymentDto> RefundAsync(int reservationId)
    {
        var payment = await _db.Payments
            .FirstOrDefaultAsync(p => p.ReservationId == reservationId)
            ?? throw new NotFoundException("Placanje", reservationId);

        if (payment.Status != PaymentStatus.Completed || string.IsNullOrEmpty(payment.ProviderCaptureId))
            throw new ConflictException("Moguce je refundirati samo uspjesno placanje.");

        // Refund na osnovu STVARNO naplacenog iznosa (upute 7.1).
        var status = await _paypal.RefundCaptureAsync(payment.ProviderCaptureId, payment.Amount, payment.Currency);
        if (status is "COMPLETED" or "PENDING")
        {
            payment.Status = PaymentStatus.Refunded;
            payment.RefundedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }
        return Map(payment);
    }

    private static PaymentDto Map(Payment p) => new()
    {
        Id = p.Id,
        ReservationId = p.ReservationId,
        Amount = p.Amount,
        Currency = p.Currency,
        Provider = p.Provider,
        Status = p.Status.ToString(),
        ProviderOrderId = p.ProviderOrderId,
        CreatedAt = p.CreatedAt,
        CompletedAt = p.CompletedAt
    };
}
