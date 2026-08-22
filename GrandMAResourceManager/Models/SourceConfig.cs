using CommunityToolkit.Mvvm.ComponentModel;

namespace GrandMAResourceManager.Models;

/// <summary>
/// A user-configured connection to a local onPC install or a USB stick.
/// Persisted as JSON by <see cref="SourceStore"/>. An ObservableObject (not
/// a plain record) so renaming a Source updates the sidebar immediately —
/// it's the same reference held by both <see cref="SourceStore.Configs"/>
/// and the live <see cref="Sources.IFileSource.Config"/>.
/// </summary>
public sealed partial class SourceConfig : ObservableObject
{
    public Guid Id { get; init; } = Guid.NewGuid();

    [ObservableProperty]
    private string _name = "";

    public SourceKind Kind { get; set; }

    /// <summary>
    /// .Local (MA3): path to the chosen gma3_x.y.z version folder.
    /// .Local (MA2): path to the chosen gma2_V_x.y.z version folder.
    /// .Usb: path to the console's data-root folder on the drive, e.g.
    /// D:\grandMA3 or D:\gma2 (see <see cref="Family"/>).
    /// </summary>
    public string? Path { get; set; }

    /// <summary>
    /// Which console generation's folder layout this Source uses. Optional
    /// so older saved configs (pre-MA2 support) decode fine and default to
    /// grandMA3 via <see cref="ResolvedFamily"/>.
    /// </summary>
    public ConsoleFamily? Family { get; set; }

    public ConsoleFamily ResolvedFamily => Family ?? ConsoleFamily.Ma3;

    /// <summary>Segoe MDL2 Assets glyph for this Source's kind, for XAML binding.</summary>
    public string KindGlyph => Kind.Glyph();

    /// <summary>Compact "MA3"/"MA2" badge text, for XAML binding.</summary>
    public string FamilyBadge => ResolvedFamily.ShortLabel();
}
