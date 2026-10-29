using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data.Configurations;

public class ReservationConfiguration : IEntityTypeConfiguration<Reservation>
{
    public void Configure(EntityTypeBuilder<Reservation> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Price).HasColumnType("decimal(10,2)");
        b.Property(x => x.Status).HasConversion<int>();
        b.Property(x => x.StatusReason).HasMaxLength(500);

        // Klijent -> Rezervacije. Restrict da se korisnik ne moze obrisati dok ima rezervacije.
        b.HasOne(x => x.Client)
            .WithMany(u => u.ReservationsAsClient)
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indeks za brzu provjeru preklapanja termina po frizeru i vremenu
        b.HasIndex(x => new { x.HairdresserId, x.StartTime, x.EndTime });
    }
}

public class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Comment).HasMaxLength(1000);

        // Jedna rezervacija = najvise jedna recenzija
        b.HasOne(x => x.Reservation)
            .WithOne(r => r.Review!)
            .HasForeignKey<Review>(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.Client)
            .WithMany(u => u.Reviews)
            .HasForeignKey(x => x.ClientId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasIndex(x => x.ReservationId).IsUnique();
    }
}

public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Title).IsRequired().HasMaxLength(200);
        b.Property(x => x.Text).IsRequired().HasMaxLength(1000);

        b.HasOne(x => x.User)
            .WithMany(u => u.Notifications)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasIndex(x => new { x.UserId, x.IsRead });
    }
}

public class SearchHistoryConfiguration : IEntityTypeConfiguration<SearchHistory>
{
    public void Configure(EntityTypeBuilder<SearchHistory> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.SearchTerm).HasMaxLength(200);

        b.HasOne(x => x.User)
            .WithMany(u => u.SearchHistory)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.ServiceCategory)
            .WithMany()
            .HasForeignKey(x => x.ServiceCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Action).HasConversion<int>();
        b.Property(x => x.Description).HasMaxLength(500);

        b.HasOne(x => x.Reservation)
            .WithMany(r => r.AuditLogs)
            .HasForeignKey(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.PerformedByUser)
            .WithMany()
            .HasForeignKey(x => x.PerformedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
