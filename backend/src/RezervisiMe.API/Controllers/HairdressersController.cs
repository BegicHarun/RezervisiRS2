using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class HairdressersController : ControllerBase
{
    private readonly IHairdresserService _hairdressers;
    public HairdressersController(IHairdresserService hairdressers) => _hairdressers = hairdressers;

    /// <summary>Frizeri jednog salona (verifikovani). Koristi mobilna app pri rezervaciji.</summary>
    [HttpGet("salon/{salonId:int}")]
    public async Task<ActionResult<IReadOnlyList<HairdresserDto>>> ForSalon(int salonId)
        => Ok(await _hairdressers.GetForSalonAsync(salonId));

    [HttpGet]
    public async Task<ActionResult<PagedResult<HairdresserDto>>> Get(
        [FromQuery] PagedQuery query, [FromQuery] int? salonId)
        => Ok(await _hairdressers.GetAsync(query, salonId));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPost]
    public async Task<ActionResult<HairdresserDto>> Create([FromBody] HairdresserUpsertRequest req)
        => Ok(await _hairdressers.CreateAsync(req));

    /// <summary>Kreira frizera SA nalogom (kredencijali za prijavu) - administrator.</summary>
    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("with-account")]
    public async Task<ActionResult<HairdresserDto>> CreateWithAccount(
        [FromBody] HairdresserAccountRequest req)
        => Ok(await _hairdressers.CreateWithAccountAsync(req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _hairdressers.DeleteAsync(id);
        return NoContent();
    }

    /// <summary>Verifikacija frizera (odobri/odbij) - administrator (7.6).</summary>
    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("{id:int}/verify")]
    public async Task<ActionResult<HairdresserDto>> Verify(int id, [FromBody] HairdresserVerifyRequest req)
        => Ok(await _hairdressers.VerifyAsync(id, req));

    /// <summary>Radno vrijeme frizera po danima (7.5).</summary>
    [HttpGet("{id:int}/working-hours")]
    public async Task<ActionResult<IReadOnlyList<WorkingHourDto>>> GetWorkingHours(int id)
        => Ok(await _hairdressers.GetWorkingHoursAsync(id));

    [Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
    [HttpPut("{id:int}/working-hours")]
    public async Task<ActionResult<IReadOnlyList<WorkingHourDto>>> SetWorkingHours(
        int id, [FromBody] List<WorkingHourUpsertRequest> hours)
        => Ok(await _hairdressers.SetWorkingHoursAsync(id, hours));
}
