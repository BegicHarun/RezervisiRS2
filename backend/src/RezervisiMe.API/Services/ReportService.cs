using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using RezervisiMe.API.Common;
using RezervisiMe.API.Data;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Services;

public interface IReportService
{
    Task<byte[]> RevenueReportAsync(DateTime from, DateTime to);
    Task<byte[]> PopularServicesReportAsync(DateTime from, DateTime to);
}

/// <summary>
/// Generise dva PDF izvjestaja (upute 7.8):
///  1) Izvjestaj o prihodima (po danima/uslugama, broj rezervacija, prosjecna vrijednost)
///  2) Izvjestaj o popularnim uslugama (rang po broju rezervacija i prihodu)
/// </summary>
public class ReportService : IReportService
{
    private readonly ApplicationDbContext _db;
    public ReportService(ApplicationDbContext db) => _db = db;

    public async Task<byte[]> RevenueReportAsync(DateTime from, DateTime to)
    {
        var toEnd = to.Date.AddDays(1);
        var data = await _db.Reservations.AsNoTracking()
            .Include(r => r.Service)
            .Where(r => r.Status == ReservationStatus.Completed &&
                        r.StartTime >= from.Date && r.StartTime < toEnd)
            .ToListAsync();

        var totalRevenue = data.Sum(r => r.Price);
        var totalCount = data.Count;
        var avg = totalCount == 0 ? 0 : totalRevenue / totalCount;

        var byDay = data
            .GroupBy(r => r.StartTime.Date)
            .OrderBy(g => g.Key)
            .Select(g => new { Day = g.Key, Count = g.Count(), Revenue = g.Sum(r => r.Price) })
            .ToList();

        var byService = data
            .GroupBy(r => r.Service.Name)
            .OrderByDescending(g => g.Sum(r => r.Price))
            .Select(g => new { Name = g.Key, Count = g.Count(), Revenue = g.Sum(r => r.Price) })
            .ToList();

        return Document.Create(doc =>
        {
            doc.Page(page =>
            {
                page.Margin(40);
                page.Size(PageSizes.A4);
                page.DefaultTextStyle(x => x.FontSize(10));

                page.Header().Column(col =>
                {
                    col.Item().Text("RezervisiMe").FontSize(20).Bold().FontColor(Colors.Blue.Medium);
                    col.Item().Text("Izvjestaj o prihodima").FontSize(14).SemiBold();
                    col.Item().Text($"Period: {from:dd.MM.yyyy} - {to:dd.MM.yyyy}").FontColor(Colors.Grey.Darken1);
                    col.Item().PaddingTop(4).LineHorizontal(1).LineColor(Colors.Grey.Lighten1);
                });

                page.Content().PaddingVertical(10).Column(col =>
                {
                    col.Spacing(14);

                    // Sazetak
                    col.Item().Row(row =>
                    {
                        row.RelativeItem().Column(c => { c.Item().Text("Ukupan prihod").FontColor(Colors.Grey.Darken1); c.Item().Text($"{totalRevenue:0.00} KM").FontSize(14).Bold(); });
                        row.RelativeItem().Column(c => { c.Item().Text("Broj rezervacija").FontColor(Colors.Grey.Darken1); c.Item().Text($"{totalCount}").FontSize(14).Bold(); });
                        row.RelativeItem().Column(c => { c.Item().Text("Prosjecna vrijednost").FontColor(Colors.Grey.Darken1); c.Item().Text($"{avg:0.00} KM").FontSize(14).Bold(); });
                    });

                    // Po danima
                    col.Item().Text("Prihod po danima").FontSize(12).SemiBold();
                    col.Item().Table(t =>
                    {
                        t.ColumnsDefinition(c => { c.RelativeColumn(2); c.RelativeColumn(); c.RelativeColumn(); });
                        t.Header(h =>
                        {
                            h.Cell().Element(HeadCell).Text("Datum");
                            h.Cell().Element(HeadCell).AlignRight().Text("Rezervacija");
                            h.Cell().Element(HeadCell).AlignRight().Text("Prihod");
                        });
                        foreach (var d in byDay)
                        {
                            t.Cell().Element(BodyCell).Text($"{d.Day:dd.MM.yyyy}");
                            t.Cell().Element(BodyCell).AlignRight().Text($"{d.Count}");
                            t.Cell().Element(BodyCell).AlignRight().Text($"{d.Revenue:0.00} KM");
                        }
                    });

                    // Po uslugama
                    col.Item().Text("Prihod po uslugama").FontSize(12).SemiBold();
                    col.Item().Table(t =>
                    {
                        t.ColumnsDefinition(c => { c.RelativeColumn(2); c.RelativeColumn(); c.RelativeColumn(); });
                        t.Header(h =>
                        {
                            h.Cell().Element(HeadCell).Text("Usluga");
                            h.Cell().Element(HeadCell).AlignRight().Text("Rezervacija");
                            h.Cell().Element(HeadCell).AlignRight().Text("Prihod");
                        });
                        foreach (var s in byService)
                        {
                            t.Cell().Element(BodyCell).Text(s.Name);
                            t.Cell().Element(BodyCell).AlignRight().Text($"{s.Count}");
                            t.Cell().Element(BodyCell).AlignRight().Text($"{s.Revenue:0.00} KM");
                        }
                    });
                });

                page.Footer().AlignCenter().Text(x =>
                {
                    x.Span("Generisano: ");
                    x.Span($"{DateTime.Now:dd.MM.yyyy HH:mm}");
                    x.Span("  ·  Stranica ");
                    x.CurrentPageNumber();
                    x.Span(" / ");
                    x.TotalPages();
                });
            });
        }).GeneratePdf();
    }

    public async Task<byte[]> PopularServicesReportAsync(DateTime from, DateTime to)
    {
        var toEnd = to.Date.AddDays(1);
        var data = await _db.Reservations.AsNoTracking()
            .Include(r => r.Service).ThenInclude(s => s.ServiceCategory)
            .Where(r => r.StartTime >= from.Date && r.StartTime < toEnd &&
                        r.Status != ReservationStatus.Cancelled)
            .ToListAsync();

        var ranked = data
            .GroupBy(r => new { r.ServiceId, r.Service.Name, Category = r.Service.ServiceCategory.Name })
            .Select(g => new
            {
                g.Key.Name,
                g.Key.Category,
                Count = g.Count(),
                Revenue = g.Where(r => r.Status == ReservationStatus.Completed).Sum(r => r.Price)
            })
            .OrderByDescending(x => x.Count)
            .ToList();

        var maxCount = ranked.Count == 0 ? 1 : ranked.Max(x => x.Count);

        return Document.Create(doc =>
        {
            doc.Page(page =>
            {
                page.Margin(40);
                page.Size(PageSizes.A4);
                page.DefaultTextStyle(x => x.FontSize(10));

                page.Header().Column(col =>
                {
                    col.Item().Text("RezervisiMe").FontSize(20).Bold().FontColor(Colors.Blue.Medium);
                    col.Item().Text("Izvjestaj o popularnim uslugama").FontSize(14).SemiBold();
                    col.Item().Text($"Period: {from:dd.MM.yyyy} - {to:dd.MM.yyyy}").FontColor(Colors.Grey.Darken1);
                    col.Item().PaddingTop(4).LineHorizontal(1).LineColor(Colors.Grey.Lighten1);
                });

                page.Content().PaddingVertical(10).Column(col =>
                {
                    col.Spacing(10);
                    col.Item().Text($"Ukupno usluga u rangu: {ranked.Count}").FontColor(Colors.Grey.Darken1);

                    col.Item().Table(t =>
                    {
                        t.ColumnsDefinition(c =>
                        {
                            c.ConstantColumn(28);
                            c.RelativeColumn(3);
                            c.RelativeColumn(2);
                            c.RelativeColumn();
                            c.RelativeColumn();
                        });
                        t.Header(h =>
                        {
                            h.Cell().Element(HeadCell).Text("#");
                            h.Cell().Element(HeadCell).Text("Usluga");
                            h.Cell().Element(HeadCell).Text("Kategorija");
                            h.Cell().Element(HeadCell).AlignRight().Text("Rezervacija");
                            h.Cell().Element(HeadCell).AlignRight().Text("Prihod");
                        });
                        int rank = 1;
                        foreach (var s in ranked)
                        {
                            t.Cell().Element(BodyCell).Text($"{rank++}");
                            t.Cell().Element(BodyCell).Text(s.Name);
                            t.Cell().Element(BodyCell).Text(s.Category);
                            t.Cell().Element(BodyCell).AlignRight().Text($"{s.Count}");
                            t.Cell().Element(BodyCell).AlignRight().Text($"{s.Revenue:0.00} KM");
                        }
                    });
                });

                page.Footer().AlignCenter().Text(x =>
                {
                    x.Span("Generisano: ");
                    x.Span($"{DateTime.Now:dd.MM.yyyy HH:mm}");
                    x.Span("  ·  Stranica ");
                    x.CurrentPageNumber();
                    x.Span(" / ");
                    x.TotalPages();
                });
            });
        }).GeneratePdf();
    }

    private static IContainer HeadCell(IContainer c) => c
        .Background(Colors.Grey.Lighten3).PaddingVertical(6).PaddingHorizontal(6)
        .DefaultTextStyle(x => x.SemiBold());

    private static IContainer BodyCell(IContainer c) => c
        .BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(5).PaddingHorizontal(6);
}
