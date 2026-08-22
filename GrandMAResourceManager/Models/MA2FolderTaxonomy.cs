namespace GrandMAResourceManager.Models;

/// <summary>
/// grandMA2 layout. USB root: <c>&lt;volume&gt;\gma2\</c>. Windows onPC root:
/// <c>C:\ProgramData\MA Lighting Technologies\grandMA\gma2_V_x.y.z\</c> (a
/// different, version-scoped instance of this same relative layout — see
/// <c>Services/LocalInstallDetector.cs</c> and <c>Sources/DiskFileSource.cs</c>).
///
/// Verified via MA Lighting documentation (2026-08-19): the folder contains
/// <c>shows</c>, <c>bitmaps</c>, <c>colors</c>, <c>effects</c>, <c>gobos</c>,
/// and <c>importexport</c> at its top level. The exact per-object-type
/// subfolder names *inside* <c>importexport</c> (macros, presets,
/// sequences, ...) could not be confirmed from documentation alone — rather
/// than guess and risk wrong shortcuts, this taxonomy only covers the
/// confirmed top-level folders plus a generic "Import/Export" entry to
/// drill into manually. Update this file once verified against a real MA2
/// installation/USB stick, the same way <see cref="MA3FolderTaxonomy"/>
/// broke down <c>datapools/*</c> after checking real data.
/// </summary>
public static class MA2FolderTaxonomy
{
    public static readonly IReadOnlyList<ConsoleCategory> Categories = new[]
    {
        new ConsoleCategory("ma2_shows", "Shows", Glyphs.Document, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "shows" })),
        new ConsoleCategory("ma2_importexport", "Import/Export", Glyphs.Folder, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "importexport" })),
        new ConsoleCategory("ma2_effects", "Effects", Glyphs.Folder, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "effects" })),
        new ConsoleCategory("ma2_gobos", "Gobos", Glyphs.Folder, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "gobos" })),
        new ConsoleCategory("ma2_bitmaps", "Bitmaps", Glyphs.Folder, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "bitmaps" })),
        new ConsoleCategory("ma2_colors", "Colors", Glyphs.Folder, ConsoleCategoryRootKind.Library, new RelativePath(new[] { "colors" })),
    };
}
