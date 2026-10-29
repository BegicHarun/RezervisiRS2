using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data.Configurations;

public class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Amount).HasColumnType("decimal(10,2)");
        b.Property(x => x.Currency).HasMaxLength(3).IsRequired();
        b.Property(x => x.Provider).HasMaxLength(30).IsRequired();
        b.Property(x => x.ProviderOrderId).HasMaxLength(100);
        b.Property(x => x.ProviderCaptureId).HasMaxLength(100);
        b.Property(x => x.Status).HasConversion<int>();

        // Jedna rezervacija ima najvise jedno placanje (1:1).
        b.HasOne(x => x.Reservation)
            .WithOne(r => r.Payment)
            .HasForeignKey<Payment>(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        // Sprijeci dvostruko placanje iste rezervacije na nivou baze.
        b.HasIndex(x => x.ReservationId).IsUnique();
    }
}
