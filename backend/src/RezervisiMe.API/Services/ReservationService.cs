using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IReservationService
{
    Task<PagedResult<ReservationDto>> GetMineAsync(PagedQuery query);
    Task<PagedResult<ReservationDto>> GetForManagementAsync(PagedQuery query, string? status,
        DateTimeOffset? from = null, DateTimeOffset? to = null, int? hairdresserId = null);
    Task<ReservationDto> GetByIdAsync(int id);
    Task<ReservationDto> CreateAsync(CreateReservationRequest req);
    Task<ReservationDto> ChangeStatusAsync(int id, ChangeStatusRequest req);
    Task<IReadOnlyList<AvailableSlotDto>> GetAvailableSlotsAsync(int hairdresserId, int serviceId, DateOnly date);
}

public class ReservationService : IReservationService
{
    private static readonly TimeZoneInfo SalonTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo");
    private static DateTime SalonLocalTimeToUtc(DateOnly date, TimeOnly time, bool endBoundary = false)
    {
        var local = date.ToDateTime(time);
        // Advance nonexistent wall-clock times to the first valid minute after the spring gap.
        while (SalonTimeZone.IsInvalidTime(local))
            local = local.AddMinutes(1);

        if (SalonTimeZone.IsAmbiguousTime(local))
        {
            var offsets = SalonTimeZone.GetAmbiguousTimeOffsets(local);
            return new DateTimeOffset(local, endBoundary ? offsets.Min() : offsets.Max()).UtcDateTime;
        }

        return TimeZoneInfo.ConvertTimeToUtc(local, SalonTimeZone);
    }

    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly NotificationOutbox _outbox;
    private readonly ILogger<ReservationService> _logger;

    public ReservationService(
        ApplicationDbContext db,
        ICurrentUser currentUser,
        NotificationOutbox outbox,
        ILogger<ReservationService> logger)
    {
        _db = db;
        _currentUser = currentUser;
        _outbox = outbox;
        _logger = logger;
    }

    public async Task<PagedResult<ReservationDto>> GetMineAsync(PagedQuery query)
    {
        var userId = _currentUser.Id;
        var q = BaseQuery().Where(r => r.ClientId == userId);
        return await PageAsync(q, query);
    }

    public async Task<PagedResult<ReservationDto>> GetForManagementAsync(PagedQuery query, string? status,
        DateTimeOffset? from = null, DateTimeOffset? to = null, int? hairdresserId = null)
    {
        var q = BaseQuery();

        // Frizer vidi samo rezervacije svog salona; admin vidi sve.
        if (!_currentUser.IsAdmin)
        {
            var userId = _currentUser.Id;
            var salonId = await _db.Hairdressers.AsNoTracking()
                .Where(h => h.UserId == userId)
                .Select(h => (int?)h.SalonId)
                .FirstOrDefaultAsync();

            // Ako korisnik nije vezan ni za jedan salon, ne vidi nista.
            q = salonId == null
                ? q.Where(r => false)
                : q.Where(r => r.Service.SalonId == salonId);
        }

        if (from.HasValue && to.HasValue && from >= to)
            throw new ValidationException("Pocetak raspona mora biti prije kraja.");
        if (from is { } start) q = q.Where(r => r.EndTime > start.UtcDateTime);
        if (to is { } end) q = q.Where(r => r.StartTime < end.UtcDateTime);
        if (hairdresserId is { } id) q = q.Where(r => r.HairdresserId == id);

        if (!string.IsNullOrWhiteSpace(status) &&
            Enum.TryParse<ReservationStatus>(status, true, out var parsed))
            q = q.Where(r => r.Status == parsed);

        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(r => r.Client.FirstName.Contains(query.Search)
                          || r.Client.LastName.Contains(query.Search)
                          || r.Service.Name.Contains(query.Search));

        return await PageAsync(q, query);
    }

    public async Task<ReservationDto> GetByIdAsync(int id)
    {
        var r = await BaseQuery().FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException("Rezervacija", id);

        // Klijent smije vidjeti samo svoje; admin vidi sve.
        if (!_currentUser.IsAdmin && r.ClientId != _currentUser.Id &&
            !await _db.Hairdressers.AnyAsync(h => h.UserId == _currentUser.Id && h.SalonId == r.Service.SalonId))
            throw new ForbiddenException("Nemate pristup ovoj rezervaciji.");

        return Map(r);
    }

    public async Task<ReservationDto> CreateAsync(CreateReservationRequest req)
    {
        var clientId = _currentUser.Id; // iz JWT-a, nikad iz body-ja (upute 5)

        var service = await _db.Services.FirstOrDefaultAsync(s => s.Id == req.ServiceId)
                      ?? throw new ValidationException("Odabrana usluga ne postoji.");

        var hairdresser = await _db.Hairdressers
            .Include(h => h.Salon)
            .FirstOrDefaultAsync(h => h.Id == req.HairdresserId)
            ?? throw new ValidationException("Odabrani frizer ne postoji.");

        if (hairdresser.VerificationStatus != VerificationStatus.Approved)
            throw new BusinessException("Frizer nije verifikovan.");

        await EnsureServiceAvailableAsync(service, hairdresser.Id);

        // Termin ne moze biti u proslosti.
        var start = req.StartTime.UtcDateTime;
        if (start < DateTime.UtcNow)
            throw new BusinessException("Termin ne moze biti u proslosti.");

        // Server sam racuna kraj i cijenu (upute 7.1) - klijent ne salje cijenu.
        var end = start.AddMinutes(service.DurationMinutes);

        // Provjera radnog vremena frizera na backendu.
        await EnsureWithinWorkingHours(hairdresser.Id, start, end);

        await using var tx = await _db.Database.BeginTransactionAsync();
        await ReservationLock.AcquireAsync(_db, $"hairdresser-booking:{hairdresser.Id}");
        await ReservationLock.AcquireAsync(_db, $"client-booking:{clientId}");
        if (await _db.Reservations.AnyAsync(r => r.ClientId == clientId && r.StartTime == start &&
                r.Status != ReservationStatus.Cancelled))
            throw new ConflictException("Vec imate rezervaciju u tom terminu.");

        // Provjera preklapanja termina na backendu, ne samo na frontendu (upute 7).
        await EnsureNoOverlap(hairdresser.Id, start, end);

        var reservation = new Reservation
        {
            ClientId = clientId,
            HairdresserId = hairdresser.Id,
            ServiceId = service.Id,
            StartTime = start,
            EndTime = end,
            Price = service.Price,
            Status = ReservationStatus.Pending
        };

        // Vise SaveChanges u jednoj operaciji -> eksplicitna transakcija (upute 3.4).
        _db.Reservations.Add(reservation);
        await _db.SaveChangesAsync();

        AddAudit(reservation.Id, clientId, AuditAction.Created, "Rezervacija kreirana.");
        // Notifikacija i zapis za Worker se spremaju u istoj transakciji.
        await NotifyAsync(clientId, "Rezervacija zaprimljena",
            $"Vasa rezervacija za '{service.Name}' je zaprimljena i ceka potvrdu.");
        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        _logger.LogInformation("Kreirana rezervacija {Id} za korisnika {UserId}", reservation.Id, clientId);
        return await GetByIdInternal(reservation.Id);
    }

    public async Task<ReservationDto> ChangeStatusAsync(int id, ChangeStatusRequest req)
    {
        if (!Enum.TryParse<ReservationStatus>(req.Status, true, out var target))
            throw new ValidationException($"Nepoznat status '{req.Status}'.");

        await using var tx = await _db.Database.BeginTransactionAsync();
        await ReservationLock.AcquireAsync(_db, id);
        var reservation = await _db.Reservations
            .Include(r => r.Service)
            .Include(r => r.Client)
            .FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new NotFoundException("Rezervacija", id);

        // Ovlastenja:
        //  - admin: sve
        //  - frizer: rezervacije SVOG salona (potvrdi/zavrsi/otkazi)
        //  - klijent (vlasnik): smije samo otkazati svoju
        var isOwner = reservation.ClientId == _currentUser.Id;
        if (!_currentUser.IsAdmin)
        {
            var mySalon = await _db.Hairdressers.AsNoTracking()
                .Where(h => h.UserId == _currentUser.Id)
                .Select(h => (int?)h.SalonId)
                .FirstOrDefaultAsync();
            var isSalonStaff = mySalon != null && reservation.Service.SalonId == mySalon;

            if (isSalonStaff)
            {
                // frizer svog salona - dozvoljeni svi prelazi (state machine dodatno validira)
            }
            else if (isOwner)
            {
                if (target != ReservationStatus.Cancelled)
                    throw new ForbiddenException("Klijent moze samo otkazati rezervaciju.");
            }
            else
            {
                throw new ForbiddenException("Nemate pristup ovoj rezervaciji.");
            }
        }

        // Provjera dozvoljenog prelaza kroz centralnu state machine.
        ReservationStateMachine.EnsureTransition(reservation.Status, target);

        if (target == ReservationStatus.Cancelled && await _db.Payments.AnyAsync(p =>
                p.ReservationId == id && p.Status == PaymentStatus.Completed))
            throw new ConflictException("Prije otkazivanja placene rezervacije potrebno je izvrsiti povrat.");

        // Otkazivanje/odbijanje zahtijeva razlog (upute 7).
        if (target == ReservationStatus.Cancelled && string.IsNullOrWhiteSpace(req.Reason))
            throw new ValidationException("Razlog otkazivanja je obavezan.");

        var action = target switch
        {
            ReservationStatus.Confirmed => AuditAction.Confirmed,
            ReservationStatus.Cancelled => AuditAction.Cancelled,
            ReservationStatus.Completed => AuditAction.Completed,
            _ => AuditAction.Confirmed
        };

        reservation.Status = target;
        reservation.StatusReason = req.Reason;
        AddAudit(reservation.Id, _currentUser.Id, action, req.Reason ?? $"Status promijenjen u {target}.");
        await NotifyAsync(reservation.ClientId, $"Rezervacija: {target}",
            $"Status vase rezervacije za '{reservation.Service.Name}' je sada: {target}." +
            (req.Reason is not null ? $" Razlog: {req.Reason}" : ""));
        await _db.SaveChangesAsync();
        await tx.CommitAsync();

        return await GetByIdInternal(reservation.Id);
    }

    public async Task<IReadOnlyList<AvailableSlotDto>> GetAvailableSlotsAsync(
        int hairdresserId, int serviceId, DateOnly date)
    {
        var service = await _db.Services.FirstOrDefaultAsync(s => s.Id == serviceId)
                      ?? throw new NotFoundException("Usluga", serviceId);

        await EnsureServiceAvailableAsync(service, hairdresserId);

        var workingHour = await _db.WorkingHours.AsNoTracking()
            .FirstOrDefaultAsync(w => w.HairdresserId == hairdresserId && w.DayOfWeek == date.DayOfWeek);

        if (workingHour is null || workingHour.IsDayOff)
            return new List<AvailableSlotDto>();

        // Postojece aktivne rezervacije tog dana (za taj termin).
        var dayStart = SalonLocalTimeToUtc(date, TimeOnly.MinValue);
        var dayEnd = SalonLocalTimeToUtc(date.AddDays(1), TimeOnly.MinValue);
        var busy = await _db.Reservations.AsNoTracking()
            .Where(r => r.HairdresserId == hairdresserId
                     && r.Status != ReservationStatus.Cancelled
                     && r.StartTime < dayEnd && r.EndTime > dayStart)
            .Select(r => new { r.StartTime, r.EndTime })
            .ToListAsync();

        var slots = new List<AvailableSlotDto>();
        var cursor = SalonLocalTimeToUtc(date, workingHour.StartTime);
        var closing = SalonLocalTimeToUtc(date, workingHour.EndTime, endBoundary: true);
        var duration = TimeSpan.FromMinutes(service.DurationMinutes);

        while (cursor.Add(duration) <= closing)
        {
            var slotEnd = cursor.Add(duration);
            var overlaps = busy.Any(b => cursor < b.EndTime && slotEnd > b.StartTime);
            if (!overlaps && cursor > DateTime.UtcNow)
                slots.Add(new AvailableSlotDto { StartTime = cursor, EndTime = slotEnd });

            cursor = cursor.AddMinutes(service.DurationMinutes);
        }

        return slots;
    }

    // ---------- helpers ----------

    private IQueryable<Reservation> BaseQuery() =>
        _db.Reservations.AsNoTracking()
            .Include(r => r.Client)
            .Include(r => r.Service).ThenInclude(s => s.Salon)
            .Include(r => r.Hairdresser).ThenInclude(h => h.User)
            .Include(r => r.AuditLogs).ThenInclude(a => a.PerformedByUser)
            .Include(r => r.Review)
            .Include(r => r.Payment);

    private async Task<ReservationDto> GetByIdInternal(int id)
    {
        var r = await BaseQuery().FirstAsync(x => x.Id == id);
        return Map(r);
    }

    private async Task<PagedResult<ReservationDto>> PageAsync(IQueryable<Reservation> q, PagedQuery query)
    {
        var total = await q.CountAsync();
        var items = await q.OrderByDescending(r => r.StartTime).ThenByDescending(r => r.Id)
            .Skip(query.Skip).Take(query.PageSize).ToListAsync();
        return new PagedResult<ReservationDto>
        {
            Items = items.Select(Map).ToList(),
            TotalCount = total, Page = query.Page, PageSize = query.PageSize
        };
    }

    private async Task EnsureServiceAvailableAsync(Service service, int hairdresserId)
    {
        var available = service.IsActive && await _db.Hairdressers.AnyAsync(h =>
            h.Id == hairdresserId && h.SalonId == service.SalonId &&
            h.VerificationStatus == VerificationStatus.Approved &&
            h.Salon.VerificationStatus == VerificationStatus.Approved &&
            (!h.HairdresserServices.Any() || h.HairdresserServices.Any(link => link.ServiceId == service.Id)));
        if (!available)
            throw new BusinessException("Odabrana usluga nije dostupna kod ovog frizera.");
    }

    private async Task EnsureNoOverlap(int hairdresserId, DateTime start, DateTime end)
    {
        var overlap = await _db.Reservations.AnyAsync(r =>
            r.HairdresserId == hairdresserId &&
            r.Status != ReservationStatus.Cancelled &&
            r.StartTime < end && r.EndTime > start);

        if (overlap)
            throw new ConflictException("Odabrani termin je vec zauzet. Odaberite drugi.");
    }

    private async Task EnsureWithinWorkingHours(int hairdresserId, DateTime start, DateTime end)
    {
        var localStart = TimeZoneInfo.ConvertTimeFromUtc(start, SalonTimeZone);
        var wh = await _db.WorkingHours.AsNoTracking()
            .FirstOrDefaultAsync(w => w.HairdresserId == hairdresserId && w.DayOfWeek == localStart.DayOfWeek);

        if (wh is null || wh.IsDayOff)
            throw new BusinessException("Frizer ne radi u odabranom terminu.");

        var day = DateOnly.FromDateTime(localStart);
        var opening = SalonLocalTimeToUtc(day, wh.StartTime);
        var closing = SalonLocalTimeToUtc(day, wh.EndTime, endBoundary: true);
        if (start < opening || end > closing)
            throw new BusinessException(
                $"Termin je izvan radnog vremena frizera ({wh.StartTime:HH\\:mm}-{wh.EndTime:HH\\:mm}).");
    }

    private void AddAudit(int reservationId, int userId, AuditAction action, string desc) =>
        _db.AuditLogs.Add(new AuditLog
        {
            ReservationId = reservationId,
            PerformedByUserId = userId,
            Action = action,
            Description = desc
        });

    private async Task NotifyAsync(int userId, string title, string text)
    {
        _db.Notifications.Add(new Notification { UserId = userId, Title = title, Text = text });
        var email = await _db.Users.Where(u => u.Id == userId).Select(u => u.Email).FirstOrDefaultAsync();
        if (!string.IsNullOrEmpty(email))
            _outbox.Enqueue(new NotificationMessage(userId, email, title, text));
    }

    private static ReservationDto Map(Reservation r) => new()
    {
        Id = r.Id,
        ClientId = r.ClientId,
        ClientName = $"{r.Client.FirstName} {r.Client.LastName}",
        HairdresserId = r.HairdresserId,
        HairdresserName = $"{r.Hairdresser.User.FirstName} {r.Hairdresser.User.LastName}",
        ServiceId = r.ServiceId,
        ServiceName = r.Service.Name,
        SalonName = r.Service.Salon.Name,
        StartTime = r.StartTime,
        EndTime = r.EndTime,
        Price = r.Price,
        Status = r.Status.ToString(),
        StatusReason = r.StatusReason,
        CanReview = r.Status == ReservationStatus.Completed && r.Review == null,
        CreatedAt = r.CreatedAt,
        LastActionBy = LatestActionUser(r),
        AuditSummary = BuildAuditSummary(r),
        IsPaid = r.Payment != null && r.Payment.Status == PaymentStatus.Completed
    };

    /// <summary>Ime korisnika koji je izvrsio zadnju audit akciju.</summary>
    private static string? LatestActionUser(Reservation r)
    {
        var last = r.AuditLogs?.OrderByDescending(a => a.PerformedAt).FirstOrDefault();
        if (last?.PerformedByUser == null) return null;
        return $"{last.PerformedByUser.FirstName} {last.PerformedByUser.LastName}";
    }

    /// <summary>Kolona "Odobrio / razlog" (upute 7.2): npr. "Odobrio: Amela H." ili "Odbio: Edin M. - Razlog: ...".</summary>
    private static string? BuildAuditSummary(Reservation r)
    {
        var last = r.AuditLogs?.OrderByDescending(a => a.PerformedAt).FirstOrDefault();
        if (last == null) return null;
        var who = last.PerformedByUser == null
            ? ""
            : $"{last.PerformedByUser.FirstName} {last.PerformedByUser.LastName}";

        return last.Action switch
        {
            AuditAction.Confirmed => $"Odobrio: {who}",
            AuditAction.Rejected => $"Odbio: {who}" + (string.IsNullOrEmpty(r.StatusReason) ? "" : $" - Razlog: {r.StatusReason}"),
            AuditAction.Cancelled => $"Otkazao: {who}" + (string.IsNullOrEmpty(r.StatusReason) ? "" : $" - Razlog: {r.StatusReason}"),
            AuditAction.Completed => $"Zavrsio: {who}",
            AuditAction.Created => $"Kreirao: {who}",
            _ => who
        };
    }
}
