using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IServiceCatalogService
{
    Task<PagedResult<ServiceDto>> GetAsync(PagedQuery query, int? salonId, int? categoryId);
    Task<ServiceDto> GetByIdAsync(int id);
    Task<ServiceDto> CreateAsync(ServiceUpsertRequest req);
    Task<ServiceDto> UpdateAsync(int id, ServiceUpsertRequest req);
    Task DeleteAsync(int id);
}

public class ServiceCatalogService : IServiceCatalogService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;
    public ServiceCatalogService(ApplicationDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    /// <summary>Salon kojem pripada trenutni frizer (null za admina ili ako nije vezan).</summary>
    private async Task<int?> CurrentUserSalonIdAsync()
    {
        if (_currentUser.IsAdmin) return null;
        var userId = _currentUser.Id;
        return await _db.Hairdressers.AsNoTracking()
            .Where(h => h.UserId == userId)
            .Select(h => (int?)h.SalonId)
            .FirstOrDefaultAsync();
    }

    /// <summary>Osigurava da frizer dira samo svoj salon; admin sve.</summary>
    private async Task EnsureCanManage(int salonId)
    {
        if (_currentUser.IsAdmin) return;
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon == null || mySalon != salonId)
            throw new ForbiddenException("Nemate pristup uslugama drugog salona.");
    }

    public async Task<PagedResult<ServiceDto>> GetAsync(PagedQuery query, int? salonId, int? categoryId)
    {
        var q = _db.Services.AsNoTracking()
            .Include(s => s.Salon)
            .Include(s => s.ServiceCategory)
            .AsQueryable();

        // Frizer vidi samo usluge svog salona (ignorise trazeni salonId).
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon != null)
            q = q.Where(s => s.SalonId == mySalon);
        else if (salonId is not null)
            q = q.Where(s => s.SalonId == salonId);

        if (categoryId is not null) q = q.Where(s => s.ServiceCategoryId == categoryId);
        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(s => s.Name.Contains(query.Search));

        var total = await q.CountAsync();
        var items = await q.OrderBy(s => s.Name)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(s => Map(s))
            .ToListAsync();

        return new PagedResult<ServiceDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<ServiceDto> GetByIdAsync(int id)
    {
        var dto = await _db.Services.AsNoTracking()
            .Include(s => s.Salon).Include(s => s.ServiceCategory)
            .Where(s => s.Id == id)
            .Select(s => Map(s))
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Usluga", id);
        return dto;
    }

    public async Task<ServiceDto> CreateAsync(ServiceUpsertRequest req)
    {
        // Frizer moze kreirati samo za svoj salon.
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon != null) req.SalonId = mySalon.Value;
        await EnsureCanManage(req.SalonId);

        await Validate(req);
        var s = new Service
        {
            Name = req.Name,
            Description = req.Description,
            Price = req.Price,
            DurationMinutes = req.DurationMinutes,
            SalonId = req.SalonId,
            ServiceCategoryId = req.ServiceCategoryId,
            IsActive = req.IsActive
        };
        _db.Services.Add(s);
        await _db.SaveChangesAsync();
        return await GetByIdAsync(s.Id);
    }

    public async Task<ServiceDto> UpdateAsync(int id, ServiceUpsertRequest req)
    {
        var s = await _db.Services.FindAsync(id) ?? throw new NotFoundException("Usluga", id);

        // Provjeri vlasnistvo nad POSTOJECOM uslugom i nad ciljnim salonom.
        await EnsureCanManage(s.SalonId);
        var mySalon = await CurrentUserSalonIdAsync();
        if (mySalon != null) req.SalonId = mySalon.Value; // frizer ne moze premjestiti u drugi salon
        await EnsureCanManage(req.SalonId);

        await Validate(req);
        s.Name = req.Name;
        s.Description = req.Description;
        s.Price = req.Price;
        s.DurationMinutes = req.DurationMinutes;
        s.SalonId = req.SalonId;
        s.ServiceCategoryId = req.ServiceCategoryId;
        s.IsActive = req.IsActive;
        await _db.SaveChangesAsync();
        return await GetByIdAsync(s.Id);
    }

    public async Task DeleteAsync(int id)
    {
        var s = await _db.Services.FindAsync(id) ?? throw new NotFoundException("Usluga", id);
        await EnsureCanManage(s.SalonId);

        var hasActive = await _db.Reservations.AnyAsync(r => r.ServiceId == id &&
            (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed));
        if (hasActive)
            throw new ConflictException("Usluga ima aktivne rezervacije i ne moze biti obrisana.");

        s.IsDeleted = true;
        await _db.SaveChangesAsync();
    }

    private async Task Validate(ServiceUpsertRequest req)
    {
        if (!await _db.Salons.AnyAsync(x => x.Id == req.SalonId))
            throw new ValidationException("Odabrani salon ne postoji.");
        if (!await _db.ServiceCategories.AnyAsync(x => x.Id == req.ServiceCategoryId))
            throw new ValidationException("Odabrana kategorija ne postoji.");
    }

    private static ServiceDto Map(Service s) => new()
    {
        Id = s.Id,
        Name = s.Name,
        Description = s.Description,
        Price = s.Price,
        DurationMinutes = s.DurationMinutes,
        SalonId = s.SalonId,
        SalonName = s.Salon.Name,
        ServiceCategoryId = s.ServiceCategoryId,
        ServiceCategoryName = s.ServiceCategory.Name,
        IsActive = s.IsActive
    };
}
