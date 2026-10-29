namespace RezervisiMe.API.Common;

/// <summary>
/// Statusi rezervacije. State machine: Pending -> Confirmed -> Completed,
/// uz moguci prelaz u Cancelled. Nikada hard delete umjesto promjene statusa.
/// </summary>
public enum ReservationStatus
{
    Pending = 0,
    Confirmed = 1,
    Completed = 2,
    Cancelled = 3
}

/// <summary>
/// Status verifikacije salona i frizera od strane administratora.
/// </summary>
public enum VerificationStatus
{
    Pending = 0,
    Approved = 1,
    Rejected = 2
}

/// <summary>
/// Tip audit akcije - ko je sta uradio nad rezervacijom.
/// </summary>
public enum AuditAction
{
    Created = 0,
    Confirmed = 1,
    Rejected = 2,
    Cancelled = 3,
    Completed = 4
}

/// <summary>
/// Status placanja rezervacije (PayPal).
/// Created -> Completed (uspjesno naplaceno) ili Failed; Completed -> Refunded (povrat).
/// </summary>
public enum PaymentStatus
{
    Created = 0,
    Completed = 1,
    Failed = 2,
    Refunded = 3
}
