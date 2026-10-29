namespace RezervisiMe.Worker;

/// <summary>
/// Poruka koju glavni API objavljuje na RabbitMQ (mora se poklapati sa
/// RezervisiMe.API.Services.NotificationMessage - ista JSON struktura).
/// </summary>
public record NotificationMessage(
    int UserId,
    string Email,
    string Title,
    string Body);
