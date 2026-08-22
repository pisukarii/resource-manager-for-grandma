namespace GrandMAResourceManager.Sources;

public enum SourceConnectionKind
{
    Disconnected,
    Connecting,
    Connected,
    Error
}

public sealed record SourceConnectionState(SourceConnectionKind Kind, string? ErrorMessage = null)
{
    public static readonly SourceConnectionState Disconnected = new(SourceConnectionKind.Disconnected);
    public static readonly SourceConnectionState Connecting = new(SourceConnectionKind.Connecting);
    public static readonly SourceConnectionState Connected = new(SourceConnectionKind.Connected);

    public static SourceConnectionState Error(string message) => new(SourceConnectionKind.Error, message);
}
