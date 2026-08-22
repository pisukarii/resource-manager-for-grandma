namespace GrandMAResourceManager.Models;

/// <summary>
/// Whether a category lives under a version-specific folder (needs the
/// installed version folder name prefixed) or under a version-independent
/// shared tree. Only meaningful for grandMA3, whose onPC install has both
/// kinds; grandMA2 has no shared-across-versions concept, so its local
/// source treats every category as version-scoped regardless of this value
/// (see <c>Sources/DiskFileSource.cs</c>).
/// </summary>
public enum ConsoleCategoryRootKind
{
    VersionScoped,
    Library
}

/// <summary>
/// One well-known console file category (Shows, Macros, Sequences, ...).
/// <see cref="RelativePath"/> is the path from the category root (see
/// <see cref="RootKind"/>) to this category, shared by every backend.
/// </summary>
public sealed record ConsoleCategory(
    string Id,
    string DisplayName,
    string SymbolGlyph,
    ConsoleCategoryRootKind RootKind,
    RelativePath RelativePath);
