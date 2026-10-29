using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RezervisiMe.API.Common;
using RezervisiMe.API.DTOs;
using RezervisiMe.API.Services;

namespace RezervisiMe.API.Controllers;

/// <summary>
/// Placanje rezervacija preko PayPal-a (sandbox).
/// Tok: create-order (vrati approveUrl) -> klijent odobri na PayPal-u -> capture (verifikacija).
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _payments;
    public PaymentsController(IPaymentService payments) => _payments = payments;

    /// <summary>Kreira PayPal narudzbu za rezervaciju. Vraca approveUrl koji klijent otvara.</summary>
    [HttpPost("reservation/{reservationId:int}/create-order")]
    public async Task<ActionResult<CreatePaymentResponse>> CreateOrder(int reservationId)
        => Ok(await _payments.CreateForReservationAsync(reservationId));

    /// <summary>Potvrdjuje (capture) placanje nakon sto je klijent odobrio na PayPal-u.</summary>
    [HttpPost("capture")]
    public async Task<ActionResult<PaymentDto>> Capture([FromBody] CapturePaymentRequest req)
        => Ok(await _payments.CaptureAsync(req.OrderId));

    /// <summary>Status placanja za rezervaciju (ili 404 ako placanja nema).</summary>
    [HttpGet("reservation/{reservationId:int}")]
    public async Task<ActionResult<PaymentDto>> ForReservation(int reservationId)
    {
        var dto = await _payments.GetForReservationAsync(reservationId);
        return dto is null ? NotFound() : Ok(dto);
    }

    /// <summary>Povrat sredstava (refund) - administrator.</summary>
    [Authorize(Roles = Roles.Administrator)]
    [HttpPost("reservation/{reservationId:int}/refund")]
    public async Task<ActionResult<PaymentDto>> Refund(int reservationId)
        => Ok(await _payments.RefundAsync(reservationId));
}
