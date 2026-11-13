using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Data;

namespace RezervisiMe.API.Services;

public sealed class OutboxMessage
{
    public long Id { get; set; }
    public string Payload { get; set; } = null!;
    public DateTime ExpiresAt { get; set; }
}

public sealed class NotificationOutbox(ApplicationDbContext db, IDataProtectionProvider protection)
{
    private readonly IDataProtector _protector = protection.CreateProtector("NotificationOutbox.v1");

    public void Enqueue(NotificationMessage message, TimeSpan? lifetime = null)
    {
        db.OutboxMessages.Add(new OutboxMessage
        {
            Payload = _protector.Protect(JsonSerializer.Serialize(message)),
            ExpiresAt = DateTime.UtcNow.Add(lifetime ?? TimeSpan.FromDays(7))
        });
    }

    public async Task DispatchAsync(IMessagePublisher publisher, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await ReservationLock.AcquireAsync(db, "notification-outbox");
        var item = await db.OutboxMessages.OrderBy(x => x.Id).FirstOrDefaultAsync(ct);
        if (item is not null)
        {
            if (item.ExpiresAt > DateTime.UtcNow)
            {
                var message = JsonSerializer.Deserialize<NotificationMessage>(_protector.Unprotect(item.Payload))!;
                await publisher.PublishAsync(message);
            }
            db.OutboxMessages.Remove(item);
            await db.SaveChangesAsync(ct);
        }
        await transaction.CommitAsync(ct);
    }
}

public sealed class NotificationOutboxWorker(
    IServiceScopeFactory scopes, IMessagePublisher publisher, ILogger<NotificationOutboxWorker> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<NotificationOutbox>()
                    .DispatchAsync(publisher, stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogWarning(ex, "Notification outbox dispatch failed. Retrying.");
            }
        }
    }
}
