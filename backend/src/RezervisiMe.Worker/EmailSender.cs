using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace RezervisiMe.Worker;

public interface IEmailSender
{
    Task SendAsync(string toEmail, string subject, string body, CancellationToken ct);
}

/// <summary>
/// Salje email preko SMTP-a. Konfiguracija iz .env (SMTP_HOST, SMTP_PORT, ...).
/// Ako SMTP nije konfigurisan (nema hosta ili je primjer), samo logira (dev rezim).
/// </summary>
public class EmailSender : IEmailSender
{
    private readonly ILogger<EmailSender> _logger;

    private readonly string? _host;
    private readonly int _port;
    private readonly string _user;
    private readonly string _password;
    private readonly bool _useSsl;
    private readonly string _fromAddress;

    public EmailSender(ILogger<EmailSender> logger)
    {
        _logger = logger;
        _host = Environment.GetEnvironmentVariable("SMTP_HOST");
        _port = int.TryParse(Environment.GetEnvironmentVariable("SMTP_PORT"), out var p) ? p : 587;
        _user = Environment.GetEnvironmentVariable("SMTP_USERNAME") ?? "";
        _password = Environment.GetEnvironmentVariable("SMTP_PASSWORD") ?? "";
        _useSsl = bool.TryParse(Environment.GetEnvironmentVariable("SMTP_USE_SSL"), out var s) && s;
        _fromAddress = string.IsNullOrWhiteSpace(_user) ? "no-reply@rezervisime.ba" : _user;
    }

    private bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_host) &&
        _host != "smtp.example.com"; // primjer iz .env.example = nije stvarno konfigurisano

    public async Task SendAsync(string toEmail, string subject, string body, CancellationToken ct)
    {
        if (!IsConfigured)
        {
            // Dev rezim: nema pravog SMTP-a, samo logiraj da bi se vidjelo da worker radi.
            _logger.LogInformation(
                "[EmailSender/DEV] (SMTP nije konfigurisan) -> TO: {To} | SUBJECT: {Subject}",
                toEmail, subject);
            return;
        }

        var msg = new MimeMessage();
        msg.From.Add(MailboxAddress.Parse(_fromAddress));
        msg.To.Add(MailboxAddress.Parse(toEmail));
        msg.Subject = subject;
        msg.Body = new TextPart("plain") { Text = body };

        using var client = new SmtpClient();
        var socketOptions = _useSsl ? SecureSocketOptions.SslOnConnect : SecureSocketOptions.StartTlsWhenAvailable;
        await client.ConnectAsync(_host, _port, socketOptions, ct);
        if (!string.IsNullOrWhiteSpace(_user))
            await client.AuthenticateAsync(_user, _password, ct);
        await client.SendAsync(msg, ct);
        await client.DisconnectAsync(true, ct);

        _logger.LogInformation("Email poslan: TO {To} | {Subject}", toEmail, subject);
    }
}
