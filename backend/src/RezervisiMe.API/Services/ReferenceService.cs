using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IReferenceService
{
    Task<PagedResult<CityDto>> GetCitiesAsync(PagedQuery query);
    Task<CityDto> CreateCityAsync(CityUpsertRequest req);
    Task<CityDto> UpdateCityAsync(int id, CityUpsertRequest req);
    Task DeleteCityAsync(int id);

    Task<PagedResult<ServiceCategoryDto>> GetCategoriesAsync(PagedQuery query);
    Task<ServiceCategoryDto> CreateCategoryAsync(ServiceCategoryUpsertRequest req);
    Task<ServiceCategoryDto> UpdateCategoryAsync(int id, ServiceCategoryUpsertRequest req);
    Task DeleteCategoryAsync(int id);

    Task<IReadOnlyList<TagDto>> GetTagsAsync();
    Task<PagedResult<TagDto>> GetTagPageAsync(PagedQuery query);
    Task<TagDto> SaveTagAsync(int? id, TagUpsertRequest request);
    Task DeleteTagAsync(int id);
}

public class ReferenceService : IReferenceService
{
    private readonly ApplicationDbContext _db;
    public ReferenceService(ApplicationDbContext db) => _db = db;

    // ---- Cities ----

    public async Task<PagedResult<CityDto>> GetCitiesAsync(PagedQuery query)
    {
        var q = _db.Cities.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(c => c.Name.Contains(query.Search) || c.Region.Contains(query.Search));

        var total = await q.CountAsync();
        var items = await q.OrderBy(c => c.Name)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(c => new CityDto { Id = c.Id, Name = c.Name, Region = c.Region })
            .ToListAsync();

        return new PagedResult<CityDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<CityDto> CreateCityAsync(CityUpsertRequest req)
    {
        var city = new City { Name = req.Name, Region = req.Region };
        _db.Cities.Add(city);
        await _db.SaveChangesAsync();
        return new CityDto { Id = city.Id, Name = city.Name, Region = city.Region };
    }

    public async Task<CityDto> UpdateCityAsync(int id, CityUpsertRequest req)
    {
        var city = await _db.Cities.FindAsync(id) ?? throw new NotFoundException("Grad", id);
        city.Name = req.Name;
        city.Region = req.Region;
        await _db.SaveChangesAsync();
        return new CityDto { Id = city.Id, Name = city.Name, Region = city.Region };
    }

    public async Task DeleteCityAsync(int id)
    {
        var city = await _db.Cities.FindAsync(id) ?? throw new NotFoundException("Grad", id);

        // Brisanje onemoguceno ako grad koriste korisnici ili saloni (upute 3.1).
        var inUse = await _db.Users.AnyAsync(u => u.CityId == id)
                    || await _db.Salons.IgnoreQueryFilters().AnyAsync(s => s.CityId == id);
        if (inUse)
            throw new ConflictException("Grad se ne moze obrisati jer ga koriste korisnici ili saloni.");

        _db.Cities.Remove(city);
        await _db.SaveChangesAsync();
    }

    // ---- Categories ----

    public async Task<PagedResult<ServiceCategoryDto>> GetCategoriesAsync(PagedQuery query)
    {
        var q = _db.ServiceCategories.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(query.Search))
            q = q.Where(c => c.Name.Contains(query.Search));

        var total = await q.CountAsync();
        var items = await q.OrderBy(c => c.Name)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(c => new ServiceCategoryDto { Id = c.Id, Name = c.Name, IconName = c.IconName })
            .ToListAsync();

        return new PagedResult<ServiceCategoryDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<ServiceCategoryDto> CreateCategoryAsync(ServiceCategoryUpsertRequest req)
    {
        var c = new ServiceCategory { Name = req.Name, IconName = req.IconName };
        _db.ServiceCategories.Add(c);
        await _db.SaveChangesAsync();
        return new ServiceCategoryDto { Id = c.Id, Name = c.Name, IconName = c.IconName };
    }

    public async Task<ServiceCategoryDto> UpdateCategoryAsync(int id, ServiceCategoryUpsertRequest req)
    {
        var c = await _db.ServiceCategories.FindAsync(id) ?? throw new NotFoundException("Kategorija", id);
        c.Name = req.Name;
        c.IconName = req.IconName;
        await _db.SaveChangesAsync();
        return new ServiceCategoryDto { Id = c.Id, Name = c.Name, IconName = c.IconName };
    }

    public async Task DeleteCategoryAsync(int id)
    {
        var c = await _db.ServiceCategories.FindAsync(id) ?? throw new NotFoundException("Kategorija", id);
        var inUse = await _db.Services.IgnoreQueryFilters().AnyAsync(s => s.ServiceCategoryId == id);
        if (inUse)
            throw new ConflictException("Kategorija se ne moze obrisati jer je koriste usluge.");

        _db.ServiceCategories.Remove(c);
        await _db.SaveChangesAsync();
    }

    // ---- Tags ----

    public async Task<IReadOnlyList<TagDto>> GetTagsAsync() =>
        await _db.Tags.AsNoTracking().OrderBy(t => t.Name)
            .Select(t => new TagDto { Id = t.Id, Name = t.Name })
            .ToListAsync();

    public async Task<PagedResult<TagDto>> GetTagPageAsync(PagedQuery query)
    {
        var tags = _db.Tags.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(query.Search))
            tags = tags.Where(t => t.Name.Contains(query.Search));
        var total = await tags.CountAsync();
        var items = await tags.OrderBy(t => t.Name).ThenBy(t => t.Id)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(t => new TagDto { Id = t.Id, Name = t.Name }).ToListAsync();
        return new PagedResult<TagDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task<TagDto> SaveTagAsync(int? id, TagUpsertRequest request)
    {
        var name = request.Name.Trim();
        if (name.Length == 0) throw new ValidationException("Naziv oznake je obavezan.");
        if (await _db.Tags.AnyAsync(t => t.Name == name && (id == null || t.Id != id)))
            throw new ConflictException("Oznaka s tim nazivom vec postoji.");

        var tag = id is int tagId
            ? await _db.Tags.FindAsync(tagId) ?? throw new NotFoundException("Oznaka", tagId)
            : new Tag();
        tag.Name = name;
        if (id is null) _db.Tags.Add(tag);
        await _db.SaveChangesAsync();
        return new TagDto { Id = tag.Id, Name = tag.Name };
    }

    public async Task DeleteTagAsync(int id)
    {
        var tag = await _db.Tags.FindAsync(id) ?? throw new NotFoundException("Oznaka", id);
        if (await _db.ReviewTags.AnyAsync(r => r.TagId == id))
            throw new ConflictException("Oznaka se ne moze obrisati jer je koriste recenzije.");
        _db.Tags.Remove(tag);
        await _db.SaveChangesAsync();
    }
}
