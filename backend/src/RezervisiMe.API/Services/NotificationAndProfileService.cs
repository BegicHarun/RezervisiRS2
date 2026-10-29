using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface INotificationService
{
    Task<PagedResult<NotificationDto>> GetMineAsync(PagedQuery query);
    Task MarkReadAsync(int id);
    Task<int> UnreadCountAsync();
}

public class NotificationService : INotificationService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;

    public NotificationService(ApplicationDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<PagedResult<NotificationDto>> GetMineAsync(PagedQuery query)
    {
        var userId = _currentUser.Id;
        var q = _db.Notifications.AsNoTracking().Where(n => n.UserId == userId);

        var total = await q.CountAsync();
        var items = await q.OrderByDescending(n => n.CreatedAt)
            .Skip(query.Skip).Take(query.PageSize)
            .Select(n => new NotificationDto
            {
                Id = n.Id, Title = n.Title, Text = n.Text,
                IsRead = n.IsRead, CreatedAt = n.CreatedAt
            })
            .ToListAsync();

        return new PagedResult<NotificationDto>
        { Items = items, TotalCount = total, Page = query.Page, PageSize = query.PageSize };
    }

    public async Task MarkReadAsync(int id)
    {
        var userId = _currentUser.Id;
        var n = await _db.Notifications.FirstOrDefaultAsync(x => x.Id == id)
                ?? throw new NotFoundException("Notifikacija", id);
        if (n.UserId != userId)
            throw new ForbiddenException("Nemate pristup ovoj notifikaciji.");

        n.IsRead = true;
        await _db.SaveChangesAsync();
    }

    public async Task<int> UnreadCountAsync()
    {
        var userId = _currentUser.Id;
        return await _db.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);
    }
}

public interface IProfileService
{
    Task<UserDto> GetMeAsync();
    Task<UserDto> UpdateAsync(UpdateProfileRequest req);
    Task ChangePasswordAsync(ChangePasswordRequest req);
}

public class ProfileService : IProfileService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly UserManager<ApplicationUser> _userManager;

    public ProfileService(
        ApplicationDbContext db,
        ICurrentUser currentUser,
        UserManager<ApplicationUser> userManager)
    {
        _db = db;
        _currentUser = currentUser;
        _userManager = userManager;
    }

    public async Task<UserDto> GetMeAsync()
    {
        var user = await _db.Users.Include(u => u.City)
            .FirstOrDefaultAsync(u => u.Id == _currentUser.Id)
            ?? throw new NotFoundException("Korisnik", _currentUser.Id);

        var roles = await _userManager.GetRolesAsync(user);
        return Map(user, roles);
    }

    public async Task<UserDto> UpdateAsync(UpdateProfileRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == _currentUser.Id)
            ?? throw new NotFoundException("Korisnik", _currentUser.Id);

        if (req.CityId is not null && !await _db.Cities.AnyAsync(c => c.Id == req.CityId))
            throw new ValidationException("Odabrani grad ne postoji.");

        user.FirstName = req.FirstName;
        user.LastName = req.LastName;
        user.CityId = req.CityId;
        user.ImageUrl = req.ImageUrl;
        await _db.SaveChangesAsync();

        return await GetMeAsync();
    }

    public async Task ChangePasswordAsync(ChangePasswordRequest req)
    {
        var user = await _userManager.FindByIdAsync(_currentUser.Id.ToString())
            ?? throw new NotFoundException("Korisnik", _currentUser.Id);

        // Korisnik mijenja vlastitu lozinku -> potvrda stare lozinke (upute 4).
        var result = await _userManager.ChangePasswordAsync(user, req.CurrentPassword, req.NewPassword);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => e.Description));
    }

    private static UserDto Map(ApplicationUser u, IList<string> roles) => new()
    {
        Id = u.Id,
        Username = u.UserName!,
        Email = u.Email!,
        FirstName = u.FirstName,
        LastName = u.LastName,
        ImageUrl = u.ImageUrl,
        CityName = u.City?.Name,
        Roles = roles.ToList()
    };
}
