using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

/// <summary>Dashboard sa KPI-jevima i podacima za grafove (desktop, 7.1).</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = Roles.Administrator + "," + Roles.Frizer)]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _dashboard;
    public DashboardController(IDashboardService dashboard) => _dashboard = dashboard;

    [HttpGet]
    public async Task<ActionResult<DashboardDto>> Get()
        => Ok(await _dashboard.GetAsync());
}
