namespace RezervisiMe.API.Entities;

/// <summary>
/// Usluga koju salon nudi (npr. sisanje, farbanje). Glavna tabela.
/// Trajanje se koristi za generisanje dostupnih termina.
/// </summary>
public class Service
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public decimal Price { get; set; }

    /// <summary>Trajanje usluge u minutama - direktno utice na izracun termina.</summary>
    public int DurationMinutes { get; set; }

    public bool IsActive { get; set; } = true;

    public int SalonId { get; set; }
    public Salon Salon { get; set; } = null!;

    /// <summary>Kategorija - FK prema referentnoj tabeli.</summary>
    public int ServiceCategoryId { get; set; }
    public ServiceCategory ServiceCategory { get; set; } = null!;

    public bool IsDeleted { get; set; }

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<HairdresserService> HairdresserServices { get; set; } = new List<HairdresserService>();
}

/// <summary>
/// Many-to-many veza: koji frizer moze obavljati koju uslugu.
/// Cista join tabela (nema dodatnih atributa) - referentna tabela.
/// </summary>
public class HairdresserService
{
    public int HairdresserId { get; set; }
    public Hairdresser Hairdresser { get; set; } = null!;

    public int ServiceId { get; set; }
    public Service Service { get; set; } = null!;
}

/// <summary>
/// Radno vrijeme frizera po danu u sedmici. Glavna tabela.
/// Definise okvir unutar kojeg backend racuna dostupne termine.
/// </summary>
public class WorkingHour
{
    public int Id { get; set; }

    public int HairdresserId { get; set; }
    public Hairdresser Hairdresser { get; set; } = null!;

    /// <summary>Dan u sedmici (0 = nedjelja ... 6 = subota), prati DayOfWeek enum.</summary>
    public DayOfWeek DayOfWeek { get; set; }

    /// <summary>Pocetak radnog vremena (npr. 09:00).</summary>
    public TimeOnly StartTime { get; set; }

    /// <summary>Kraj radnog vremena (npr. 17:00).</summary>
    public TimeOnly EndTime { get; set; }

    /// <summary>Da li je taj dan neradni.</summary>
    public bool IsDayOff { get; set; }
}
