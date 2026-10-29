using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data.Configurations;

public class CityConfiguration : IEntityTypeConfiguration<City>
{
    public void Configure(EntityTypeBuilder<City> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).IsRequired().HasMaxLength(100);
        b.Property(x => x.Region).IsRequired().HasMaxLength(100);

        // Korisnik -> Grad: pri brisanju grada ne brisi korisnike (Restrict)
        b.HasMany(x => x.Users)
            .WithOne(u => u.City!)
            .HasForeignKey(u => u.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Salons)
            .WithOne(s => s.City)
            .HasForeignKey(s => s.CityId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class ServiceCategoryConfiguration : IEntityTypeConfiguration<ServiceCategory>
{
    public void Configure(EntityTypeBuilder<ServiceCategory> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).IsRequired().HasMaxLength(100);
        b.Property(x => x.IconName).HasMaxLength(50);

        b.HasMany(x => x.Services)
            .WithOne(s => s.ServiceCategory)
            .HasForeignKey(s => s.ServiceCategoryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class SalonConfiguration : IEntityTypeConfiguration<Salon>
{
    public void Configure(EntityTypeBuilder<Salon> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).IsRequired().HasMaxLength(150);
        b.Property(x => x.Address).IsRequired().HasMaxLength(250);
        b.Property(x => x.Description).HasMaxLength(2000);
        b.Property(x => x.RejectionReason).HasMaxLength(500);
        b.Property(x => x.VerificationStatus).HasConversion<int>();

        // Soft delete filter - obrisani saloni se ne vracaju u upitima
        b.HasQueryFilter(x => !x.IsDeleted);

        b.HasMany(x => x.Hairdressers)
            .WithOne(h => h.Salon)
            .HasForeignKey(h => h.SalonId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Services)
            .WithOne(s => s.Salon)
            .HasForeignKey(s => s.SalonId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.Reviews)
            .WithOne(r => r.Salon)
            .HasForeignKey(r => r.SalonId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class HairdresserConfiguration : IEntityTypeConfiguration<Hairdresser>
{
    public void Configure(EntityTypeBuilder<Hairdresser> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Specialization).IsRequired().HasMaxLength(150);
        b.Property(x => x.RejectionReason).HasMaxLength(500);
        b.Property(x => x.VerificationStatus).HasConversion<int>();

        b.HasQueryFilter(x => !x.IsDeleted);

        // Frizer <-> Korisnik: 1-na-1, jedan nalog moze imati jedan frizerski profil
        b.HasOne(x => x.User)
            .WithOne(u => u.HairdresserProfile!)
            .HasForeignKey<Hairdresser>(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        b.HasMany(x => x.WorkingHours)
            .WithOne(w => w.Hairdresser)
            .HasForeignKey(w => w.HairdresserId)
            .OnDelete(DeleteBehavior.Cascade); // radno vrijeme se brise s frizerom

        b.HasMany(x => x.Reservations)
            .WithOne(r => r.Hairdresser)
            .HasForeignKey(r => r.HairdresserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class ServiceConfiguration : IEntityTypeConfiguration<Service>
{
    public void Configure(EntityTypeBuilder<Service> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).IsRequired().HasMaxLength(150);
        b.Property(x => x.Description).HasMaxLength(1000);
        b.Property(x => x.Price).HasColumnType("decimal(10,2)");

        b.HasQueryFilter(x => !x.IsDeleted);

        b.HasMany(x => x.Reservations)
            .WithOne(r => r.Service)
            .HasForeignKey(r => r.ServiceId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class WorkingHourConfiguration : IEntityTypeConfiguration<WorkingHour>
{
    public void Configure(EntityTypeBuilder<WorkingHour> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.DayOfWeek).HasConversion<int>();
    }
}

public class HairdresserServiceConfiguration : IEntityTypeConfiguration<HairdresserService>
{
    public void Configure(EntityTypeBuilder<HairdresserService> b)
    {
        // Kompozitni kljuc za many-to-many join tabelu
        b.HasKey(x => new { x.HairdresserId, x.ServiceId });

        b.HasOne(x => x.Hairdresser)
            .WithMany(h => h.HairdresserServices)
            .HasForeignKey(x => x.HairdresserId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.Service)
            .WithMany(s => s.HairdresserServices)
            .HasForeignKey(x => x.ServiceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
