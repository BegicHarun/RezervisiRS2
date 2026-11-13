using Microsoft.EntityFrameworkCore;
using RezervisiMe.API.Common;

namespace RezervisiMe.API.Data;

internal static class ReservationLock
{
    public static Task AcquireAsync(ApplicationDbContext db, int reservationId)
        => AcquireAsync(db, $"reservation:{reservationId}");

    public static async Task AcquireAsync(ApplicationDbContext db, string resource)
    {
        try
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                DECLARE @result int;
                EXEC @result = sp_getapplock @Resource = {resource},
                    @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 5000;
                IF @result < 0 THROW 51001, 'Reservation lock unavailable.', 1;
                """);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 51001)
        {
            throw new ConflictException("Zapis se trenutno obrađuje. Pokušajte ponovo.");
        }
    }
}
