using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface ISalonService
{
    Task<PagedResult<SalonDto>> GetAsync(PagedQuery query, int? cityId, bool onlyApproved);
    Task<SalonDto> GetByIdAsync(int id);
    Task<SalonDto> CreateAsync(SalonUpsertRequest req);
    Task<SalonDto> UpdateAsync(int id, SalonUpsertRequest req);
    Task DeleteAsync(int id);
    Task<SalonDto> VerifyAsync(int id, SalonVerifyRequest req);
}

public class SalonService : ISalonService
{
    private readonly ApplicationDbContext _db;
    public SalonService(ApplicationDbContext db) => _db = db;

    public async Task<PagedResult<SalonDto>> GetAsync(PagedQuery query, int? cityId, bool onlyApproved)
    {
        var q = _db.Salons.AsNoTracking()
            .Include(s => s.City)
            .Include(s => s.Images)
            .Include(s => s.Reviews)
            .AsQueryable();

        if (onlyApproved)
            q = q.Where(s => s.VerificationStatus == VerificationStatus.Approved);

        if (cityId is not null)
            q = q.Where(s => s.CityId == cityId);

        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(s => s.Name.Contains(query.Search) || s.Address.Contains(query.Search));

        var total = await q.CountAsync();

        // Projekcija se radi na bazi; AvgRating se racuna u istom upitu (bez N+1).
        var items = await q.OrderByDescending(s => s.Reviews.Count)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(s => new SalonDto
            {
                Id = s.Id,
                Name = s.Name,
                Address = s.Address,
                Description = s.Description,
                ImageUrl = s.ImageUrl,
                Latitude = s.Latitude,
                Longitude = s.Longitude,
                CityId = s.CityId,
                CityName = s.City.Name,
                VerificationStatus = s.VerificationStatus.ToString(),
                AverageRating = s.Reviews.Any() ? s.Reviews.Average(r => r.Rating) : 0,
                ReviewCount = s.Reviews.Count,
                ImageUrls = s.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).ToList()
            })
            .ToListAsync();

        return new PagedResult<SalonDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<SalonDto> GetByIdAsync(int id)
    {
        var dto = await _db.Salons.AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new SalonDto
            {
                Id = s.Id,
                Name = s.Name,
                Address = s.Address,
                Description = s.Description,
                ImageUrl = s.ImageUrl,
                Latitude = s.Latitude,
                Longitude = s.Longitude,
                CityId = s.CityId,
                CityName = s.City.Name,
                VerificationStatus = s.VerificationStatus.ToString(),
                AverageRating = s.Reviews.Any() ? s.Reviews.Average(r => r.Rating) : 0,
                ReviewCount = s.Reviews.Count,
                ImageUrls = s.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).ToList()
            })
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Salon", id);

        return dto;
    }

    public async Task<SalonDto> CreateAsync(SalonUpsertRequest req)
    {
        await EnsureCityExists(req.CityId);

        var salon = new Salon
        {
            Name = req.Name,
            Address = req.Address,
            Description = req.Description,
            ImageUrl = req.ImageUrl,
            Latitude = req.Latitude,
            Longitude = req.Longitude,
            CityId = req.CityId,
            VerificationStatus = VerificationStatus.Pending
        };
        _db.Salons.Add(salon);
        await _db.SaveChangesAsync();
        return await GetByIdAsync(salon.Id);
    }

    public async Task<SalonDto> UpdateAsync(int id, SalonUpsertRequest req)
    {
        var salon = await _db.Salons.FindAsync(id) ?? throw new NotFoundException("Salon", id);
        await EnsureCityExists(req.CityId);

        salon.Name = req.Name;
        salon.Address = req.Address;
        salon.Description = req.Description;
        salon.ImageUrl = req.ImageUrl;
        salon.Latitude = req.Latitude;
        salon.Longitude = req.Longitude;
        salon.CityId = req.CityId;

        await _db.SaveChangesAsync();
        return await GetByIdAsync(salon.Id);
    }

    public async Task DeleteAsync(int id)
    {
        var salon = await _db.Salons.FindAsync(id) ?? throw new NotFoundException("Salon", id);

        // Soft delete (upute 3.1) - ne brisemo fizicki dok salon ima aktivne rezervacije.
        var hasActive = await _db.Reservations
            .AnyAsync(r => r.Hairdresser.SalonId == id &&
                           (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed));
        if (hasActive)
            throw new ConflictException("Salon ima aktivne rezervacije i ne moze biti obrisan.");

        salon.IsDeleted = true;
        await _db.SaveChangesAsync();
    }

    public async Task<SalonDto> VerifyAsync(int id, SalonVerifyRequest req)
    {
        var salon = await _db.Salons.FindAsync(id) ?? throw new NotFoundException("Salon", id);

        if (!req.Approve && string.IsNullOrWhiteSpace(req.RejectionReason))
            throw new ValidationException("Razlog odbijanja je obavezan.");

        salon.VerificationStatus = req.Approve ? VerificationStatus.Approved : VerificationStatus.Rejected;
        salon.RejectionReason = req.Approve ? null : req.RejectionReason;

        await _db.SaveChangesAsync();
        return await GetByIdAsync(salon.Id);
    }

    private async Task EnsureCityExists(int cityId)
    {
        if (!await _db.Cities.AnyAsync(c => c.Id == cityId))
            throw new ValidationException("Odabrani grad ne postoji.");
    }
}
