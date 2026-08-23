namespace GrandMAResourceManager.Models;

using static ConsoleCategoryRootKind;

/// <summary>
/// Ported verbatim from the macOS app's <c>MA3FolderTaxonomy.swift</c>,
/// verified against a real onPC install on 2026-08-18. Windows onPC mirrors
/// the same relative layout under a different root
/// (<c>C:\ProgramData\MALightingTechnology\</c> instead of
/// <c>~/MALightingTechnology</c>) — see <c>Services/LocalInstallDetector.cs</c>.
/// </summary>
public static class MA3FolderTaxonomy
{
    public static readonly IReadOnlyList<ConsoleCategory> Categories = new[]
    {
        new ConsoleCategory("shows", "Shows", Glyphs.Document, VersionScoped, new RelativePath(new[] { "shared", "shows" })),
        new ConsoleCategory("backups", "Backups", Glyphs.Refresh, VersionScoped, new RelativePath(new[] { "shared", "backups" })),
        new ConsoleCategory("lib_fixture_types", "Fixture Library", Glyphs.Folder, VersionScoped, new RelativePath(new[] { "shared", "lib_fixture_types" })),
        new ConsoleCategory("resource", "Resource", Glyphs.Folder, VersionScoped, new RelativePath(new[] { "shared", "resource" })),

        new ConsoleCategory("macros", "Macros", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "macros" })),
        new ConsoleCategory("sequences", "Sequences", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "sequences" })),
        new ConsoleCategory("presets", "Presets", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "presets" })),
        new ConsoleCategory("groups", "Groups", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "groups" })),
        new ConsoleCategory("layouts", "Layouts", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "layouts" })),
        new ConsoleCategory("executorconfigurations", "Executor Configs", Glyphs.Gear, Library, new RelativePath(new[] { "gma3_library", "datapools", "executorconfigurations" })),
        new ConsoleCategory("executorpages", "Executor Pages", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "executorpages" })),
        new ConsoleCategory("plugins", "Plugins", Glyphs.Component, Library, new RelativePath(new[] { "gma3_library", "datapools", "plugins" })),
        new ConsoleCategory("quickeys", "Quick Keys", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "quickeys" })),
        new ConsoleCategory("timecodes", "Timecodes", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "timecodes" })),
        new ConsoleCategory("matricks", "Matricks", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "matricks" })),
        new ConsoleCategory("shapes", "Shapes", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "shapes" })),
        new ConsoleCategory("bitmaps", "Bitmaps", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "bitmaps" })),
        new ConsoleCategory("filters", "Filters", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "filters" })),
        new ConsoleCategory("generators", "Generators", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "datapools", "generators" })),

        new ConsoleCategory("fixturetypes", "Fixture Types", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "fixturetypes" })),
        new ConsoleCategory("fixturetyperesources", "Fixture Resources", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "fixturetyperesources" })),
        new ConsoleCategory("appearances", "Appearances", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "appearances" })),
        new ConsoleCategory("colorthemes", "Color Themes", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "colorthemes" })),
        new ConsoleCategory("media", "Media", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "media" })),
        new ConsoleCategory("templateshows", "Template Shows", Glyphs.Document, Library, new RelativePath(new[] { "gma3_library", "templateshows" })),
        new ConsoleCategory("userprofiles", "User Profiles", Glyphs.Person, Library, new RelativePath(new[] { "gma3_library", "userprofiles" })),
        new ConsoleCategory("patch", "Patch", Glyphs.Gear, Library, new RelativePath(new[] { "gma3_library", "patch" })),
        new ConsoleCategory("inout", "In/Out", Glyphs.Gear, Library, new RelativePath(new[] { "gma3_library", "inout" })),
        new ConsoleCategory("agendas", "Agendas", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "agendas" })),
        new ConsoleCategory("certificates", "Certificates", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "certificates" })),
        new ConsoleCategory("mvr", "MVR", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "mvr" })),
        new ConsoleCategory("netkeys", "Net Keys", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "netkeys" })),
        new ConsoleCategory("scribbles", "Scribbles", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "scribbles" })),
        new ConsoleCategory("users", "Users", Glyphs.Person, Library, new RelativePath(new[] { "gma3_library", "users" })),
        new ConsoleCategory("systemtest", "System Test", Glyphs.Checkmark, Library, new RelativePath(new[] { "gma3_library", "SystemTest" })),
        new ConsoleCategory("systemtestarchive", "System Test Archive", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "SystemTestArchive" })),
        new ConsoleCategory("systemtesttemp", "System Test Temp", Glyphs.Folder, Library, new RelativePath(new[] { "gma3_library", "SystemTestTemp" })),
    };
}
