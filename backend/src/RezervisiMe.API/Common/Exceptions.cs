namespace RezervisiMe.API.Common;

/// <summary>Bazni tip za poslovne greske - mapira se na 400/409 preko middleware-a.</summary>
public class BusinessException : Exception
{
    public BusinessException(string message) : base(message) { }
}

/// <summary>Trazeni resurs ne postoji - mapira se na 404.</summary>
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
    public NotFoundException(string entity, object key)
        : base($"{entity} sa identifikatorom '{key}' nije pronadjen.") { }
}

/// <summary>Korisnik nema pravo na resurs (nije vlasnik) - mapira se na 403.</summary>
public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}

/// <summary>Konflikt (npr. preklapanje termina, duplikat) - mapira se na 409.</summary>
public class ConflictException : Exception
{
    public ConflictException(string message) : base(message) { }
}

/// <summary>Greska u validaciji unosa - mapira se na 400 sa listom gresaka.</summary>
public class ValidationException : Exception
{
    public IReadOnlyList<string> Errors { get; }
    public ValidationException(IEnumerable<string> errors)
        : base("Validacija nije uspjela.")
    {
        Errors = errors.ToList();
    }
    public ValidationException(string error) : this(new[] { error }) { }
}
