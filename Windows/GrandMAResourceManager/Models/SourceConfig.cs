using CommunityToolkit.Mvvm.ComponentModel;
using GrandMAResourceManager.Services;

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

    // --- SFTP-only fields (Kind == SourceKind.Sftp) ---

    public string? Host { get; set; }
    public int? Port { get; set; }
    public string? Username { get; set; }
    public ConnectionTarget? ConnectionTarget { get; set; }

    /// <summary>
    /// The remote path this Source is rooted at (e.g. the console's
    /// <c>/MALighting/grandma3</c>, or an onPC install folder reached over
    /// plain SSH). Named "override" for parity with the macOS app, where it
    /// exists so a per-console/version path can be corrected without a code
    /// change.
    /// </summary>
    public string? BasePathOverride { get; set; }

    /// <summary>
    /// Live connection status for an SFTP Source, pushed here by the backing
    /// <see cref="Sources.SftpFileSource"/> whenever it changes — null while
    /// connecting/unknown, true once connected, false on error/disconnect.
    /// Kept on the shared config (rather than only on the live IFileSource)
    /// so the sidebar's status dot can bind straight to it like every other
    /// Source row property.
    /// </summary>
    [ObservableProperty]
    private bool? _sftpConnected;

    /// <summary>Segoe MDL2 Assets glyph for this Source's kind, for XAML binding.</summary>
    public string KindGlyph => Kind.Glyph();

    /// <summary>Compact "MA3"/"MA2" badge text, for XAML binding.</summary>
    public string FamilyBadge => ResolvedFamily.ShortLabel();

    public bool IsSftp => Kind == SourceKind.Sftp;

    /// <summary>
    /// Whether this SFTP Source's host shares a subnet with one of this PC's
    /// own network interfaces — flagged in the sidebar as "MA Net" so the
    /// user can tell it's a direct LAN hop (e.g. through the console's Manet
    /// port) rather than a routed connection.
    /// </summary>
    public bool ShowMaNetBadge => IsSftp && Host is { Length: > 0 } host && NetworkInterfaceHelper.IsHostOnLocalSubnet(host);

    public string MaNetLabel => $"MA Net ({Host})";
}
