namespace GrandMAResourceManager.Models;

/// <summary>
/// A path relative to an <see cref="Sources.IFileSource"/>'s root, expressed
/// as ordered components. Kept independent of absolute filesystem paths so
/// the same taxonomy can be resolved against different backends (local
/// disk, USB volume).
/// </summary>
public sealed record RelativePath(IReadOnlyList<string> Components)
{
    public static readonly RelativePath Root = new(Array.Empty<string>());

    public RelativePath(string singleComponent) : this(new[] { singleComponent }) { }

    public RelativePath Appending(string component) =>
        new(Components.Append(component).ToArray());

    public RelativePath Appending(RelativePath other) =>
        new(Components.Concat(other.Components).ToArray());

    public string DisplayPath => string.Join("/", Components);

    public bool Equals(RelativePath? other) =>
        other is not null && Components.SequenceEqual(other.Components);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        foreach (var c in Components) hash.Add(c);
        return hash.ToHashCode();
    }
}
