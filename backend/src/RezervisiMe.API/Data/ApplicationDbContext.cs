using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data;

/// <summary>
/// EF Core DbContext. Nasljedjuje IdentityDbContext radi ASP.NET Identity tabela.
/// Svi FK-ovi definisani kroz konfiguraciju (IEntityTypeConfiguration), uz referencijalni integritet.
/// </summary>
public class ApplicationDbContext
    : IdentityDbContext<ApplicationUser, ApplicationRole, int>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // Glavne tabele
    public DbSet<Salon> Salons => Set<Salon>();
    public DbSet<Hairdresser> Hairdressers => Set<Hairdresser>();
    public DbSet<Service> Services => Set<Service>();
    public DbSet<Reservation> Reservations => Set<Reservation>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<WorkingHour> WorkingHours => Set<WorkingHour>();
    public DbSet<SearchHistory> SearchHistory => Set<SearchHistory>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<SalonImage> SalonImages => Set<SalonImage>();
    public DbSet<ReviewTag> ReviewTags => Set<ReviewTag>();
    public DbSet<Payment> Payments => Set<Payment>();

    // Referentne tabele
    public DbSet<City> Cities => Set<City>();
    public DbSet<ServiceCategory> ServiceCategories => Set<ServiceCategory>();
    public DbSet<HairdresserService> HairdresserServices => Set<HairdresserService>();
    public DbSet<Tag> Tags => Set<Tag>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Ucitaj sve IEntityTypeConfiguration<> iz ovog assembly-ja
        builder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);
    }
}
