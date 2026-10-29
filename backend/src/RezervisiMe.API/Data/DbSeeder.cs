using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Common;
using RezervisiMe.API.Entities;

namespace RezervisiMe.API.Data;

/// <summary>
/// Runtime seeder - popunjava bazu pocetnim podacima pri pokretanju aplikacije.
/// Koristi Identity UserManager za kreiranje korisnika (isti hash format kao runtime login).
/// </summary>
public static class DbSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<ApplicationRole>>();

        // Sacekaj da baza bude spremna i primijeni migracije, sa retry-em.
        // SQL Server/Azure SQL Edge zna trebati i preko 60s pri PRVOM startu
        // (narocito na Apple Silicon kroz emulaciju), pa API ne smije pasti ako
        // baza jos nije potpuno gore - inace profesor mora rucno restartovati.
        await MigrateWithRetryAsync(db);

        // 1) Role
        foreach (var role in Roles.All)
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new ApplicationRole(role));

        // 2) Gradovi
        if (!await db.Cities.AnyAsync())
        {
            db.Cities.AddRange(
                new City { Name = "Sarajevo", Region = "Kanton Sarajevo" },
                new City { Name = "Zenica", Region = "Zenicko-dobojski kanton" },
                new City { Name = "Mostar", Region = "Hercegovacko-neretvanski kanton" },
                new City { Name = "Tuzla", Region = "Tuzlanski kanton" },
                new City { Name = "Zavidovici", Region = "Zenicko-dobojski kanton" });
            await db.SaveChangesAsync();
        }

        // 3) Kategorije usluga
        if (!await db.ServiceCategories.AnyAsync())
        {
            db.ServiceCategories.AddRange(
                new ServiceCategory { Name = "Sisanje", IconName = "content_cut" },
                new ServiceCategory { Name = "Farbanje", IconName = "palette" },
                new ServiceCategory { Name = "Tretmani", IconName = "spa" },
                new ServiceCategory { Name = "Nokti", IconName = "back_hand" },
                new ServiceCategory { Name = "Brijanje", IconName = "face" });
            await db.SaveChangesAsync();
        }

        // 4) Tagovi za recenzije
        if (!await db.Tags.AnyAsync())
        {
            db.Tags.AddRange(
                new Tag { Name = "Ljubazno osoblje" },
                new Tag { Name = "Cisto" },
                new Tag { Name = "Brzo" },
                new Tag { Name = "Povoljno" },
                new Tag { Name = "Profesionalno" });
            await db.SaveChangesAsync();
        }

        var sarajevo = await db.Cities.FirstAsync(c => c.Name == "Sarajevo");

        // 5) Korisnici
        var admin = await EnsureUser(userManager, "admin", "admin@rezervisime.ba", "Test1234!",
            "Admin", "Administratoric", Roles.Administrator, sarajevo.Id);
        var seedUser = await EnsureUser(userManager, "desktop", "frizer@rezervisime.ba", "Test1234!",
            "Amela", "Frizeric", Roles.Frizer, sarajevo.Id);
        await EnsureUser(userManager, "mobile", "klijent@rezervisime.ba", "Test1234!",
            "Harun", "Begic", Roles.Klijent, sarajevo.Id);

        // 6) Salon + usluge + frizer + radno vrijeme (da app bude testabilna)
        if (!await db.Salons.IgnoreQueryFilters().AnyAsync())
        {
            var sisanje = await db.ServiceCategories.FirstAsync(c => c.Name == "Sisanje");
            var farbanje = await db.ServiceCategories.FirstAsync(c => c.Name == "Farbanje");

            var salon = new Salon
            {
                Name = "Studio Amela",
                Address = "Ferhadija 10",
                Description = "Moderni frizerski salon u centru grada.",
                CityId = sarajevo.Id,
                VerificationStatus = VerificationStatus.Approved,
                ImageUrl = "https://picsum.photos/seed/salon1/600/400"
            };
            salon.Images.Add(new SalonImage
            { ImageUrl = "https://picsum.photos/seed/salon1a/600/400", Caption = "Enterijer", SortOrder = 1 });
            salon.Services.Add(new Service
            { Name = "Zensko sisanje", Price = 25m, DurationMinutes = 45, ServiceCategory = sisanje });
            salon.Services.Add(new Service
            { Name = "Farbanje kose", Price = 60m, DurationMinutes = 90, ServiceCategory = farbanje });
            db.Salons.Add(salon);
            await db.SaveChangesAsync();

            var hairdresser = new Hairdresser
            {
                UserId = seedUser.Id,
                SalonId = salon.Id,
                Specialization = "Kolorista",
                VerificationStatus = VerificationStatus.Approved
            };
            for (var d = DayOfWeek.Monday; d <= DayOfWeek.Friday; d++)
                hairdresser.WorkingHours.Add(new WorkingHour
                {
                    DayOfWeek = d,
                    StartTime = new TimeOnly(9, 0),
                    EndTime = new TimeOnly(17, 0)
                });
            db.Hairdressers.Add(hairdresser);
            await db.SaveChangesAsync();
        }

        // 7) Demo rezervacije kroz zadnjih 7 dana (da dashboard/izvjestaji imaju podatke).
        // Zaseban guard - radi i ako salon vec postoji od ranije.
        if (!await db.Reservations.AnyAsync())
        {
            var salon = await db.Salons.IgnoreQueryFilters().FirstOrDefaultAsync();
            var hairdresser = await db.Hairdressers.IgnoreQueryFilters().FirstOrDefaultAsync();
            var mobileUser = await userManager.FindByNameAsync("mobile");
            var frizerUser = await userManager.FindByNameAsync("desktop");

            if (salon != null && hairdresser != null && mobileUser != null && frizerUser != null)
            {
                var svc = await db.Services.IgnoreQueryFilters()
                    .Where(s => s.SalonId == salon.Id).ToListAsync();
                if (svc.Count > 0)
                {
                    var rnd = new Random(220008);
                    var statuses = new[]
                    {
                        ReservationStatus.Completed, ReservationStatus.Completed,
                        ReservationStatus.Confirmed, ReservationStatus.Pending,
                        ReservationStatus.Cancelled
                    };

                    for (int dayOffset = 7; dayOffset >= 0; dayOffset--)
                    {
                        var day = DateTime.UtcNow.Date.AddDays(-dayOffset);
                        if (day.DayOfWeek == DayOfWeek.Saturday || day.DayOfWeek == DayOfWeek.Sunday)
                            continue;

                        var count = rnd.Next(1, 4);
                        for (int i = 0; i < count; i++)
                        {
                            var service = svc[rnd.Next(svc.Count)];
                            var hour = 9 + rnd.Next(0, 7);
                            var start = new DateTime(day.Year, day.Month, day.Day, hour, 0, 0, DateTimeKind.Utc);
                            var status = statuses[rnd.Next(statuses.Length)];
                            if (day > DateTime.UtcNow.Date && status == ReservationStatus.Completed)
                                status = ReservationStatus.Confirmed;

                            var res = new Reservation
                            {
                                ClientId = mobileUser.Id,
                                HairdresserId = hairdresser.Id,
                                ServiceId = service.Id,
                                StartTime = start,
                                EndTime = start.AddMinutes(service.DurationMinutes),
                                Price = service.Price,
                                Status = status,
                                StatusReason = status == ReservationStatus.Cancelled ? "Klijent sprijecen" : null,
                                CreatedAt = start.AddDays(-1)
                            };
                            res.AuditLogs.Add(new AuditLog
                            {
                                PerformedByUserId = status == ReservationStatus.Pending ? mobileUser.Id : frizerUser.Id,
                                Action = status switch
                                {
                                    ReservationStatus.Confirmed => AuditAction.Confirmed,
                                    ReservationStatus.Completed => AuditAction.Completed,
                                    ReservationStatus.Cancelled => AuditAction.Cancelled,
                                    _ => AuditAction.Created
                                },
                                Description = "Seed",
                                PerformedAt = start.AddDays(-1)
                            });
                            db.Reservations.Add(res);
                        }
                    }
                    await db.SaveChangesAsync();
                }
            }
        }

        // 8) Dodatni saloni se seedaju ODVOJENO, u pozadini (SeedExtraInBackgroundAsync),
        // da ne blokiraju start API-ja. Vidi Program.cs.
    }

    /// <summary>
    /// Dodatni seed (6 salona + recenzije) koji se pokrece U POZADINI nakon sto se API
    /// vec digao. Ne smije srusiti aplikaciju - sve je u try/catch. Osnovni podaci
    /// (nalozi, 1 salon) su vec seedani sinhrono u SeedAsync.
    /// </summary>
    public static async Task SeedExtraInBackgroundAsync(IServiceProvider services)
    {
        try
        {
            using var scope = services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            await SeedExtraSalonsAsync(db, userManager);
        }
        catch
        {
            // Dodatni demo podaci nisu kriticni - ako zakazu, aplikacija svejedno radi.
        }
    }

    /// <summary>
    /// Puni bazu sa jos salona (razni gradovi), uslugama, frizerima (sa nalozima),
    /// zavrsenim rezervacijama i recenzijama raznih ocjena - da recommender ima sta
    /// rangirati i objasniti, a izvjestaji realne podatke.
    /// </summary>
    private static async Task SeedExtraSalonsAsync(
        ApplicationDbContext db, UserManager<ApplicationUser> userManager)
    {
        // Guard: ako vec ima vise od jednog salona, preskoci (vec seedano).
        if (await db.Salons.IgnoreQueryFilters().CountAsync() > 1) return;

        var cities = await db.Cities.ToListAsync();
        var cats = await db.ServiceCategories.ToListAsync();
        var tags = await db.Tags.ToListAsync();
        var mobileUser = await userManager.FindByNameAsync("mobile");
        if (cities.Count == 0 || cats.Count == 0 || mobileUser == null) return;

        City CityByName(string n) => cities.FirstOrDefault(c => c.Name == n) ?? cities[0];
        ServiceCategory Cat(string n) => cats.FirstOrDefault(c => c.Name == n) ?? cats[0];

        // Definicije salona: naziv, grad, adresa, opis, [ (usluga, kategorija, cijena, trajanje) ],
        // frizer-username, specijalizacija, prosjecna ocjena (koliko recenzija i kojih ocjena).
        var defs = new[]
        {
            new { Name = "Barbershop Mujo", City = "Sarajevo", Addr = "Titova 22",
                  Desc = "Klasicni muski frizerski salon i brijacnica.",
                  Img = "salon2", User = "frizer2", Spec = "Barber",
                  Svcs = new[] { ("Musko sisanje","Sisanje",15m,30), ("Brijanje","Brijanje",10m,20),
                                 ("Sisanje + brijanje","Brijanje",22m,45) },
                  Ratings = new[] { 5,5,4,5,4 } },
            new { Name = "Salon Lejla", City = "Zenica", Addr = "Londza 5",
                  Desc = "Zenski salon za sisanje, farbanje i tretmane.",
                  Img = "salon3", User = "frizer3", Spec = "Kolorista",
                  Svcs = new[] { ("Zensko sisanje","Sisanje",20m,45), ("Farbanje","Farbanje",55m,90),
                                 ("Pramenovi","Farbanje",70m,120), ("Fen frizura","Sisanje",18m,30) },
                  Ratings = new[] { 5,4,4,5,3,4 } },
            new { Name = "Hair Studio Mostar", City = "Mostar", Addr = "Kralja Tvrtka 9",
                  Desc = "Moderni unisex salon u srcu Mostara.",
                  Img = "salon4", User = "frizer4", Spec = "Stilista",
                  Svcs = new[] { ("Sisanje","Sisanje",18m,40), ("Tretman kose","Tretmani",35m,60),
                                 ("Farbanje","Farbanje",50m,90) },
                  Ratings = new[] { 4,4,5,3,4 } },
            new { Name = "Beauty Tuzla", City = "Tuzla", Addr = "Slatina 14",
                  Desc = "Salon ljepote - kosa, nokti i tretmani lica.",
                  Img = "salon5", User = "frizer5", Spec = "Kozmeticar",
                  Svcs = new[] { ("Manikir","Nokti",20m,45), ("Gel nokti","Nokti",30m,60),
                                 ("Tretman lica","Tretmani",40m,60), ("Sisanje","Sisanje",20m,40) },
                  Ratings = new[] { 5,5,5,4,4,5,3 } },
            new { Name = "Frizerski salon Ena", City = "Zavidovici", Addr = "Alije Izetbegovica 3",
                  Desc = "Porodicni salon sa dugom tradicijom.",
                  Img = "salon6", User = "frizer6", Spec = "Frizer",
                  Svcs = new[] { ("Zensko sisanje","Sisanje",16m,40), ("Musko sisanje","Sisanje",12m,30),
                                 ("Farbanje","Farbanje",45m,90) },
                  Ratings = new[] { 4,3,4,4 } },
        };

        var rnd = new Random(220008);

        foreach (var d in defs)
        {
            var city = CityByName(d.City);
            var salon = new Salon
            {
                Name = d.Name,
                Address = d.Addr,
                Description = d.Desc,
                CityId = city.Id,
                VerificationStatus = VerificationStatus.Approved,
                ImageUrl = $"https://picsum.photos/seed/{d.Img}/600/400"
            };
            salon.Images.Add(new SalonImage
            {
                ImageUrl = $"https://picsum.photos/seed/{d.Img}a/600/400",
                Caption = "Enterijer", SortOrder = 1
            });
            foreach (var (sname, scat, price, dur) in d.Svcs)
                salon.Services.Add(new Service
                {
                    Name = sname, Price = price, DurationMinutes = dur,
                    ServiceCategory = Cat(scat)
                });
            db.Salons.Add(salon);
            await db.SaveChangesAsync();

            // Frizer sa nalogom.
            var frizerUser = await EnsureUser(userManager, d.User,
                $"{d.User}@rezervisime.ba", "Test1234!",
                d.Spec, "Frizer", Roles.Frizer, city.Id);
            var hairdresser = new Hairdresser
            {
                UserId = frizerUser.Id,
                SalonId = salon.Id,
                Specialization = d.Spec,
                VerificationStatus = VerificationStatus.Approved
            };
            for (var day = DayOfWeek.Monday; day <= DayOfWeek.Friday; day++)
                hairdresser.WorkingHours.Add(new WorkingHour
                {
                    DayOfWeek = day,
                    StartTime = new TimeOnly(9, 0),
                    EndTime = new TimeOnly(17, 0)
                });
            db.Hairdressers.Add(hairdresser);
            await db.SaveChangesAsync();

            // Za svaku ocjenu: zavrsena rezervacija u proslosti + recenzija (recommender treba podatke).
            var svcList = await db.Services.IgnoreQueryFilters()
                .Where(s => s.SalonId == salon.Id).ToListAsync();
            int dayBack = 30;
            foreach (var rating in d.Ratings)
            {
                var svc = svcList[rnd.Next(svcList.Count)];
                var start = DateTime.UtcNow.Date.AddDays(-dayBack).AddHours(10);
                dayBack -= 2;

                var res = new Reservation
                {
                    ClientId = mobileUser.Id,
                    HairdresserId = hairdresser.Id,
                    ServiceId = svc.Id,
                    StartTime = start,
                    EndTime = start.AddMinutes(svc.DurationMinutes),
                    Price = svc.Price,
                    Status = ReservationStatus.Completed,
                    CreatedAt = start.AddDays(-1)
                };
                res.AuditLogs.Add(new AuditLog
                {
                    PerformedByUserId = frizerUser.Id,
                    Action = AuditAction.Completed,
                    Description = "Seed",
                    PerformedAt = start
                });
                db.Reservations.Add(res);
                await db.SaveChangesAsync();

                var review = new Review
                {
                    ReservationId = res.Id,
                    ClientId = mobileUser.Id,
                    SalonId = salon.Id,
                    Rating = rating,
                    Comment = rating >= 4 ? "Odlicna usluga, preporucujem!" :
                              rating == 3 ? "Korektno, moze bolje." : "Nisam zadovoljan.",
                    CreatedAt = start.AddHours(2)
                };
                if (tags.Count > 0 && rating >= 4)
                    review.ReviewTags.Add(new ReviewTag { TagId = tags[rnd.Next(tags.Count)].Id });
                db.Reviews.Add(review);
                await db.SaveChangesAsync();
            }
        }
    }

    /// <summary>
    /// Ceka da baza postane dostupna (do ~60s), sa retry-em. SQL Server/Azure SQL Edge
    /// zna biti spor pri prvom startu, pa API ne smije odmah pasti ako baza jos nije gore.
    /// </summary>
    private static async Task MigrateWithRetryAsync(ApplicationDbContext db)
    {
        // Do ~2.5 min ukupno (50 x 3s). CanConnectAsync zna proci cim SQL otvori
        // port, ali SQL jos dovrsava interni init - zato se i sama migracija pokusava
        // u petlji, a ne samo konekcija. Tek ako NAKON svih pokusaja i dalje pada,
        // baca se stvarna greska.
        const int maxAttempts = 50;
        for (int attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                await db.Database.MigrateAsync();
                return; // uspjeh
            }
            catch when (attempt < maxAttempts)
            {
                // Baza jos nije spremna (npr. SQL error 35 dok dovrsava start) - sacekaj pa ponovo.
                await Task.Delay(TimeSpan.FromSeconds(3));
            }
        }
        // Posljednji pokusaj bez catch-a - ako pukne, neka izbaci stvarnu gresku.
        await db.Database.MigrateAsync();
    }

    private static async Task<ApplicationUser> EnsureUser(
        UserManager<ApplicationUser> userManager,
        string userName, string email, string password,
        string firstName, string lastName, string role, int cityId)
    {
        var existing = await userManager.FindByNameAsync(userName);
        if (existing is not null) return existing;

        var user = new ApplicationUser
        {
            UserName = userName,
            Email = email,
            EmailConfirmed = true,
            FirstName = firstName,
            LastName = lastName,
            CityId = cityId
        };

        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
            throw new Exception($"Seed korisnika '{userName}' nije uspio: " +
                string.Join(", ", result.Errors.Select(e => e.Description)));

        await userManager.AddToRoleAsync(user, role);
        return user;
    }
}
