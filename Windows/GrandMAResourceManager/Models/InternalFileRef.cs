using System.Text.Json;

namespace GrandMAResourceManager.Models;

/// <summary>
/// A drag payload identifying a row on one of this app's own Sources (as
/// opposed to a real file dragged in from Explorer), so a drag between two
/// Source rows — including SFTP on either end, which has no on-disk
/// backing — can be resolved into a copyOut-then-copyIn transfer. Carried
/// as a custom clipboard/drag-drop data format alongside (or instead of)
/// <see cref="System.Windows.DataFormats.FileDrop"/>. Mirrors the macOS
/// app's <c>InternalFileRef</c>/<c>ma3InternalFileRef</c> UTType.
/// </summary>
public sealed record InternalFileRef(Guid SourceId, string[] PathComponents)
{
    public const string Format = "GrandMAResourceManager.InternalFileRef";

    public string Serialize() => JsonSerializer.Serialize(this);

    public static InternalFileRef? Deserialize(string json)
    {
        try { return JsonSerializer.Deserialize<InternalFileRef>(json); }
        catch (JsonException) { return null; }
    }
}
