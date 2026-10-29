using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalonsController : ControllerBase
{
    private readonly ISalonService _salons;
    public SalonsController(ISalonService salons) => _salons = salons;

    /// <summary>Lista salona. Klijenti vide samo verifikovane; admin vidi sve.</summary>
    [HttpGet]
    public async Task<ActionResult<PagedResult<SalonDto>>> Get(
        [FromQuery] PagedQuery query, [FromQuery] int? cityId)
    {
        var isAdmin = User.IsInRole(Roles.Administrator);
        return Ok(await _salons.GetAsync(query, cityId, onlyApproved: !isAdmin));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<SalonDto>> GetById(int id)
        => Ok(await _salons.GetByIdAsync(id));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPost]
    public async Task<ActionResult<SalonDto>> Create([FromBody] SalonUpsertRequest req)
    {
        var created = await _salons.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [Authorize(Roles = Roles.Administrator)]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<SalonDto>> Update(int id, [FromBody] SalonUpsertRequest req)
        => Ok(await _salons.UpdateAsync(id, req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _salons.DeleteAsync(id);
        return NoContent();
    }

    /// <summary>Verifikacija salona (samo administrator).</summary>
    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("{id:int}/verify")]
    public async Task<ActionResult<SalonDto>> Verify(int id, [FromBody] SalonVerifyRequest req)
        => Ok(await _salons.VerifyAsync(id, req));
}
