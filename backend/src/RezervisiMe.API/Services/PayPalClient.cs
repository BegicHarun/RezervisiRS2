using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace RezervisiMe.API.Services;

public record PayPalOrder(string OrderId, string Status, string? ApproveUrl);
public record PayPalCapture(string CaptureId, string Status);

public interface IPayPalClient
{
    bool IsConfigured { get; }
    Task<PayPalOrder> CreateOrderAsync(decimal amount, string currency, string reference, string returnUrl, string cancelUrl);
    Task<PayPalCapture> CaptureOrderAsync(string orderId);
    Task<string> RefundCaptureAsync(string captureId, decimal amount, string currency);
}

/// <summary>
/// Klijent za PayPal REST API v2 (Orders + Payments). Koristi se sandbox ili live
/// okruzenje ovisno o PAYPAL_MODE. Sve verifikacije idu server-side (capture),
/// klijentu se nikad ne vjeruje da je placanje uspjesno.
/// </summary>
public class PayPalClient : IPayPalClient
{
    private readonly IHttpClientFactory _httpFactory;
    private readonly ILogger<PayPalClient> _logger;

    private readonly string? _clientId;
    private readonly string? _secret;
    private readonly string _baseUrl;

    public PayPalClient(IHttpClientFactory httpFactory, ILogger<PayPalClient> logger)
    {
        _httpFactory = httpFactory;
        _logger = logger;
        _clientId = Environment.GetEnvironmentVariable("PAYPAL_CLIENT_ID");
        _secret = Environment.GetEnvironmentVariable("PAYPAL_SECRET");
        var mode = Environment.GetEnvironmentVariable("PAYPAL_MODE") ?? "sandbox";
        _baseUrl = mode.Equals("live", StringComparison.OrdinalIgnoreCase)
            ? "https://api-m.paypal.com"
            : "https://api-m.sandbox.paypal.com";
    }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_clientId) && !string.IsNullOrWhiteSpace(_secret);

    private async Task<string> GetAccessTokenAsync()
    {
        var client = _httpFactory.CreateClient();
        var auth = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_clientId}:{_secret}"));
        var req = new HttpRequestMessage(HttpMethod.Post, $"{_baseUrl}/v1/oauth2/token");
        req.Headers.Authorization = new AuthenticationHeaderValue("Basic", auth);
        req.Content = new FormUrlEncodedContent(new[]
        {
            new KeyValuePair<string, string>("grant_type", "client_credentials")
        });

        var res = await client.SendAsync(req);
        var body = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
            throw new InvalidOperationException($"PayPal auth nije uspio: {res.StatusCode} {body}");

        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.GetProperty("access_token").GetString()!;
    }

    public async Task<PayPalOrder> CreateOrderAsync(
        decimal amount, string currency, string reference, string returnUrl, string cancelUrl)
    {
        var token = await GetAccessTokenAsync();
        var client = _httpFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = new
        {
            intent = "CAPTURE",
            purchase_units = new[]
            {
                new
                {
                    reference_id = reference,
                    amount = new
                    {
                        currency_code = currency,
                        value = amount.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
                    }
                }
            },
            application_context = new
            {
                return_url = returnUrl,
                cancel_url = cancelUrl,
                user_action = "PAY_NOW",
                brand_name = "RezervisiMe"
            }
        };

        var res = await client.PostAsync($"{_baseUrl}/v2/checkout/orders",
            new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"));
        var body = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
            throw new InvalidOperationException($"PayPal create order nije uspio: {res.StatusCode} {body}");

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        var orderId = root.GetProperty("id").GetString()!;
        var status = root.GetProperty("status").GetString()!;
        string? approveUrl = null;
        if (root.TryGetProperty("links", out var links))
        {
            foreach (var l in links.EnumerateArray())
            {
                if (l.GetProperty("rel").GetString() == "approve")
                    approveUrl = l.GetProperty("href").GetString();
            }
        }
        return new PayPalOrder(orderId, status, approveUrl);
    }

    public async Task<PayPalCapture> CaptureOrderAsync(string orderId)
    {
        var token = await GetAccessTokenAsync();
        var client = _httpFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var res = await client.PostAsync($"{_baseUrl}/v2/checkout/orders/{orderId}/capture",
            new StringContent("{}", Encoding.UTF8, "application/json"));
        var body = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
        {
            // Sandbox PayPal test racuni znaju vratiti COMPLIANCE_VIOLATION (422) na capture,
            // iako je order uredno kreiran i korisnik ga je odobrio. To je ogranicenje sandbox
            // okruzenja, ne greska u kodu. Umjesto da srusimo tok, vratimo poseban status da
            // servis moze odluciti sta dalje (u sandbox modu tretira kao uspjeh - vidi PaymentService).
            if (res.StatusCode == System.Net.HttpStatusCode.UnprocessableEntity &&
                body.Contains("COMPLIANCE_VIOLATION", StringComparison.OrdinalIgnoreCase))
            {
                return new PayPalCapture("", "COMPLIANCE_VIOLATION");
            }
            throw new InvalidOperationException($"PayPal capture nije uspio: {res.StatusCode} {body}");
        }

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        var status = root.GetProperty("status").GetString()!;
        // captureId se nalazi u purchase_units[0].payments.captures[0].id
        string captureId = "";
        var pu = root.GetProperty("purchase_units")[0];
        if (pu.TryGetProperty("payments", out var payments) &&
            payments.TryGetProperty("captures", out var captures) &&
            captures.GetArrayLength() > 0)
        {
            captureId = captures[0].GetProperty("id").GetString() ?? "";
        }
        return new PayPalCapture(captureId, status);
    }

    public async Task<string> RefundCaptureAsync(string captureId, decimal amount, string currency)
    {
        var token = await GetAccessTokenAsync();
        var client = _httpFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = new
        {
            amount = new
            {
                value = amount.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture),
                currency_code = currency
            }
        };

        var res = await client.PostAsync($"{_baseUrl}/v2/payments/captures/{captureId}/refund",
            new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json"));
        var body = await res.Content.ReadAsStringAsync();
        if (!res.IsSuccessStatusCode)
            throw new InvalidOperationException($"PayPal refund nije uspio: {res.StatusCode} {body}");

        using var doc = JsonDocument.Parse(body);
        return doc.RootElement.GetProperty("status").GetString()!;
    }
}
