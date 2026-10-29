using System.Text;
using System.Text.Json;
using RabbitMQ.Client;

namespace RezervisiMe.API.Services;

/// <summary>
/// Salje poruke na RabbitMQ. Koristi jednu dijeljenu (singleton) konekciju,
/// ne kreira novu po svakom pozivu (Dodatak A.1).
/// </summary>
public class RabbitMqPublisher : IMessagePublisher, IAsyncDisposable
{
    public const string QueueName = "notifications";

    private readonly IConnection _connection;
    private readonly ILogger<RabbitMqPublisher> _logger;

    private RabbitMqPublisher(IConnection connection, ILogger<RabbitMqPublisher> logger)
    {
        _connection = connection;
        _logger = logger;
    }

    public static async Task<RabbitMqPublisher> CreateAsync(ILogger<RabbitMqPublisher> logger)
    {
        var factory = new ConnectionFactory
        {
            HostName = Environment.GetEnvironmentVariable("RABBITMQ_HOST") ?? "localhost",
            Port = int.TryParse(Environment.GetEnvironmentVariable("RABBITMQ_PORT"), out var p) ? p : 5672,
            UserName = Environment.GetEnvironmentVariable("RABBITMQ_USER") ?? "guest",
            Password = Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD") ?? "guest"
        };
        var connection = await factory.CreateConnectionAsync();
        return new RabbitMqPublisher(connection, logger);
    }

    public async Task PublishAsync(NotificationMessage message)
    {
        try
        {
            await using var channel = await _connection.CreateChannelAsync();
            await channel.QueueDeclareAsync(QueueName, durable: true, exclusive: false, autoDelete: false);

            var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
            var props = new BasicProperties { Persistent = true };

            await channel.BasicPublishAsync(
                exchange: string.Empty, routingKey: QueueName,
                mandatory: false, basicProperties: props, body: body);
        }
        catch (Exception ex)
        {
            // Ne rusimo glavni tok ako messaging padne - logiramo i nastavljamo.
            _logger.LogError(ex, "Slanje poruke na RabbitMQ nije uspjelo: {Title}", message.Title);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_connection.IsOpen) await _connection.CloseAsync();
        await _connection.DisposeAsync();
    }
}
