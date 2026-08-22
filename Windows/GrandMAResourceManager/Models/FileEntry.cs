namespace GrandMAResourceManager.Models;

public sealed record FileEntry(
    string Name,
    bool IsDirectory,
    long? Size,
    DateTime? ModifiedDate,
    RelativePath Path)
{
    public string Id => Path.DisplayPath;
}
