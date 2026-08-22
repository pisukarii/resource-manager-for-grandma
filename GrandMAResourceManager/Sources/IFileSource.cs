using GrandMAResourceManager.Models;

namespace GrandMAResourceManager.Sources;

/// <summary>
/// Common interface every backend (local disk, USB volume) conforms to, so
/// UI/ViewModel code never branches on backend kind. Mirrors the macOS
/// app's <c>FileSource</c> Swift protocol.
/// </summary>
public interface IFileSource
{
    Guid Id { get; }
    SourceConfig Config { get; }
    SourceConnectionState ConnectionState { get; }

    Task ConnectAsync();
    Task<List<FileEntry>> ListAsync(RelativePath path);
    Task CopyInAsync(string localPath, RelativePath destination);
    Task CopyOutAsync(RelativePath source, string localPath);
    void Reveal(RelativePath path);

    /// <summary>Prefix prepended before a category's uniform taxonomy path for this backend.</summary>
    RelativePath RootPrefix(ConsoleCategory category);

    /// <summary>
    /// The real on-disk path backing this RelativePath, if any — used so
    /// file rows can be drag-sourced straight to Explorer/other apps.
    /// </summary>
    string? LocalFilePath(RelativePath path);

    bool SupportsDestructiveOperations { get; }
    Task RenameAsync(RelativePath path, string newName);
    Task DeleteAsync(RelativePath path);
}

public static class FileSourceExtensions
{
    public static RelativePath CategoryPath(this IFileSource source, ConsoleCategory category) =>
        source.RootPrefix(category).Appending(category.RelativePath);
}
