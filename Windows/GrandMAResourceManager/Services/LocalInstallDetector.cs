using System.IO;
using GrandMAResourceManager.Models;

namespace GrandMAResourceManager.Services;

/// <summary>
/// Finds installed onPC version folders under both grandMA3's and
/// grandMA2's ProgramData roots. Extends the macOS app's
/// <c>MA3LocalDetector.swift</c> to also cover grandMA2, since — unlike
/// macOS where grandMA2 doesn't ship an onPC build — the Windows app's
/// Local source can be either family.
/// </summary>
public static class LocalInstallDetector
{
    public static string Ma3Root =>
        System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "MALightingTechnology");

    public static string Ma2Root =>
        System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "MA Lighting Technologies", "grandMA");

    public sealed record VersionFolder(string Name, string FullPath, ConsoleFamily Family);

    public static List<VersionFolder> DetectVersionFolders()
    {
        var results = new List<VersionFolder>();
        results.AddRange(ScanMa3());
        results.AddRange(ScanMa2());
        return results;
    }

    private static IEnumerable<VersionFolder> ScanMa3()
    {
        if (!Directory.Exists(Ma3Root)) yield break;
        foreach (var dir in Directory.EnumerateDirectories(Ma3Root))
        {
            var name = System.IO.Path.GetFileName(dir);
            if (!name.StartsWith("gma3_", StringComparison.OrdinalIgnoreCase)) continue;
            if (!Directory.Exists(System.IO.Path.Combine(dir, "shared"))) continue;
            yield return new VersionFolder(name, dir, ConsoleFamily.Ma3);
        }

        // gma3_library itself (Macros/Presets/Fixture Types/...) is shared
        // across every installed version rather than belonging to one, so
        // it's offered as its own addable item alongside the version
        // folders rather than folded into one of them.
        var libraryDir = System.IO.Path.Combine(Ma3Root, "gma3_library");
        if (Directory.Exists(libraryDir))
        {
            yield return new VersionFolder("gma3_library", libraryDir, ConsoleFamily.Ma3);
        }
    }

    private static IEnumerable<VersionFolder> ScanMa2()
    {
        if (!Directory.Exists(Ma2Root)) yield break;
        foreach (var dir in Directory.EnumerateDirectories(Ma2Root))
        {
            var name = System.IO.Path.GetFileName(dir);
            if (!name.StartsWith("gma2_", StringComparison.OrdinalIgnoreCase)) continue;
            if (!Directory.Exists(System.IO.Path.Combine(dir, "shows"))) continue;
            yield return new VersionFolder(name, dir, ConsoleFamily.Ma2);
        }
    }
}
