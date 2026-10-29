using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

/// <summary>PDF izvjestaji za preuzimanje i ispis (7.8).</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reports;
    public ReportsController(IReportService reports) => _reports = reports;

    /// <summary>Izvjestaj o prihodima za period.</summary>
    [HttpGet("revenue")]
    public async Task<IActionResult> Revenue([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var f = from ?? DateTime.UtcNow.AddDays(-30);
        var t = to ?? DateTime.UtcNow;
        var pdf = await _reports.RevenueReportAsync(f, t);
        return File(pdf, "application/pdf", $"prihodi_{f:yyyyMMdd}_{t:yyyyMMdd}.pdf");
    }

    /// <summary>Izvjestaj o popularnim uslugama za period.</summary>
    [HttpGet("popular-services")]
    public async Task<IActionResult> PopularServices([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var f = from ?? DateTime.UtcNow.AddDays(-30);
        var t = to ?? DateTime.UtcNow;
        var pdf = await _reports.PopularServicesReportAsync(f, t);
        return File(pdf, "application/pdf", $"popularne_usluge_{f:yyyyMMdd}_{t:yyyyMMdd}.pdf");
    }
}
