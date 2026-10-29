using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IHairdresserService
{
    Task<IReadOnlyList<HairdresserDto>> GetForSalonAsync(int salonId);
    Task<PagedResult<HairdresserDto>> GetAsync(PagedQuery query, int? salonId);
    Task<HairdresserDto> CreateAsync(HairdresserUpsertRequest req);
    Task<HairdresserDto> CreateWithAccountAsync(HairdresserAccountRequest req);
    Task DeleteAsync(int id);
    Task<HairdresserDto> VerifyAsync(int id, HairdresserVerifyRequest req);
    Task<IReadOnlyList<WorkingHourDto>> GetWorkingHoursAsync(int hairdresserId);
    Task<IReadOnlyList<WorkingHourDto>> SetWorkingHoursAsync(int hairdresserId, List<WorkingHourUpsertRequest> hours);
}

public class HairdresserServiceImpl : IHairdresserService
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ICurrentUser _currentUser;
    public HairdresserServiceImpl(ApplicationDbContext db, UserManager<ApplicationUser> userManager, ICurrentUser currentUser)
    {
        _db = db;
        _userManager = userManager;
        _currentUser = currentUser;
    }

    private async Task<int?> CurrentUserSalonIdAsync()
    {
        if (_currentUser.IsAdmin) return null;
        var userId = _currentUser.Id;
        return await _db.Hairdressers.AsNoTracking()
            .Where(h => h.UserId == userId)
            .Select(h => (int?)h.SalonId)
            .FirstOrDefaultAsync();
    }

    private static readonly string[] DayNames =
        { "Nedjelja", "Ponedjeljak", "Utorak", "Srijeda", "Cetvrtak", "Petak", "Subota" };

    public async Task<IReadOnlyList<HairdresserDto>> GetForSalonAsync(int salonId)
    {
        return await _db.Hairdressers.AsNoTracking()
            .Where(h => h.SalonId == salonId &&
                        h.VerificationStatus == VerificationStatus.Approved)
            .Include(h => h.User)
            .Include(h => h.Salon)
            .Select(h => Map(h))
            .ToListAsync();
    }

    public async Task<PagedResult<HairdresserDto>> GetAsync(PagedQuery query, int? salonId)
    {
        var q = _db.Hairdressers.AsNoTracking()
            .Include(h => h.User).Include(h => h.Salon).AsQueryable();

        // Frizer vidi samo kolege iz svog salona; admin vidi sve.
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon != null)
            q = q.Where(h => h.SalonId == mySalon);
        else if (salonId is not null)
            q = q.Where(h => h.SalonId == salonId);

        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(h => h.User.FirstName.Contains(query.Search)
                          || h.User.LastName.Contains(query.Search)
                          || h.Specialization.Contains(query.Search));

        var total = await q.CountAsync();
        var items = await q.OrderBy(h => h.User.FirstName)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(h => Map(h))
            .ToListAsync();

        return new PagedResult<HairdresserDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<HairdresserDto> CreateAsync(HairdresserUpsertRequest req)
    {
        if (!await _db.Users.AnyAsync(u => u.Id == req.UserId))
            throw new ValidationException("Odabrani korisnik ne postoji.");
        if (!await _db.Salons.AnyAsync(s => s.Id == req.SalonId))
            throw new ValidationException("Odabrani salon ne postoji.");

        var h = new Hairdresser
        {
            UserId = req.UserId,
            SalonId = req.SalonId,
            Specialization = req.Specialization,
            VerificationStatus = VerificationStatus.Pending
        };
        _db.Hairdressers.Add(h);
        await _db.SaveChangesAsync();

        var created = await _db.Hairdressers.AsNoTracking()
            .Include(x => x.User).Include(x => x.Salon)
            .FirstAsync(x => x.Id == h.Id);
        return Map(created);
    }

    /// <summary>
    /// Kreira NOVI korisnicki nalog (rola Frizer) sa loznikom i povezuje ga za salon.
    /// Koristi ga admin iz desktop panela (kredencijali za prijavu frizera).
    /// </summary>
    public async Task<HairdresserDto> CreateWithAccountAsync(HairdresserAccountRequest req)
    {
        if (await _userManager.FindByNameAsync(req.Username) is not null)
            throw new ConflictException("Korisnicko ime je vec zauzeto.");
        if (await _userManager.FindByEmailAsync(req.Email) is not null)
            throw new ConflictException("Email je vec registrovan.");

        var salon = await _db.Salons.FindAsync(req.SalonId)
            ?? throw new ValidationException("Odabrani salon ne postoji.");

        var user = new ApplicationUser
        {
            UserName = req.Username,
            Email = req.Email,
            FirstName = req.FirstName,
            LastName = req.LastName,
            CityId = salon.CityId,
            EmailConfirmed = true
        };

        var result = await _userManager.CreateAsync(user, req.Password);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => e.Description));

        await _userManager.AddToRoleAsync(user, Roles.Frizer);

        var h = new Hairdresser
        {
            UserId = user.Id,
            SalonId = req.SalonId,
            Specialization = req.Specialization,
            // Admin rucno kreira -> odmah odobren.
            VerificationStatus = VerificationStatus.Approved
        };
        _db.Hairdressers.Add(h);
        await _db.SaveChangesAsync();

        var created = await _db.Hairdressers.AsNoTracking()
            .Include(x => x.User).Include(x => x.Salon)
            .FirstAsync(x => x.Id == h.Id);
        return Map(created);
    }

    public async Task DeleteAsync(int id)
    {
        var h = await _db.Hairdressers.FindAsync(id)
                ?? throw new NotFoundException("Frizer", id);
        var hasActive = await _db.Reservations.AnyAsync(r =>
            r.HairdresserId == id &&
            (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed));
        if (hasActive)
            throw new ConflictException("Frizer ima aktivne rezervacije i ne moze biti obrisan.");

        h.IsDeleted = true;
        await _db.SaveChangesAsync();
    }

    public async Task<HairdresserDto> VerifyAsync(int id, HairdresserVerifyRequest req)
    {
        var h = await _db.Hairdressers
            .Include(x => x.User).Include(x => x.Salon)
            .FirstOrDefaultAsync(x => x.Id == id)
            ?? throw new NotFoundException("Frizer", id);

        if (!req.Approve && string.IsNullOrWhiteSpace(req.RejectionReason))
            throw new ValidationException("Razlog odbijanja je obavezan.");

        h.VerificationStatus = req.Approve ? VerificationStatus.Approved : VerificationStatus.Rejected;
        h.RejectionReason = req.Approve ? null : req.RejectionReason;
        await _db.SaveChangesAsync();
        return Map(h);
    }

    public async Task<IReadOnlyList<WorkingHourDto>> GetWorkingHoursAsync(int hairdresserId)
    {
        if (!await _db.Hairdressers.AnyAsync(h => h.Id == hairdresserId))
            throw new NotFoundException("Frizer", hairdresserId);

        return await _db.WorkingHours.AsNoTracking()
            .Where(w => w.HairdresserId == hairdresserId)
            .OrderBy(w => w.DayOfWeek)
            .Select(w => MapWh(w))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<WorkingHourDto>> SetWorkingHoursAsync(
        int hairdresserId, List<WorkingHourUpsertRequest> hours)
    {
        var h = await _db.Hairdressers.FindAsync(hairdresserId)
                ?? throw new NotFoundException("Frizer", hairdresserId);

        // Frizer moze mijenjati radno vrijeme samo za frizere svog salona.
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon != null && h.SalonId != mySalon)
            throw new ForbiddenException("Nemate pristup frizerima drugog salona.");

        var existing = _db.WorkingHours.Where(w => w.HairdresserId == hairdresserId);
        _db.WorkingHours.RemoveRange(existing);

        foreach (var item in hours)
        {
            if (!TimeOnly.TryParse(item.StartTime, out var start))
                throw new ValidationException($"Neispravno vrijeme: {item.StartTime}");
            if (!TimeOnly.TryParse(item.EndTime, out var end))
                throw new ValidationException($"Neispravno vrijeme: {item.EndTime}");
            if (!item.IsDayOff && end <= start)
                throw new ValidationException("Kraj radnog vremena mora biti nakon pocetka.");

            _db.WorkingHours.Add(new WorkingHour
            {
                HairdresserId = hairdresserId,
                DayOfWeek = (DayOfWeek)item.DayOfWeek,
                StartTime = start,
                EndTime = end,
                IsDayOff = item.IsDayOff
            });
        }
        await _db.SaveChangesAsync();
        return await GetWorkingHoursAsync(hairdresserId);
    }

    private static WorkingHourDto MapWh(WorkingHour w) => new()
    {
        Id = w.Id,
        DayOfWeek = (int)w.DayOfWeek,
        DayName = DayNames[(int)w.DayOfWeek],
        StartTime = w.StartTime.ToString("HH\\:mm"),
        EndTime = w.EndTime.ToString("HH\\:mm"),
        IsDayOff = w.IsDayOff
    };

    private static HairdresserDto Map(Hairdresser h) => new()
    {
        Id = h.Id,
        UserId = h.UserId,
        FullName = $"{h.User.FirstName} {h.User.LastName}",
        Specialization = h.Specialization,
        SalonId = h.SalonId,
        SalonName = h.Salon.Name,
        VerificationStatus = h.VerificationStatus.ToString()
    };
}
