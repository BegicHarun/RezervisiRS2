using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReservationsController : ControllerBase
{
    private readonly IReservationService _reservations;
    public ReservationsController(IReservationService reservations) => _reservations = reservations;

    /// <summary>Moje rezervacije (klijent). userId se uzima iz JWT tokena.</summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PagedResult<ReservationDto>>> Mine([FromQuery] PagedQuery query)
        => Ok(await _reservations.GetMineAsync(query));

    /// <summary>Rezervacije za upravljanje: admin sve, frizer samo svog salona. Opcioni filter statusa.</summary>
    [Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
    [HttpGet]
    public async Task<ActionResult<PagedResult<ReservationDto>>> All(
        [FromQuery] PagedQuery query, [FromQuery] string? status)
        => Ok(await _reservations.GetForManagementAsync(query, status));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ReservationDto>> GetById(int id)
        => Ok(await _reservations.GetByIdAsync(id));

    /// <summary>Slobodni termini za frizera i uslugu na dati datum.</summary>
    [HttpGet("available-slots")]
    public async Task<ActionResult<IReadOnlyList<AvailableSlotDto>>> Slots(
        [FromQuery] int hairdresserId, [FromQuery] int serviceId, [FromQuery] DateOnly date)
        => Ok(await _reservations.GetAvailableSlotsAsync(hairdresserId, serviceId, date));

    [HttpPost]
    public async Task<ActionResult<ReservationDto>> Create([FromBody] CreateReservationRequest req)
    {
        var created = await _reservations.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    /// <summary>Promjena statusa kroz state machine (potvrda/otkazivanje/zavrsetak).</summary>
    [HttpPost("{id:int}/status")]
    public async Task<ActionResult<ReservationDto>> ChangeStatus(int id, [FromBody] ChangeStatusRequest req)
        => Ok(await _reservations.ChangeStatusAsync(id, req));
}
