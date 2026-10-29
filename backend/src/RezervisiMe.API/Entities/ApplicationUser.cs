using Microsoft.AspNetCore.Identity;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Korisnik sistema (klijent, frizer ili administrator).
/// Nasljedjuje IdentityUser<int> - koristimo int primarni kljuc radi konzistentnosti sa ostalim tabelama.
/// </summary>
public class ApplicationUser : IdentityUser<int>
{
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;

    /// <summary>URL do profilne slike (ako postoji).</summary>
    public string? ImageUrl { get; set; }

    /// <summary>Grad korisnika - FK prema referentnoj tabeli Cities (ne string polje!).</summary>
    public int? CityId { get; set; }
    public City? City { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    // Navigacije
    public Hairdresser? HairdresserProfile { get; set; }
    public ICollection<Reservation> ReservationsAsClient { get; set; } = new List<Reservation>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<SearchHistory> SearchHistory { get; set; } = new List<SearchHistory>();
}
