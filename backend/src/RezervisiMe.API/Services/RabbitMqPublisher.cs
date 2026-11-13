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
    private const string DeadLetterQueue = "notifications.failed";

    private IConnection? _connection;
    private readonly ConnectionFactory _factory;
    private readonly SemaphoreSlim _connectionLock = new(1);

    public RabbitMqPublisher()
    {
        _factory = new ConnectionFactory
        {
            HostName = Environment.GetEnvironmentVariable("RABBITMQ_HOST") ?? "localhost",
            Port = int.TryParse(Environment.GetEnvironmentVariable("RABBITMQ_PORT"), out var p) ? p : 5672,
            UserName = Environment.GetEnvironmentVariable("RABBITMQ_USER") ?? "guest",
            Password = Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD") ?? "guest"
        };
    }

    private async Task<IConnection> GetConnectionAsync()
    {
        await _connectionLock.WaitAsync();
        try
        {
            if (_connection is { IsOpen: true }) return _connection;
            if (_connection is not null) await _connection.DisposeAsync();
            _connection = null;
            _connection = await _factory.CreateConnectionAsync();
            return _connection;
        }
        finally
        {
            _connectionLock.Release();
        }
    }

    public async Task PublishAsync(NotificationMessage message)
    {
        var connection = await GetConnectionAsync();
        await using var channel = await connection.CreateChannelAsync(new CreateChannelOptions(
            publisherConfirmationsEnabled: true, publisherConfirmationTrackingEnabled: true));
        await channel.QueueDeclareAsync(DeadLetterQueue, durable: true, exclusive: false, autoDelete: false);
        await channel.QueueDeclareAsync(QueueName, durable: true, exclusive: false, autoDelete: false,
            arguments: new Dictionary<string, object?>
            {
                ["x-dead-letter-exchange"] = "",
                ["x-dead-letter-routing-key"] = DeadLetterQueue
            });

        var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
        var props = new BasicProperties { Persistent = true };

        await channel.BasicPublishAsync(
            exchange: string.Empty, routingKey: QueueName,
            mandatory: true, basicProperties: props, body: body);
    }

    public async ValueTask DisposeAsync()
    {
        if (_connection is not null) await _connection.DisposeAsync();
        _connectionLock.Dispose();
    }
}
