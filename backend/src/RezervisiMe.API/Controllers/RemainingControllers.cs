using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Recommender;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviews;
    public ReviewsController(IReviewService reviews) => _reviews = reviews;

    [HttpGet("salon/{salonId:int}")]
    public async Task<ActionResult<IReadOnlyList<ReviewDto>>> ForSalon(int salonId)
        => Ok(await _reviews.GetForSalonAsync(salonId));

    [HttpPost]
    public async Task<ActionResult<ReviewDto>> Create([FromBody] CreateReviewRequest req)
        => Ok(await _reviews.CreateAsync(req));
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notifications;
    public NotificationsController(INotificationService notifications) => _notifications = notifications;

    [HttpGet]
    public async Task<ActionResult<PagedResult<NotificationDto>>> Mine([FromQuery] PagedQuery query)
        => Ok(await _notifications.GetMineAsync(query));

    [HttpGet("unread-count")]
    public async Task<ActionResult<int>> UnreadCount()
        => Ok(await _notifications.UnreadCountAsync());

    [HttpPost("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id)
    {
        await _notifications.MarkReadAsync(id);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProfileController : ControllerBase
{
    private readonly IProfileService _profile;
    public ProfileController(IProfileService profile) => _profile = profile;

    [HttpGet]
    public async Task<ActionResult<UserDto>> Me() => Ok(await _profile.GetMeAsync());

    [HttpPut]
    public async Task<ActionResult<UserDto>> Update([FromBody] UpdateProfileRequest req)
        => Ok(await _profile.UpdateAsync(req));

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest req)
    {
        await _profile.ChangePasswordAsync(req);
        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommenderService _recommender;
    public RecommendationsController(IRecommenderService recommender) => _recommender = recommender;

    /// <summary>Personalizovane preporuke salona za trenutnog korisnika.</summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<RecommendationDto>>> Get([FromQuery] int take = 5)
        => Ok(await _recommender.GetRecommendationsAsync(take));
}
