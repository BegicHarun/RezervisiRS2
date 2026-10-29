using System.Text;
using System.Text.Json;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace RezervisiMe.Worker;

/// <summary>
/// Pomocni mikroservis (upute 3.2 / 4): slusa RabbitMQ red "notifications"
/// i za svaku poruku salje email obavijest. Radi u ZASEBNOM kontejneru,
/// odvojeno od glavnog API-ja.
/// </summary>
public class NotificationConsumer : BackgroundService
{
    public const string QueueName = "notifications";

    private readonly ILogger<NotificationConsumer> _logger;
    private readonly IEmailSender _emailSender;

    private IConnection? _connection;
    private IChannel? _channel;

    public NotificationConsumer(ILogger<NotificationConsumer> logger, IEmailSender emailSender)
    {
        _logger = logger;
        _emailSender = emailSender;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // RabbitMQ zna biti spor pri dizanju - pokusaj konekcije sa retry-em.
        await ConnectWithRetryAsync(stoppingToken);
        if (_channel is null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += OnMessageAsync;

        await _channel.BasicConsumeAsync(QueueName, autoAck: false, consumer: consumer, cancellationToken: stoppingToken);
        _logger.LogInformation("Worker slusa red '{Queue}'. Cekam poruke...", QueueName);

        // Drzi servis zivim dok se ne zatrazi gasenje.
        while (!stoppingToken.IsCancellationRequested)
            await Task.Delay(1000, stoppingToken);
    }

    private async Task OnMessageAsync(object sender, BasicDeliverEventArgs ea)
    {
        var json = Encoding.UTF8.GetString(ea.Body.ToArray());
        try
        {
            var msg = JsonSerializer.Deserialize<NotificationMessage>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (msg is not null && !string.IsNullOrWhiteSpace(msg.Email))
            {
                await _emailSender.SendAsync(msg.Email, msg.Title, msg.Body, CancellationToken.None);
            }

            // Potvrdi obradu tek nakon uspjeha (ako padne, poruka se vraca u red).
            if (_channel is not null)
                await _channel.BasicAckAsync(ea.DeliveryTag, multiple: false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Obrada poruke nije uspjela: {Json}", json);
            // Ne vracaj u red beskonacno - odbaci (da ne blokira red).
            if (_channel is not null)
                await _channel.BasicNackAsync(ea.DeliveryTag, multiple: false, requeue: false);
        }
    }

    private async Task ConnectWithRetryAsync(CancellationToken ct)
    {
        var factory = new ConnectionFactory
        {
            HostName = Environment.GetEnvironmentVariable("RABBITMQ_HOST") ?? "localhost",
            Port = int.TryParse(Environment.GetEnvironmentVariable("RABBITMQ_PORT"), out var p) ? p : 5672,
            UserName = Environment.GetEnvironmentVariable("RABBITMQ_USER") ?? "guest",
            Password = Environment.GetEnvironmentVariable("RABBITMQ_PASSWORD") ?? "guest"
        };

        for (int attempt = 1; attempt <= 10 && !ct.IsCancellationRequested; attempt++)
        {
            try
            {
                _connection = await factory.CreateConnectionAsync(ct);
                _channel = await _connection.CreateChannelAsync(cancellationToken: ct);
                await _channel.QueueDeclareAsync(QueueName, durable: true, exclusive: false, autoDelete: false,
                    cancellationToken: ct);
                _logger.LogInformation("Povezan na RabbitMQ ({Host}).", factory.HostName);
                return;
            }
            catch (Exception ex)
            {
                _logger.LogWarning("RabbitMQ konekcija nije uspjela (pokusaj {Attempt}/10): {Msg}", attempt, ex.Message);
                await Task.Delay(TimeSpan.FromSeconds(3), ct);
            }
        }
        _logger.LogError("Nije moguce povezati se na RabbitMQ. Worker se gasi.");
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel is not null) await _channel.CloseAsync(cancellationToken);
        if (_connection is not null) await _connection.CloseAsync(cancellationToken);
        await base.StopAsync(cancellationToken);
    }
}
