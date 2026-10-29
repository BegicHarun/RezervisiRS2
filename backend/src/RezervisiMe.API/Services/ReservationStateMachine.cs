using RezervisiMe.API.Common;

namespace RezervisiMe.API.Services;

/// <summary>
/// Centralizovana state machine za rezervacije (upute 7).
/// Definise dozvoljene prelaze na jednom mjestu - logika NIJE rasporedjena po kontrolerima.
/// Pending -> Confirmed -> Completed
/// Pending -> Cancelled
/// Confirmed -> Cancelled
/// </summary>
public static class ReservationStateMachine
{
    private static readonly Dictionary<ReservationStatus, ReservationStatus[]> Allowed = new()
    {
        [ReservationStatus.Pending] = new[] { ReservationStatus.Confirmed, ReservationStatus.Cancelled },
        [ReservationStatus.Confirmed] = new[] { ReservationStatus.Completed, ReservationStatus.Cancelled },
        [ReservationStatus.Completed] = Array.Empty<ReservationStatus>(),
        [ReservationStatus.Cancelled] = Array.Empty<ReservationStatus>()
    };

    public static bool CanTransition(ReservationStatus from, ReservationStatus to) =>
        Allowed.TryGetValue(from, out var targets) && targets.Contains(to);

    public static void EnsureTransition(ReservationStatus from, ReservationStatus to)
    {
        if (from == to)
            throw new BusinessException($"Rezervacija je vec u statusu '{from}'.");

        if (!CanTransition(from, to))
            throw new BusinessException(
                $"Nedozvoljen prelaz statusa: '{from}' -> '{to}'. " +
                $"Dozvoljeni prelazi iz '{from}': " +
                (Allowed[from].Length == 0 ? "nema" : string.Join(", ", Allowed[from])) + ".");
    }
}
