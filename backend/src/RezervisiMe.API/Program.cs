using System.Security.Claims;
using System.Text;
using DotNetEnv;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using RezervisiMe.API.Auth;
using RezervisiMe.API.Data;
using RezervisiMe.API.Entities;
using RezervisiMe.API.Middleware;
using RezervisiMe.API.Recommender;
using RezervisiMe.API.Services;

// Ucitaj .env prije citanja konfiguracije (upute 3.3).
Env.TraversePath().Load();

// QuestPDF Community licenca (besplatno za edukativne/manje projekte) - mora prije generisanja PDF-a.
QuestPDF.Settings.License = QuestPDF.Infrastructure.LicenseType.Community;

var builder = WebApplication.CreateBuilder(args);

// ---- Konfiguracija iz .env ----
var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING")
    ?? throw new InvalidOperationException("CONNECTION_STRING nije postavljen u .env fajlu.");
var jwtSettings = JwtSettings.FromEnvironment();

// ---- Baza ----
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString));

// ---- Identity ----
builder.Services
    .AddIdentity<ApplicationUser, ApplicationRole>(options =>
    {
        options.User.RequireUniqueEmail = true;
        options.Password.RequiredLength = 6;
        options.Password.RequireNonAlphanumeric = false;
    })
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// ---- JWT autentifikacija ----
builder.Services.AddSingleton(jwtSettings);
builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true, // validacija potpisa (upute 5)
            ValidIssuer = jwtSettings.Issuer,
            ValidAudience = jwtSettings.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key))
        };

        // Server-side logout invalidacija (uputa 5): provjeri da se SecurityStamp iz
        // tokena slaze sa stampom korisnika u bazi. Logout mijenja stamp -> stari token pada.
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var userManager = context.HttpContext.RequestServices
                    .GetRequiredService<UserManager<ApplicationUser>>();
                var stampFromToken = context.Principal?.FindFirst(TokenService.SecurityStampClaim)?.Value;
                var userId = context.Principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (string.IsNullOrEmpty(userId))
                {
                    context.Fail("Nevazeci token.");
                    return;
                }
                var user = await userManager.FindByIdAsync(userId);
                if (user is null || !user.IsActive || user.SecurityStamp != stampFromToken)
                    context.Fail("Token je povucen (odjava) ili nalog nije dostupan.");
            }
        };
    });

builder.Services.AddAuthorization();

// ---- HttpContext + trenutni korisnik ----
builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient(); // za PayPal REST pozive (IHttpClientFactory)
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

// ---- Servisi (svi Scoped - koriste DbContext) ----
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ISalonService, SalonService>();
builder.Services.AddScoped<IServiceCatalogService, ServiceCatalogService>();
builder.Services.AddScoped<IReservationService, ReservationService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IProfileService, ProfileService>();
builder.Services.AddScoped<IReferenceService, ReferenceService>();
builder.Services.AddScoped<IHairdresserService, HairdresserServiceImpl>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IPayPalClient, PayPalClient>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IRecommenderService, RecommenderService>();

// ---- Message publisher (RabbitMQ ako je konfigurisan, inace no-op) ----
if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("RABBITMQ_HOST")))
{
    builder.Services.AddSingleton<IMessagePublisher>(sp =>
        RabbitMqPublisher.CreateAsync(
            sp.GetRequiredService<ILogger<RabbitMqPublisher>>()).GetAwaiter().GetResult());
}
else
{
    builder.Services.AddSingleton<IMessagePublisher, NullMessagePublisher>();
}

// ---- CORS (definisan jednom, eksplicitni origini) ----
const string CorsPolicy = "RezervisiMeCors";
builder.Services.AddCors(options =>
    options.AddPolicy(CorsPolicy, policy =>
        policy.WithOrigins("http://localhost:3000", "http://localhost:8080")
              .AllowAnyHeader()
              .AllowAnyMethod()));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// ---- Swagger sa JWT podrskom ----
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "RezervisiMe API", Version = "v1" });
    var scheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Unesite JWT token (bez 'Bearer' prefiksa).",
        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
    };
    c.AddSecurityDefinition("Bearer", scheme);
    c.AddSecurityRequirement(new OpenApiSecurityRequirement { [scheme] = Array.Empty<string>() });
});

var app = builder.Build();

// ---- Migracija + osnovni seed (nalozi, 1 salon) - blokirajuce, nuzno za login ----
await DbSeeder.SeedAsync(app.Services);

// ---- Dodatni demo seed (6 salona + recenzije) - U POZADINI ----
// Ne blokira start API-ja; puni se nakon sto se web server digne. Ako zakaze,
// aplikacija svejedno radi (osnovni podaci su vec tu).
_ = Task.Run(() => DbSeeder.SeedExtraInBackgroundAsync(app.Services));

// ---- Pipeline ----
app.UseMiddleware<ExceptionMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(CorsPolicy);
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
