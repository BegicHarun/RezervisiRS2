namespace RezervisiMe.API.Services;

/// <summary>
/// Poruka koja se salje workeru preko RabbitMQ-a (npr. za slanje emaila).
/// </summary>
public record NotificationMessage(
    int UserId,
    string Email,
    string Title,
    string Body);

public interface IMessagePublisher
{
    Task PublishAsync(NotificationMessage message);
}

/// <summary>
/// Zadana implementacija koja samo logira. Pravi RabbitMQ publisher se
/// registruje kad se doda .env sa RABBITMQ_HOST (vidi Program.cs / faza 4).
/// </summary>
public class NullMessagePublisher : IMessagePublisher
{
    private readonly ILogger<NullMessagePublisher> _logger;
    public NullMessagePublisher(ILogger<NullMessagePublisher> logger) => _logger = logger;

    public Task PublishAsync(NotificationMessage message)
    {
        _logger.LogInformation(
            "[NullPublisher] Poruka za korisnika {UserId}: {Title}", message.UserId, message.Title);
        return Task.CompletedTask;
    }
}
