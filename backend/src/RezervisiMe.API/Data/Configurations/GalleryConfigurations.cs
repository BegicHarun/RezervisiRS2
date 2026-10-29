using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data.Configurations;

public class SalonImageConfiguration : IEntityTypeConfiguration<SalonImage>
{
    public void Configure(EntityTypeBuilder<SalonImage> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.ImageUrl).IsRequired().HasMaxLength(500);
        b.Property(x => x.Caption).HasMaxLength(200);

        b.HasOne(x => x.Salon)
            .WithMany(s => s.Images)
            .HasForeignKey(x => x.SalonId)
            .OnDelete(DeleteBehavior.Cascade); // slike se brisu sa salonom
    }
}

public class TagConfiguration : IEntityTypeConfiguration<Tag>
{
    public void Configure(EntityTypeBuilder<Tag> b)
    {
        b.HasKey(x => x.Id);
        b.Property(x => x.Name).IsRequired().HasMaxLength(60);
        b.HasIndex(x => x.Name).IsUnique();
    }
}

public class ReviewTagConfiguration : IEntityTypeConfiguration<ReviewTag>
{
    public void Configure(EntityTypeBuilder<ReviewTag> b)
    {
        b.HasKey(x => new { x.ReviewId, x.TagId });

        b.HasOne(x => x.Review)
            .WithMany(r => r.ReviewTags)
            .HasForeignKey(x => x.ReviewId)
            .OnDelete(DeleteBehavior.Cascade);

        b.HasOne(x => x.Tag)
            .WithMany(t => t.ReviewTags)
            .HasForeignKey(x => x.TagId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
