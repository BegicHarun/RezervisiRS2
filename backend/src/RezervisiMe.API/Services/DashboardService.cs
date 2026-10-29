using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IDashboardService
{
    Task<DashboardDto> GetAsync();
}

/// <summary>
/// Racuna presjek poslovanja za desktop dashboard (upute 7.1).
/// Svi podaci su stvarni (iz rezervacija), ne fake vrijednosti.
/// </summary>
public class DashboardService : IDashboardService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;
    public DashboardService(ApplicationDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<DashboardDto> GetAsync()
    {
        var now = DateTime.UtcNow;
        var today = new DateTime(now.Year, now.Month, now.Day, 0, 0, 0, DateTimeKind.Utc);
        var weekAgo = today.AddDays(-6); // zadnjih 7 dana ukljucujuci danas
        var prevWeekStart = weekAgo.AddDays(-7);

        // Frizer vidi statistiku svog salona; admin globalno.
        int? mySalon = null;
        if (!_currentUser.IsAdmin)
        {
            var userId = _currentUser.Id;
            mySalon = await _db.Hairdressers.AsNoTracking()
                .Where(h => h.UserId == userId)
                .Select(h => (int?)h.SalonId)
                .FirstOrDefaultAsync();
        }

        var baseQuery = _db.Reservations.AsNoTracking().Include(r => r.Service).AsQueryable();
        if (mySalon != null)
            baseQuery = baseQuery.Where(r => r.Service.SalonId == mySalon);

        var all = await baseQuery.ToListAsync();

        var dto = new DashboardDto();

        // KPI: ukupno rezervacija (svih vremena)
        dto.TotalReservations = all.Count;

        // KPI: prihod (zavrsene rezervacije)
        dto.TotalRevenue = all.Where(r => r.Status == ReservationStatus.Completed)
            .Sum(r => r.Price);

        // KPI: novi klijenti (registrovani u zadnjih 7 dana) - preko rezervacija
        dto.NewClients = all.Where(r => r.CreatedAt >= weekAgo)
            .Select(r => r.ClientId).Distinct().Count();

        // KPI: popunjenost (potvrdjene+zavrsene / ukupno), gruba mjera
        var activeCount = all.Count(r =>
            r.Status == ReservationStatus.Confirmed || r.Status == ReservationStatus.Completed);
        dto.OccupancyRate = all.Count == 0 ? 0 : Math.Round(activeCount * 100.0 / all.Count, 1);

        // Trend: ova sedmica vs prethodna
        var thisWeek = all.Count(r => r.CreatedAt >= weekAgo);
        var prevWeek = all.Count(r => r.CreatedAt >= prevWeekStart && r.CreatedAt < weekAgo);
        dto.ReservationsTrend = prevWeek == 0 ? 0 : Math.Round((thisWeek - prevWeek) * 100.0 / prevWeek, 1);

        var thisWeekRev = all.Where(r => r.CreatedAt >= weekAgo && r.Status == ReservationStatus.Completed).Sum(r => r.Price);
        var prevWeekRev = all.Where(r => r.CreatedAt >= prevWeekStart && r.CreatedAt < weekAgo && r.Status == ReservationStatus.Completed).Sum(r => r.Price);
        dto.RevenueTrend = prevWeekRev == 0 ? 0 : Math.Round((double)((thisWeekRev - prevWeekRev) * 100 / prevWeekRev), 1);

        // Bar chart: rezervacije po danu (zadnjih 7 dana)
        string[] dayNames = { "Ned", "Pon", "Uto", "Sri", "Cet", "Pet", "Sub" };
        for (int i = 0; i < 7; i++)
        {
            var day = weekAgo.AddDays(i);
            var next = day.AddDays(1);
            var count = all.Count(r => r.StartTime >= day && r.StartTime < next);
            dto.ReservationsPerDay.Add(new DailyCountDto
            {
                Date = day,
                Label = dayNames[(int)day.DayOfWeek],
                Count = count
            });
        }

        // Donut chart: po statusu
        foreach (var st in Enum.GetValues<ReservationStatus>())
        {
            dto.ReservationsByStatus.Add(new StatusCountDto
            {
                Status = st.ToString(),
                Count = all.Count(r => r.Status == st)
            });
        }

        // Popularne usluge (po broju rezervacija)
        dto.PopularServices = all
            .GroupBy(r => new { r.ServiceId, r.Service.Name })
            .Select(g => new PopularServiceDto
            {
                ServiceId = g.Key.ServiceId,
                ServiceName = g.Key.Name,
                ReservationCount = g.Count(),
                Revenue = g.Where(r => r.Status == ReservationStatus.Completed).Sum(r => r.Price)
            })
            .OrderByDescending(s => s.ReservationCount)
            .Take(5)
            .ToList();

        // Nedavne rezervacije (zadnjih 5)
        var recentIds = all.OrderByDescending(r => r.CreatedAt).Take(5).Select(r => r.Id).ToList();
        var recent = await _db.Reservations.AsNoTracking()
            .Where(r => recentIds.Contains(r.Id))
            .Include(r => r.Client)
            .Include(r => r.Hairdresser).ThenInclude(h => h.User)
            .Include(r => r.Service).ThenInclude(s => s.Salon)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        dto.RecentReservations = recent.Select(r => new ReservationDto
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
            StatusReason = r.StatusReason
        }).ToList();

        return dto;
    }
}
