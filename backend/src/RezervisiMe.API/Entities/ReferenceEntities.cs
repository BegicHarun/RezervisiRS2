using Microsoft.AspNetCore.Identity;

namespace RezervisiMe.API.Entities;

/// <summary>
/// Rola (ASP.NET Identity). Referentna tabela.
/// </summary>
public class ApplicationRole : IdentityRole<int>
{
    public ApplicationRole() { }
    public ApplicationRole(string name) : base(name) { }
}

/// <summary>
/// Grad - referentna tabela. Koristi se u adresama korisnika i salona.
/// </summary>
public class City
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Region { get; set; } = null!;

    public ICollection<ApplicationUser> Users { get; set; } = new List<ApplicationUser>();
    public ICollection<Salon> Salons { get; set; } = new List<Salon>();
}

/// <summary>
/// Kategorija usluge - referentna tabela (npr. sisanje, farbanje, nokti).
/// </summary>
public class ServiceCategory
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? IconName { get; set; }

    public ICollection<Service> Services { get; set; } = new List<Service>();
}
