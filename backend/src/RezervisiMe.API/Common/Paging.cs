namespace RezervisiMe.API.Common;

/// <summary>
/// Bazni parametri za paginaciju i pretragu na list endpointima (upute 8.2).
/// PageSize ima maksimalni limit da se sprijeci RetrieveAll bez limita.
/// </summary>
public class PagedQuery
{
    private const int MaxPageSize = 100;
    private int _pageSize = 20;
    private int _page = 1;

    public int Page
    {
        get => _page;
        set => _page = value < 1 ? 1 : value;
    }

    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = value is < 1 or > MaxPageSize ? MaxPageSize : value;
    }

    /// <summary>Opcioni tekst za pretragu (svaki list endpoint ima bar jedan parametar).</summary>
    public string? Search { get; set; }

    public int Skip => (Page - 1) * PageSize;
}

/// <summary>Standardni omotac za paginirane rezultate.</summary>
public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = new List<T>();
    public int TotalCount { get; init; }
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalPages => PageSize == 0 ? 0 : (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasNextPage => Page < TotalPages;
    public bool HasPreviousPage => Page > 1;
}
