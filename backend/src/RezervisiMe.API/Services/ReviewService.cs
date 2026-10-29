using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IReviewService
{
    Task<IReadOnlyList<ReviewDto>> GetForSalonAsync(int salonId);
    Task<ReviewDto> CreateAsync(CreateReviewRequest req);
}

public class ReviewService : IReviewService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;

    public ReviewService(ApplicationDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<ReviewDto>> GetForSalonAsync(int salonId)
    {
        return await _db.Reviews.AsNoTracking()
            .Where(r => r.SalonId == salonId)
            .Include(r => r.Client)
            .Include(r => r.ReviewTags).ThenInclude(rt => rt.Tag)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new ReviewDto
            {
                Id = r.Id,
                ReservationId = r.ReservationId,
                SalonId = r.SalonId,
                ClientName = $"{r.Client.FirstName} {r.Client.LastName}",
                Rating = r.Rating,
                Comment = r.Comment,
                CreatedAt = r.CreatedAt,
                Tags = r.ReviewTags.Select(rt => rt.Tag.Name).ToList()
            })
            .ToListAsync();
    }

    public async Task<ReviewDto> CreateAsync(CreateReviewRequest req)
    {
        var userId = _currentUser.Id;

        var reservation = await _db.Reservations
            .Include(r => r.Service)
            .FirstOrDefaultAsync(r => r.Id == req.ReservationId)
            ?? throw new NotFoundException("Rezervacija", req.ReservationId);

        if (reservation.ClientId != userId)
            throw new ForbiddenException("Mozete recenzirati samo vlastite rezervacije.");

        // Ne recenzirati prije zavrsetka (upute 7).
        if (reservation.Status != ReservationStatus.Completed)
            throw new BusinessException("Recenzija je moguca tek nakon zavrsenog termina.");

        if (await _db.Reviews.AnyAsync(r => r.ReservationId == req.ReservationId))
            throw new ConflictException("Rezervacija je vec recenzirana.");

        var salonId = await _db.Services.Where(s => s.Id == reservation.ServiceId)
            .Select(s => s.SalonId).FirstAsync();

        var review = new Review
        {
            ReservationId = reservation.Id,
            ClientId = userId,
            SalonId = salonId,
            Rating = req.Rating,
            Comment = req.Comment
        };

        // Validne oznake
        if (req.TagIds.Count > 0)
        {
            var validTagIds = await _db.Tags.Where(t => req.TagIds.Contains(t.Id))
                .Select(t => t.Id).ToListAsync();
            foreach (var tagId in validTagIds)
                review.ReviewTags.Add(new ReviewTag { TagId = tagId });
        }

        _db.Reviews.Add(review);
        await _db.SaveChangesAsync();

        return (await GetForSalonAsync(salonId)).First(r => r.Id == review.Id);
    }
}
