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
    private readonly NotificationOutbox _outbox;
    private const string Currency = "USD";

    public PaymentService(ApplicationDbContext db, IPayPalClient paypal, ICurrentUser currentUser, NotificationOutbox outbox)
    {
        _db = db;
        _paypal = paypal;
        _currentUser = currentUser;
        _outbox = outbox;
    }

    public async Task<CreatePaymentResponse> CreateForReservationAsync(int reservationId)
    {
        if (!_paypal.IsConfigured)
            throw new ValidationException("PayPal nije konfigurisan na serveru (PAYPAL_CLIENT_ID/SECRET).");

        await using var tx = await _db.Database.BeginTransactionAsync();
        await ReservationLock.AcquireAsync(_db, reservationId);
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
        if (existing is not null && existing.Status is PaymentStatus.Completed or PaymentStatus.Refunded)
            throw new ConflictException("Rezervacija je vec placena.");

        if (existing is { Status: PaymentStatus.Created, ProviderOrderId: { } existingOrderId })
        {
            var pending = await _paypal.GetOrderAsync(existingOrderId);
            if (pending.ApproveUrl is not null && pending.Status is "CREATED" or "PAYER_ACTION_REQUIRED" or "APPROVED")
                return new CreatePaymentResponse { PaymentId = existing.Id, OrderId = existingOrderId, ApproveUrl = pending.ApproveUrl };
            throw new ConflictException("Postojeca PayPal narudzba zahtijeva provjeru statusa.");
        }

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
        await tx.CommitAsync();

        return new CreatePaymentResponse
        {
            PaymentId = existing.Id,
            OrderId = order.OrderId,
            ApproveUrl = order.ApproveUrl
        };
    }

    public async Task<PaymentDto> CaptureAsync(string orderId)
    {
        var reservationId = await _db.Payments.AsNoTracking()
            .Where(p => p.ProviderOrderId == orderId).Select(p => (int?)p.ReservationId).FirstOrDefaultAsync()
            ?? throw new NotFoundException("Placanje za order", 0);
        await using var tx = await _db.Database.BeginTransactionAsync();
        await ReservationLock.AcquireAsync(_db, reservationId);
        var payment = await _db.Payments
            .Include(p => p.Reservation)
            .FirstOrDefaultAsync(p => p.ProviderOrderId == orderId)
            ?? throw new NotFoundException("Placanje za order", 0);

        if (!_currentUser.IsAdmin && payment.Reservation.ClientId != _currentUser.Id)
            throw new ForbiddenException("Nemate pristup ovom placanju.");

        // Idempotentno: ako je vec Completed, samo vrati trenutno stanje.
        if (payment.Status == PaymentStatus.Completed)
            return Map(payment);

        if (payment.Reservation.Status == ReservationStatus.Cancelled || payment.Status == PaymentStatus.Refunded)
            throw new ConflictException("Ovo placanje vise nije dostupno.");

        // Server-side verifikacija: PayPal capture.
        var capture = await _paypal.CaptureOrderAsync(orderId);

        if (capture.Status is "COMPLETED" && !string.IsNullOrWhiteSpace(capture.CaptureId)
            && capture.Amount == payment.Amount && capture.Currency == payment.Currency)
        {
            payment.Status = PaymentStatus.Completed;
            payment.ProviderCaptureId = capture.CaptureId;
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
            ReservationStateMachine.EnsureTransition(payment.Reservation.Status, ReservationStatus.Confirmed);
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

        if (payment.Status == PaymentStatus.Completed)
            await AddNotificationAsync(payment.Reservation.ClientId, "Placanje potvrdjeno", "PayPal naplata je potvrdjena.");

        await _db.SaveChangesAsync();
        await tx.CommitAsync();
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
        await using var tx = await _db.Database.BeginTransactionAsync();
        await ReservationLock.AcquireAsync(_db, reservationId);
        var payment = await _db.Payments
            .FirstOrDefaultAsync(p => p.ReservationId == reservationId)
            ?? throw new NotFoundException("Placanje", reservationId);

        if (payment.Status == PaymentStatus.Refunded) return Map(payment);

        if (payment.Status != PaymentStatus.Completed || string.IsNullOrEmpty(payment.ProviderCaptureId))
            throw new ConflictException("Moguce je refundirati samo uspjesno placanje.");

        // Refund na osnovu STVARNO naplacenog iznosa (upute 7.1).
        var status = await _paypal.RefundCaptureAsync(payment.ProviderCaptureId, payment.Amount, payment.Currency);
        if (status is "COMPLETED")
        {
            payment.Status = PaymentStatus.Refunded;
            payment.RefundedAt = DateTime.UtcNow;
            var clientId = await _db.Reservations.Where(r => r.Id == reservationId)
                .Select(r => r.ClientId).SingleAsync();
            await AddNotificationAsync(clientId, "Povrat zavrsen", "PayPal je potvrdio povrat sredstava.");
            await _db.SaveChangesAsync();
            await tx.CommitAsync();
        }
        return Map(payment);
    }

    private async Task AddNotificationAsync(int userId, string title, string text)
    {
        _db.Notifications.Add(new Notification { UserId = userId, Title = title, Text = text });
        var email = await _db.Users.Where(u => u.Id == userId).Select(u => u.Email).FirstOrDefaultAsync();
        if (!string.IsNullOrWhiteSpace(email))
            _outbox.Enqueue(new NotificationMessage(userId, email, title, text));
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
