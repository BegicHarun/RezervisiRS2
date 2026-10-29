using DotNetEnv;
using RezervisiMe.Worker;

// Ucitaj .env (konfiguracija na jednom mjestu - upute 3.3).
Env.TraversePath().Load();

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton<IEmailSender, EmailSender>();
builder.Services.AddHostedService<NotificationConsumer>();

var host = builder.Build();
host.Run();
