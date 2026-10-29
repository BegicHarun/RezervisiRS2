using System.Text.Json;
using RezervisiMe.API.Common;

namespace RezervisiMe.API.Middleware;

/// <summary>
/// Centralno mapiranje izuzetaka na HTTP statuse (upute 3.4).
/// Klijentu se ne izlaze stack trace; greska se logira na serveru,
/// a klijentu vraca standardizovana poruka.
/// </summary>
public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;
    private readonly IHostEnvironment _env;

    public ExceptionMiddleware(
        RequestDelegate next,
        ILogger<ExceptionMiddleware> logger,
        IHostEnvironment env)
    {
        _next = next;
        _logger = logger;
        _env = env;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleAsync(context, ex);
        }
    }

    private async Task HandleAsync(HttpContext context, Exception ex)
    {
        var (status, message, errors) = ex switch
        {
            NotFoundException => (StatusCodes.Status404NotFound, ex.Message, (IReadOnlyList<string>?)null),
            ForbiddenException => (StatusCodes.Status403Forbidden, ex.Message, null),
            ConflictException => (StatusCodes.Status409Conflict, ex.Message, null),
            ValidationException ve => (StatusCodes.Status400BadRequest, ve.Message, ve.Errors),
            BusinessException => (StatusCodes.Status400BadRequest, ex.Message, null),
            _ => (StatusCodes.Status500InternalServerError,
                  "Doslo je do greske na serveru. Pokusajte ponovo.", null)
        };

        if (status == StatusCodes.Status500InternalServerError)
            _logger.LogError(ex, "Neobradjena greska: {Message}", ex.Message);
        else
            _logger.LogWarning("Obradjena greska ({Status}): {Message}", status, ex.Message);

        context.Response.StatusCode = status;
        context.Response.ContentType = "application/json";

        var payload = new
        {
            status,
            message,
            errors,
            // Stack trace samo u developmentu
            detail = _env.IsDevelopment() && status == 500 ? ex.ToString() : null
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(payload,
            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }));
    }
}
