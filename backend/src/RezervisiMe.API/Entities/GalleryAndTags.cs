namespace RezervisiMe.API.Entities;

/// <summary>
/// Slika u galeriji salona. Glavna tabela.
/// Salon moze imati vise slika (npr. enterijer, radovi).
/// </summary>
public class SalonImage
{
    public int Id { get; set; }

    public int SalonId { get; set; }
    public Salon Salon { get; set; } = null!;

    public string ImageUrl { get; set; } = null!;
    public string? Caption { get; set; }

    /// <summary>Redoslijed prikaza u galeriji.</summary>
    public int SortOrder { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Brza oznaka za recenziju (npr. "Ljubazno osoblje", "Cisto", "Brzo").
/// Referentna tabela - unaprijed definisan skup oznaka.
/// </summary>
public class Tag
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;

    public ICollection<ReviewTag> ReviewTags { get; set; } = new List<ReviewTag>();
}

/// <summary>
/// Many-to-many veza izmedju recenzije i oznake. Glavna tabela (nosi vezu recenzija-oznaka).
/// </summary>
public class ReviewTag
{
    public int ReviewId { get; set; }
    public Review Review { get; set; } = null!;

    public int TagId { get; set; }
    public Tag Tag { get; set; } = null!;
}
