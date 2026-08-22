namespace GrandMAResourceManager.Models;

/// <summary>
/// Which MA Lighting console generation a Source's folder layout follows.
/// Unlike the macOS app (USB-only MA2), the Windows app lets both Local and
/// USB sources be either family, since grandMA2 onPC still runs on Windows.
/// </summary>
public enum ConsoleFamily
{
    Ma3,
    Ma2
}

public static class ConsoleFamilyExtensions
{
    public static string DisplayName(this ConsoleFamily family) => family switch
    {
        ConsoleFamily.Ma3 => "grandMA3",
        ConsoleFamily.Ma2 => "grandMA2",
        _ => family.ToString()
    };

    /// <summary>Compact form for badges, e.g. in the sidebar's Source rows.</summary>
    public static string ShortLabel(this ConsoleFamily family) => family switch
    {
        ConsoleFamily.Ma3 => "MA3",
        ConsoleFamily.Ma2 => "MA2",
        _ => family.ToString()
    };

    /// <summary>The marker folder this family creates at a USB volume's root.</summary>
    public static string UsbRootFolderName(this ConsoleFamily family) => family switch
    {
        ConsoleFamily.Ma3 => "grandMA3",
        ConsoleFamily.Ma2 => "gma2",
        _ => throw new ArgumentOutOfRangeException(nameof(family))
    };

    public static IReadOnlyList<ConsoleCategory> Categories(this ConsoleFamily family) => family switch
    {
        ConsoleFamily.Ma3 => MA3FolderTaxonomy.Categories,
        ConsoleFamily.Ma2 => MA2FolderTaxonomy.Categories,
        _ => throw new ArgumentOutOfRangeException(nameof(family))
    };
}
