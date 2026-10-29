using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ServicesController : ControllerBase
{
    private readonly IServiceCatalogService _services;
    public ServicesController(IServiceCatalogService services) => _services = services;

    [HttpGet]
    public async Task<ActionResult<PagedResult<ServiceDto>>> Get(
        [FromQuery] PagedQuery query, [FromQuery] int? salonId, [FromQuery] int? categoryId)
        => Ok(await _services.GetAsync(query, salonId, categoryId));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ServiceDto>> GetById(int id)
        => Ok(await _services.GetByIdAsync(id));

    [Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
    [HttpPost]
    public async Task<ActionResult<ServiceDto>> Create([FromBody] ServiceUpsertRequest req)
    {
        var created = await _services.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<ServiceDto>> Update(int id, [FromBody] ServiceUpsertRequest req)
        => Ok(await _services.UpdateAsync(id, req));

    [Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _services.DeleteAsync(id);
        return NoContent();
    }
}
