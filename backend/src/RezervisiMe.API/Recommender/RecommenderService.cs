using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Recommender;

public class RecommendationDto
{
    public int SalonId { get; set; }
    public string SalonName { get; set; } = null!;
    public string CityName { get; set; } = null!;
    public string? ImageUrl { get; set; }
    public double AverageRating { get; set; }
    public int ReviewCount { get; set; }
    public double Score { get; set; }

    /// <summary>Objasnjenje zasto je salon preporucen (upute 2.4 - objasnjive preporuke).</summary>
    public string Explanation { get; set; } = null!;
}

public interface IRecommenderService
{
    Task<IReadOnlyList<RecommendationDto>> GetRecommendationsAsync(int take = 5);
}

/// <summary>
/// Hibridni recommender: kombinuje content-based (kategorije koje korisnik pretrazuje/rezervise)
/// i popularity-based (prosjecna ocjena + broj recenzija) signale.
/// Svi signali se STVARNO koriste u scoringu (upute 2.4) i temelje se na stvarnim podacima
/// (SearchHistory, rezervacije), ne na fake vrijednostima.
/// </summary>
public class RecommenderService : IRecommenderService
{
    private readonly ApplicationDbContext _db;
    private readonly ICurrentUser _currentUser;

    // Tezine signala u konacnom scoreu.
    private const double ContentWeight = 0.6;
    private const double PopularityWeight = 0.4;

    public RecommenderService(ApplicationDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<RecommendationDto>> GetRecommendationsAsync(int take = 5)
    {
        var userId = _currentUser.Id;

        // ---- CONTENT-BASED signal ----
        // Kategorije koje korisnika zanimaju, iz stvarne historije pretrage i rezervacija.
        var searchedCategories = await _db.SearchHistory.AsNoTracking()
            .Where(sh => sh.UserId == userId && sh.ServiceCategoryId != null)
            .Select(sh => sh.ServiceCategoryId!.Value)
            .ToListAsync();

        var reservedCategories = await _db.Reservations.AsNoTracking()
            .Where(r => r.ClientId == userId)
            .Select(r => r.Service.ServiceCategoryId)
            .ToListAsync();

        var interestCategories = searchedCategories.Concat(reservedCategories)
            .GroupBy(c => c)
            .ToDictionary(g => g.Key, g => g.Count());

        // Saloni koje je korisnik vec rezervisao - da ih ne preporucujemo ponovo kao "novo".
        var visitedSalonIds = await _db.Reservations.AsNoTracking()
            .Where(r => r.ClientId == userId)
            .Select(r => r.Service.SalonId)
            .Distinct()
            .ToListAsync();

        // Kandidati: verifikovani saloni + agregati (jedan GroupBy-stil upit, bez N+1).
        var candidates = await _db.Salons.AsNoTracking()
            .Where(s => s.VerificationStatus == VerificationStatus.Approved)
            .Select(s => new
            {
                s.Id,
                s.Name,
                s.ImageUrl,
                CityName = s.City.Name,
                ReviewCount = s.Reviews.Count,
                AvgRating = s.Reviews.Any() ? s.Reviews.Average(r => r.Rating) : 0.0,
                CategoryIds = s.Services.Select(sv => sv.ServiceCategoryId).Distinct().ToList()
            })
            .ToListAsync();

        if (candidates.Count == 0)
            return new List<RecommendationDto>();

        var maxReviews = Math.Max(1, candidates.Max(c => c.ReviewCount));

        var results = new List<RecommendationDto>();
        foreach (var c in candidates)
        {
            // Content score: koliko se salonove kategorije poklapaju s interesima korisnika.
            double contentScore = 0;
            var matchedInterest = 0;
            if (interestCategories.Count > 0)
            {
                var totalInterest = interestCategories.Values.Sum();
                matchedInterest = c.CategoryIds
                    .Where(interestCategories.ContainsKey)
                    .Sum(id => interestCategories[id]);
                contentScore = totalInterest == 0 ? 0 : (double)matchedInterest / totalInterest;
            }

            // Popularity score: normalizovana ocjena (0-1) i normalizovan broj recenzija (0-1).
            var ratingScore = c.AvgRating / 5.0;
            var volumeScore = (double)c.ReviewCount / maxReviews;
            var popularityScore = (ratingScore * 0.7) + (volumeScore * 0.3);

            var finalScore = (contentScore * ContentWeight) + (popularityScore * PopularityWeight);

            // Blagi bonus ako korisnik jos nije bio u tom salonu (otkrivanje novog).
            if (!visitedSalonIds.Contains(c.Id))
                finalScore += 0.05;

            results.Add(new RecommendationDto
            {
                SalonId = c.Id,
                SalonName = c.Name,
                CityName = c.CityName,
                ImageUrl = c.ImageUrl,
                AverageRating = Math.Round(c.AvgRating, 2),
                ReviewCount = c.ReviewCount,
                Score = Math.Round(finalScore, 4),
                Explanation = BuildExplanation(matchedInterest, c.AvgRating, c.ReviewCount, !visitedSalonIds.Contains(c.Id))
            });
        }

        return results.OrderByDescending(r => r.Score).Take(take).ToList();
    }

    private static string BuildExplanation(int matchedInterest, double avgRating, int reviewCount, bool isNew)
    {
        var parts = new List<string>();
        if (matchedInterest > 0)
            parts.Add("odgovara uslugama koje ste pretrazivali/rezervisali");
        if (avgRating >= 4.0 && reviewCount > 0)
            parts.Add($"visoko ocijenjen ({avgRating:0.0}/5 iz {reviewCount} recenzija)");
        else if (reviewCount > 0)
            parts.Add($"ocjena {avgRating:0.0}/5");
        if (isNew)
            parts.Add("jos ga niste posjetili");

        return parts.Count == 0
            ? "Preporuceno na osnovu opste popularnosti."
            : "Preporuceno jer: " + string.Join("; ", parts) + ".";
    }
}
