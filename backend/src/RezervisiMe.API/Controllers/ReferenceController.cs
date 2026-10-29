using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

/// <summary>
/// CRUD nad referentnim podacima (gradovi, kategorije). Citanje je dostupno svim
/// autentifikovanim korisnicima (za dropdown liste), a izmjene samo administratoru.
/// </summary>
[ApiController]
[Route("api")]
[Authorize]
public class ReferenceController : ControllerBase
{
    private readonly IReferenceService _reference;
    public ReferenceController(IReferenceService reference) => _reference = reference;

    // ---- Cities ----

    [HttpGet("cities")]
    public async Task<ActionResult<PagedResult<CityDto>>> GetCities([FromQuery] PagedQuery query)
        => Ok(await _reference.GetCitiesAsync(query));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("cities")]
    public async Task<ActionResult<CityDto>> CreateCity([FromBody] CityUpsertRequest req)
        => Ok(await _reference.CreateCityAsync(req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPut("cities/{id:int}")]
    public async Task<ActionResult<CityDto>> UpdateCity(int id, [FromBody] CityUpsertRequest req)
        => Ok(await _reference.UpdateCityAsync(id, req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpDelete("cities/{id:int}")]
    public async Task<IActionResult> DeleteCity(int id)
    {
        await _reference.DeleteCityAsync(id);
        return NoContent();
    }

    // ---- Categories ----

    [HttpGet("categories")]
    public async Task<ActionResult<PagedResult<ServiceCategoryDto>>> GetCategories([FromQuery] PagedQuery query)
        => Ok(await _reference.GetCategoriesAsync(query));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("categories")]
    public async Task<ActionResult<ServiceCategoryDto>> CreateCategory([FromBody] ServiceCategoryUpsertRequest req)
        => Ok(await _reference.CreateCategoryAsync(req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpPut("categories/{id:int}")]
    public async Task<ActionResult<ServiceCategoryDto>> UpdateCategory(int id, [FromBody] ServiceCategoryUpsertRequest req)
        => Ok(await _reference.UpdateCategoryAsync(id, req));

    [Authorize(Roles = Roles.Administrator)]
    [HttpDelete("categories/{id:int}")]
    public async Task<IActionResult> DeleteCategory(int id)
    {
        await _reference.DeleteCategoryAsync(id);
        return NoContent();
    }

    // ---- Tags ----

    [HttpGet("tags")]
    public async Task<ActionResult<IReadOnlyList<TagDto>>> GetTags()
        => Ok(await _reference.GetTagsAsync());
}
