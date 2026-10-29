namespace RezervisiMe.API.DTOs;

/// <summary>KPI kartice + podaci za grafove na desktop dashboardu (upute 7.1).</summary>
public class DashboardDto
{
    // KPI kartice
    public int TotalReservations { get; set; }
    public decimal TotalRevenue { get; set; }
    public int NewClients { get; set; }
    public double OccupancyRate { get; set; } // popunjenost termina (0-100)

    // Trend (poredjenje sa prethodnim periodom, u procentima)
    public double ReservationsTrend { get; set; }
    public double RevenueTrend { get; set; }

    // Bar chart: rezervacije po danu (zadnjih 7 dana)
    public List<DailyCountDto> ReservationsPerDay { get; set; } = new();

    // Donut chart: raspodjela po statusu
    public List<StatusCountDto> ReservationsByStatus { get; set; } = new();

    // Rang lista najpopularnijih usluga
    public List<PopularServiceDto> PopularServices { get; set; } = new();

    // Nedavne rezervacije
    public List<ReservationDto> RecentReservations { get; set; } = new();
}

public class DailyCountDto
{
    public DateTime Date { get; set; }
    public string Label { get; set; } = null!;
    public int Count { get; set; }
}

public class StatusCountDto
{
    public string Status { get; set; } = null!;
    public int Count { get; set; }
}

public class PopularServiceDto
{
    public int ServiceId { get; set; }
    public string ServiceName { get; set; } = null!;
    public int ReservationCount { get; set; }
    public decimal Revenue { get; set; }
}
